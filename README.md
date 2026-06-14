# MeshDrop

跨平台局域网分享工具，类 AirDrop。同一网段内自动发现安装了本应用的其他设备，
点选目标即可发送一段文字或一组文件。**所有端原生实现**，不走 Electron / Flutter
/ React Native，保证最佳性能与平台体验。

## 平台覆盖

| 平台              | 技术栈                                                | 状态 |
| ----------------- | ----------------------------------------------------- | ---- |
| macOS             | SwiftUI + Network.framework                           | 可构建 / MeshDropKit 测试通过 |
| iOS 17+ / iPadOS  | SwiftUI + Network.framework                           | 与 Apple core 共用实现 |
| iOS 26            | + Liquid Glass (`.glassEffect()`)                     | UI 已接入 |
| tvOS              | SwiftUI focus engine（只接收）                        | 与 Apple core 共用实现 |
| visionOS          | SwiftUI spatial + glass                               | 已接 engine adapter，仍保留 preview mock |
| watchOS           | SwiftUI + WatchConnectivity 桥到 iPhone               | companion bridge |
| Android           | Jetpack Compose + `NsdManager`                        | build + 单元/截图测试通过 |
| Wear OS           | Compose for Wear + WearableDataLayer 桥到 Android     | build 通过，无独立单测 |
| Windows           | WinUI 3 (.NET 8) + `Makaretu.Dns`                     | 已接 ShareEngine/Gateway；需 Windows 环境验证 |
| Linux GUI         | Rust + gtk4-rs + libadwaita + `mdns-sd`               | core 测试 + GUI check 通过 |
| Linux TUI         | Rust + ratatui + `mdns-sd`                            | build/test 通过，当前 0 单测 |
| Web Browser       | React + Vite，通过 Gateway 桥接                       | build 通过；仅显式 `?mock=1` 才进入 mock |

各端共用一份自研协议（见 [protocol/](protocol/README.md)），通过 mDNS / DNS-SD
做服务发现，TCP framing + HELLO / HELLO_ACK + TOFU 指纹信任。v0.1 的 LAN
传输允许明文 TCP；Web Gateway 自身使用 TLS 1.3 自签证书。端到端应用层加密在 v1.0
强制。

> **安全现状（v0.1）**：LAN 传输为明文，TOFU 指纹**只防误连、不抗主动 MITM**
> （`fp` 尚未与密钥/证书绑定，详见 [protocol/security.md](protocol/security.md)）。
> 不要把当前版本宣传为"端到端加密 / 安全传输"。

## 目录布局

```
share/
├── protocol/           # 协议规范（语言无关）— 所有端实现的真相
├── apple/              # Swift Package MeshDropKit + macOS / iOS / iPadOS / tvOS / visionOS / watchOS
├── android/            # Gradle 项目（Kotlin + Compose）
├── wearos/             # Wear OS（Kotlin）
├── windows/            # .NET 8 + WinUI 3 解决方案
├── linux/              # Cargo workspace（Rust + GTK4 + ratatui）
└── web/                # React + Vite
```

每个平台子目录有独立 README 说明如何构建与运行。

## 设计原则

1. **原生 UI**：每端使用平台首选 UI 框架，遵循平台 HIG。
2. **协议先行**：协议规范是真相；所有端按 [protocol/](protocol/) 实现，互通由协议
   合规性保证。
3. **零中间服务器**：mDNS 发现 + 直连 TCP；无信令服务器、无云转发。
4. **首次配对，长期信任**：设备首次连接需用户确认（指纹校验），之后基于公钥指纹
   持续信任，类 SSH 的 TOFU 模型。
5. **不留遗憾**：iOS 26 Liquid Glass、macOS Tahoe 玻璃工具栏、Android 12+ 动态色、
   Windows 11 Mica、Linux libadwaita — 该用的现代效果都用。

## 当前完成度

协议层：
- ✅ mDNS / DNS-SD 服务发现
- ✅ TCP framing（HELLO / HELLO_ACK）
- ✅ TEXT 消息互发
- ✅ FILE_OFFER / ACCEPT / REJECT / CHUNK / COMPLETE / CANCEL 全流程
- ✅ TOFU 配对（指纹首次确认 + 长期信任）
- ✅ FILE_ACCEPT.resume_offset 断点续传（Apple / Android / Windows / Linux）

平台原生功能：
- ✅ Apple 端身份私钥 → Keychain (`kSecAttrAccessibleAfterFirstUnlock`)
- ✅ Windows 身份私钥 → DPAPI
- ✅ Android 身份私钥 → EncryptedSharedPreferences（AndroidKeyStore 派生主密钥）
- ✅ Android Share Target / iOS Share Extension（App Group 队列）
- ✅ Wear OS / Apple Watch companion bridge
- ✅ Settings 重置身份功能
- ⚠️ Linux 身份当前是文件存储（`0o600`，静置未加密），后续切 libsecret

Web Gateway（companion-bridges.md §4.3）：
- ✅ macOS / Windows / Linux GUI 都有 TLS 1.3 自签证书 + WebSocket 控制通道
  + multipart upload + 命令路由 + 事件订阅实现
- ✅ Web live 模式不再隐式回退 mock；dev/截图 mock 必须显式 `?mock=1`
- ⚠️ Windows Gateway 需要在 Windows 环境跑 `dotnet build` 验证

## 本地验证

```bash
./scripts/verify-local.sh
```

脚本会按当前机器能力跑 Web / Android / Wear OS / Linux / Apple 的构建与测试；Windows
WinUI 构建只会在检测到 `dotnet` 且运行在 Windows 时执行。

## 互通证据

协议 conformance 用例见 [protocol/conformance-tests.md](protocol/conformance-tests.md)。
当前仓库包含历史/模板证据，但不少 RESULT.md 仍是 BLOCKED 或待回填；不能把这些模板当作
最新实测 PASS。真实设备矩阵需要另起 conformance 轮次补证据。

## v0.2 计划

- 端到端应用层加密（X25519 + ChaCha20-Poly1305，超出 TLS 之上的消息加密）
- 文件夹批量传输（recursive offer）
- 剪贴板分享协议 type
- 推送通知唤醒接收端
- Linux 身份存储升级（libsecret；Android 已切 EncryptedSharedPreferences）
