# 发布配置

`Release` workflow 从不可变的版本标签构建应用，从触发工作流的提交读取打包脚本。
这允许修复旧标签的打包流程，而不移动标签或替换已经公开的二进制。
`release-manifest.json` 同时记录这两个提交以及每个下载文件的大小和 SHA-256。

## 完整发布清单

| 渠道 | 必需产物 | 验证 |
| --- | --- | --- |
| Windows x64、ARM64 | 各一个便携 ZIP、商店 MSIX | PE 架构、运行时完整性、传输测试；ARM64 使用实际打包的加密库在 ARM64 runner 测试 |
| macOS | Intel / Apple Silicon 通用 ZIP | 双架构、Developer ID 签名、Apple 公证、stapler 与 Gatekeeper |
| Android、Wear OS | 各一个 APK、AAB | Release 构建、单元测试、APK 签名和 zipalign、AAB 签名 |
| Linux x64、ARM64 | 各一个桌面 DEB、桌面 tar.gz、终端 tar.gz | 核心与终端测试、实际链接库、虚拟显示器下的桌面启动、终端命令启动 |
| Web | 静态站点 ZIP | TypeScript / Vite 构建和 Gateway 客户端测试 |
| iOS / iPadOS / Watch、tvOS、visionOS | App Store 入口 | 真机目标 Release 构建，Watch 随 iOS 编译 |

共 16 个下载包，以及 `CHANGELOG.md`、`SHA256SUMS.txt`、`release-manifest.json`；GitHub 同时提供标签的源码归档。
任何必需平台缺失或验证失败都会阻止新的 Release 发布。
Windows 的 `*-store.msix` 未做侧载签名；Android 的 AAB 用于商店提交。普通安装使用 ZIP / APK。
商店提交和审核不由 GitHub 发布工作流触发。

Linux 预编译包面向 Ubuntu 24.04+（glibc 2.39+）；GUI 还需要 GTK 4.12+ 和 libadwaita 1.5+。
DEB 记录实际二进制的动态库依赖，使用 `sudo apt install ./MeshDrop-*.deb` 安装。
终端包不依赖 GTK，解压后运行 `./meshdrop-tui` 或 `./meshdrop-tui --help`。
Web 包需要运行中的桌面 Gateway。

## 签名 Secrets

在仓库 Settings → Secrets and variables → Actions 配置以下 Secrets，不能把签名材料提交到 Git。
签名过程不允许退回 debug key、临时生成的密钥或未签名下载。

| Secret | 内容 |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | 正式 Android keystore 的 Base64 |
| `ANDROID_STORE_PASSWORD` | keystore 密码 |
| `ANDROID_KEY_ALIAS` | 发布密钥 alias |
| `ANDROID_KEY_PASSWORD` | 密钥密码 |
| `MACOS_CERTIFICATE_P12` | Developer ID Application 身份导出的加密 P12 的 Base64 |
| `MACOS_CERTIFICATE_PASSWORD` | P12 密码 |
| `MACOS_PROVISION_PROFILE` | MeshDrop 的 Developer ID 描述文件的 Base64 |
| `APPLE_NOTARY_KEY` | 允许公证的 App Store Connect API 私钥 PEM |
| `APPLE_NOTARY_KEY_ID` | API Key ID |
| `APPLE_NOTARY_ISSUER_ID` | Team API Key 的 Issuer ID |

Android 与 Wear OS 使用持续保管的正式签名密钥，后续更新必须保持签名一致。
macOS 的签名和公证材料只在临时 runner 的专用钥匙串及临时目录中使用，不进入构建产物。
Windows ARM64 在固定的官方 libsodium `1.0.19` 源码提交上构建缺失的动态库，沿用 NSec 原有依赖版本，并随包包含该库许可证。

## 新版本与补发

发布前同步 `VERSION`、Windows 项目/MSIX、macOS/iOS 的版本和相应构建号，运行
`python3 scripts/check-release-version.py vMAJOR.MINOR.PATCH`，在 CI 通过的 `main` 提交上打标签并推送。
`-alpha.N`、`-beta.N`、`-rc.N` 标签产生预发布。

目前 Android / Wear OS / Linux / Web 仍是 `0.1.0` 实验组件，tvOS / visionOS 保留各自应用版本。
GitHub 标签表示整仓快照，不会只通过打包更改各端内嵌版本或假设它们已经协议互通。
Apple / Windows 使用 TLS 1.3 双向设备认证；Android / Linux 原生传输尚为明文，不能连接上述 TLS 客户端。
各端版本与互通能力升级应在打标签之前落实到源码中。

补齐已有版本时，手动运行 Release 并填写现有标签。
重建过程中优先保留该标签已经发布的同名二进制，核对 GitHub 资产摘要；发布器拒绝替换不同哈希的已发布二进制。
新资产全部通过检查后补入同一 Release，再更新说明、完整清单和校验文件。
原标签、既有二进制及下载链接保持稳定。
