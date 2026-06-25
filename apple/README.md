# Apple (macOS / iOS / iPadOS / tvOS / visionOS / watchOS)

`MeshDropKit` 是一个 Swift Package，实现协议规范定义的设备身份、mDNS 发现、帧
编解码、传输引擎、信任库、Web Gateway。所有 Apple 端 app 都以它为唯一依赖。

```
apple/
├── Package.swift                  # MeshDropKit SPM（依赖 apple/swift-certificates）
├── Sources/MeshDropKit/           # 协议核心 + 引擎
├── Tests/MeshDropKitTests/        # XCTest 单元测试（66 个）
├── MeshDropMac/                   # SwiftUI macOS app
├── MeshDropiOS/                   # SwiftUI iOS + iPadOS Universal app
├── MeshDropTV/                    # SwiftUI tvOS app（只接收）
├── MeshDropVision/                # SwiftUI visionOS app（spatial）
└── MeshDropWatch/                 # SwiftUI watchOS app（通过 WatchConnectivity 桥到 iPhone）
```

## 构建

### MeshDropKit 单元测试

```bash
cd apple
swift test                         # 66 测试，覆盖 Frame / WebSocketFrame / Multipart / GatewayCommands / IdentityStore / ResumeStore
```

### 生成 Xcode 工程

需要 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`。

```bash
cd apple/MeshDropMac && xcodegen generate && open MeshDropMac.xcodeproj
cd apple/MeshDropiOS && xcodegen generate && open MeshDropiOS.xcodeproj
cd apple/MeshDropTV && xcodegen generate && open MeshDropTV.xcodeproj
cd apple/MeshDropVision && xcodegen generate && open MeshDropVision.xcodeproj
cd apple/MeshDropWatch && xcodegen generate && open MeshDropWatch.xcodeproj
```

首次运行系统会弹"MeshDrop 想要在本地网络上查找并连接到设备"，允许。

## 当前覆盖（v0.1）

协议层：
- ✅ Identity（Ed25519 + 指纹；Keychain `kSecAttrAccessibleAfterFirstUnlock`）
- ✅ mDNS 发现（NWBrowser + NWListener.Service，TXT 全字段）
- ✅ Frame / Message 编解码 + 单测
- ✅ Connection 状态机（HELLO/HELLO_ACK/TEXT/FILE_OFFER/ACCEPT/REJECT/CHUNK/COMPLETE/CANCEL）
- ✅ TOFU 配对（指纹首次确认 + 长期信任）
- ✅ FILE_ACCEPT.resume_offset 断点续传（ResumeStore）
- ✅ 重置身份（ShareEngine.resetIdentity，Settings UI 入口在 macOS/iOS/tvOS/visionOS 都有）

Web Gateway（仅 macOS 启用，companion-bridges.md §4.3）：
- ✅ TLS 1.3 + 自签 P-256 证书 (CN=meshdrop.local)，缓存 Keychain
- ✅ `POST /api/v1/pair` 配对码 → session token
- ✅ `WS /api/v1/control` 双向命令 + 事件订阅（手写 RFC6455 framing）
- ✅ `POST /api/v1/upload` multipart 暂存
- ✅ `GET /api/v1/download/<historyId>` 流式下载已接收文件

Apple 端独有：
- ✅ Share Extension（iOS / iPadOS）— App Group 队列持久化
- ✅ Web Gateway（macOS）
- ✅ Watch Companion Bridge (`WatchConnectivity`)
- ✅ Apple Silicon / Liquid Glass / Tahoe 玻璃工具栏视觉

## v0.2 计划

- 应用层 E2E 加密（X25519 + ChaCha20-Poly1305）
- 文件夹批量传输
- 推送通知唤醒
- Web Gateway 给 iOS / iPadOS 端也提供（companion-bridges §4.3 规定只 macOS / Win / Linux GUI；可考虑放宽）
