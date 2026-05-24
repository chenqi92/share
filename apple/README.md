# Apple (macOS + iOS)

`ShareKit` 是一个 Swift Package，实现协议规范定义的设备身份、mDNS 发现、帧编解
码、控制消息。macOS 与 iOS app 都以它为唯一依赖。

```
apple/
├── Package.swift           # ShareKit SPM
├── Sources/ShareKit/       # 协议核心（macOS 14+ / iOS 17+）
├── Tests/ShareKitTests/
├── ShareMac/               # SwiftUI macOS app
│   ├── project.yml         # XcodeGen 规格
│   ├── Sources/
│   ├── Resources/Info.plist
│   └── ShareMac.entitlements
└── ShareiOS/               # SwiftUI iOS 17+ app
    ├── project.yml
    ├── Sources/            # LiquidGlass.swift 内含 iOS 26 适配
    └── Resources/Info.plist
```

## 构建

### 单测 ShareKit

```bash
cd apple
swift test
```

### 生成 Xcode 工程

需要 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`。

```bash
cd apple/ShareMac && xcodegen generate && open ShareMac.xcodeproj
cd apple/ShareiOS && xcodegen generate && open ShareiOS.xcodeproj
```

### 运行 macOS app

在 Xcode 选 `ShareMac` scheme → ⌘R。首次运行系统会弹"MeshDrop 想要在本地
网络上查找并连接到设备"，允许。

### 运行 iOS app

iOS 17+ 真机或模拟器都可以；同一 Wi-Fi 下与 Mac、其他 iOS 设备互看。

## iOS 26 Liquid Glass

[ShareiOS/Sources/LiquidGlass.swift](ShareiOS/Sources/LiquidGlass.swift) 封装了
`.liquidGlass(in:)` 修饰符：

- **iOS 26+ / macOS 26+**：调用 SwiftUI 原生 `.glassEffect(.regular, in: shape)`，
  得到完整的 Liquid Glass 折射 / 高光 / 边缘高亮效果。
- **iOS 17 ~ 25**：自动回退到 `.background(.ultraThinMaterial, in: shape)`，
  视觉接近，触感平直。

需要 **Xcode 26+ (Swift 6.2+)** 构建才会启用 Liquid Glass 分支；旧 Xcode 编译
会自动跳过该分支，运行无影响。

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
