# MeshDrop

跨平台局域网分享工具，类 AirDrop。同一网段内自动发现安装了本应用的其他设备，
点选目标即可发送一段文字或一组文件。**所有端原生实现**，不走 Electron / Flutter
/ React Native，保证最佳性能与平台体验。

## 平台覆盖

| 平台      | 技术栈                                  | 状态     |
| --------- | --------------------------------------- | -------- |
| macOS     | SwiftUI + Network.framework             | 骨架     |
| iOS 17+   | SwiftUI + Network.framework             | 骨架     |
| iOS 26    | + Liquid Glass (`.glassEffect()`)       | 骨架     |
| Android   | Jetpack Compose + `NsdManager`          | 骨架     |
| Windows   | WinUI 3 (.NET 8) + `Makaretu.Dns`       | 骨架     |
| Linux     | Rust + gtk4-rs + libadwaita + `mdns-sd` | 骨架     |

各端共用一份自研协议（见 [protocol/](protocol/README.md)），通过 mDNS / DNS-SD
做服务发现，TCP + Noise 风格握手 + AES-256-GCM 做加密传输。

## 目录布局

```
share/
├── protocol/           # 协议规范（语言无关）— 所有端实现的真相
├── apple/              # Swift Package ShareKit + macOS app + iOS app
├── android/            # Gradle 项目（Kotlin + Compose）
├── windows/            # .NET 8 + WinUI 3 解决方案
└── linux/              # Cargo workspace (Rust + GTK4)
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

## 开发顺序

骨架阶段（当前）：
- 协议规范 v0.1 全部完成
- 5 端项目都能 build、跑起来、列出局域网内其他端

下一阶段：
- 文本传输（最简单的消息类型）
- 文件传输（offer / accept / chunk / 断点续传）
- 配对 UI（首次连接指纹确认）

更后：
- 端到端加密真正实装（当前骨架先明文跑 LAN，加密层放在文档里规范）
- 文件夹批量、剪贴板分享、推送通知唤醒接收端
