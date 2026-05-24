# Apple (macOS + iOS)

`MeshDropKit` 是一个 Swift Package，实现协议规范定义的设备身份、mDNS 发现、帧
编解码、控制消息。macOS 与 iOS app 都以它为唯一依赖。

```
apple/
├── Package.swift             # MeshDropKit SPM
├── Sources/MeshDropKit/      # 协议核心（macOS 14+ / iOS 17+）
├── Tests/MeshDropKitTests/
├── MeshDropMac/              # SwiftUI macOS app
│   ├── project.yml           # XcodeGen 规格
│   ├── Sources/
│   ├── Resources/Info.plist
│   └── MeshDrop.entitlements
└── ShareiOS/                 # SwiftUI iOS 17+ app（下一轮重做品牌）
    ├── project.yml
    ├── Sources/
    └── Resources/Info.plist
```

## 构建

### 单测 MeshDropKit

```bash
cd apple
swift test
```

### 生成 Xcode 工程

需要 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`。

```bash
cd apple/MeshDropMac && xcodegen generate && open MeshDropMac.xcodeproj
cd apple/ShareiOS && xcodegen generate && open ShareiOS.xcodeproj
```

### 运行 macOS app

在 Xcode 选 `MeshDropMac` scheme → ⌘R。首次运行系统会弹"MeshDrop 想要在本地
网络上查找并连接到设备"，允许。

### 运行 iOS app

iOS 17+ 真机或模拟器都可以；同一 Wi-Fi 下与 Mac、其他 iOS 设备互看。

## 当前覆盖

- ✅ Identity（Ed25519 密钥 + 指纹；UserDefaults 存储，TODO Keychain）
- ✅ mDNS 发现（NWBrowser + NWListener.Service，含 TXT 字段全部）
- ✅ Frame / Message 编解码 + 单测
- ⚠️ Transport：listener 收到连接后直接 close（骨架），下一步实装 HELLO 握手
- ⚠️ Pairing：未实现
- ⚠️ Text / File 传输：未实现

## TODO

- [ ] Keychain 替换 UserDefaults 存私钥
- [ ] NWConnection 接入 Frame 读写循环
- [ ] HELLO 握手 + 配对 UI
- [ ] TEXT 发送
- [ ] FILE_OFFER / CHUNK / COMPLETE
- [ ] TLS 1.3 双向证书校验
