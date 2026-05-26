# C2 — mac → android 文件互发（含中文名）— 2026-05-25

| 项             | 值                                                  |
| -------------- | --------------------------------------------------- |
| 发送端 commit  | 587b2ff（mac，main HEAD）                            |
| 接收端 commit  | 587b2ff（android，main HEAD，未构建成功）            |
| 网络           | N/A（未进入连接阶段）                                |
| 结果           | **FAIL（blocked，未能执行实际传输）**                |
| 耗时           | N/A                                                  |

## 关键观察

1. **Mac 端编译通过**：`xcodegen generate` + `xcodebuild -scheme MeshDropMac
   -configuration Debug -destination 'platform=macOS'` 在本机 ad-hoc 签名下
   `** BUILD SUCCEEDED **`（log 见 `send.log`）。`MeshDrop.app` bundle
   完整产出于 derived data。
2. **Android 端无法启动构建**：仓库内 `android/gradle/wrapper/gradle-wrapper.jar`
   缺失（只有 `gradle-wrapper.properties`），`./gradlew :app:assembleDebug` 报
   `Error: Unable to access jarfile .../gradle/wrapper/gradle-wrapper.jar`。
   详见 android 端目录下 `recv.log`。
3. **无 phone-class Android 运行环境**：`adb devices` 列表为空；本机
   `~/.android/avd/` 仅含 `WearRound.avd`（Wear OS 圆表面），无 phone AVD，
   也未挂载真机。

## 偏离 / 异常

- 测试文件 `测试报告 v2 · 含中文与 Emoji 🌧️.pdf`（5,452,800 字节，5.2 MiB
  随机数据）已在本机生成，`shasum -a 256` 写入 `sha256.txt` 首行。
  Android 端无法落盘第二行（未触发 FILE_COMPLETE）。
- 屏录 `send.mp4` / `recv.mp4` 未采集：Mac 端虽编译通过但未进入实际
  发送界面（avoid 浪费 demo 录制，因对端不存在）；Android 端未构建出
  APK，更无 UI 可录。两端目录各放 `*.mp4.MISSING` 占位说明。

## 复跑此用例需要

1. 把 `android/gradle/wrapper/gradle-wrapper.jar`（gradle 8.11 wrapper jar，
   约 43 KB）补回仓库，或换成系统 `gradle` 安装；
2. 安装 phone-class system image + 创建 phone AVD，或挂一台真机。
3. 两端处于同一 LAN，双方 trusted 库已含对方 fp（或先跑 C5 走 TOFU）。

## 协议层引用

本次 FAIL 与协议层无关，纯运行环境 / 构建脚本问题。理论待覆盖：

- messages.md §0x20 FILE_OFFER
- messages.md §0x21 FILE_ACCEPT
- messages.md §0x23 FILE_COMPLETE
- messages.md §0x30 FILE_CHUNK
- 文件名 UTF-8 跨平台无乱码
