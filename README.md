# MeshDrop

跨平台局域网分享工具，类 AirDrop。同一网段内自动发现安装了本应用的其他设备，
点选目标即可发送一段文字或一组文件。**所有端原生实现**，不走 Electron / Flutter
/ React Native，保证最佳性能与平台体验。

## 平台覆盖

| 平台              | 技术栈                                                | 状态      |
| ----------------- | ----------------------------------------------------- | --------- |
| macOS             | SwiftUI + Network.framework                           | v0.1 完成 |
| iOS 17+ / iPadOS  | SwiftUI + Network.framework                           | v0.1 完成 |
| iOS 26            | + Liquid Glass (`.glassEffect()`)                     | v0.1 完成 |
| tvOS              | SwiftUI focus engine（只接收）                        | v0.1 完成 |
| visionOS          | SwiftUI spatial + glass                               | v0.1 完成 |
| watchOS           | SwiftUI + WatchConnectivity 桥到 iPhone               | v0.1 完成 |
| Android           | Jetpack Compose + `NsdManager`                        | v0.1 完成 |
| Wear OS           | Compose for Wear + WearableDataLayer 桥到 Android     | v0.1 完成 |
| Windows           | WinUI 3 (.NET 8) + `Makaretu.Dns`                     | v0.1 完成 |
| Linux GUI         | Rust + gtk4-rs + libadwaita + `mdns-sd`               | v0.1 完成 |
| Linux TUI         | Rust + ratatui + `mdns-sd`                            | v0.1 完成 |
| Web Browser       | React + Vite，通过 Gateway 桥接                       | v0.1 完成 |

各端共用一份自研协议（见 [protocol/](protocol/README.md)），通过 mDNS / DNS-SD
做服务发现，TCP + Noise 风格握手 + AES-256-GCM 做加密传输。

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

## v0.1 完成度

协议层（所有端按 spec 实装）：
- ✅ mDNS / DNS-SD 服务发现
- ✅ TCP framing（HELLO / HELLO_ACK）
- ✅ TEXT 消息互发
- ✅ FILE_OFFER / ACCEPT / REJECT / CHUNK / COMPLETE / CANCEL 全流程
- ✅ TOFU 配对（指纹首次确认 + 长期信任）
- ✅ FILE_ACCEPT.resume_offset 断点续传（Apple / Android）

平台原生功能：
- ✅ Apple 端身份私钥 → Keychain (`kSecAttrAccessibleAfterFirstUnlock`)
- ✅ Windows 身份私钥 → DPAPI
- ✅ Android Share Target / iOS Share Extension（App Group 队列）
- ✅ Wear OS / Apple Watch companion bridge
- ✅ Settings 重置身份功能

Web Gateway（companion-bridges.md §4.3）：
- ✅ macOS / Windows / Linux GUI 都实装 TLS 1.3 自签证书 + WebSocket 控制通道
  + multipart upload + 命令路由 + 事件订阅
- ✅ macOS 端 GET /api/v1/download/<historyId> 流式下载

## v0.2 计划

- 端到端应用层加密（X25519 + ChaCha20-Poly1305，超出 TLS 之上的消息加密）
- 文件夹批量传输（recursive offer）
- 剪贴板分享协议 type
- 推送通知唤醒接收端
- Android / Linux 身份存储升级（EncryptedSharedPreferences / libsecret）
