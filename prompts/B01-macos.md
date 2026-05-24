# MeshDrop · macOS Backend 接入 Prompt

## 端特定任务

把 `apple/MeshDropMac/Sources/` 里的 UI 从 MockData 切到真实 `ShareEngine.shared`。
**并新增 Web Gateway 模块**（macOS 端兼任浏览器的 LAN 桥）。

## 工作范围（严格限定）

- ✅ `apple/MeshDropMac/Sources/`（除 mock 子目录）
- ✅ `apple/Sources/MeshDropKit/`（**只允许新增 `WebGateway.swift` 和必要补丁**，禁止大改既有协议层）
- ✅ `apple/MeshDropMac/Resources/Info.plist`（加 NSLocalNetworkUsageDescription / Bonjour service type 已有则跳过）
- ❌ 其他端目录

## 必做

### 1. UI 切换到真 Engine

逐个文件把 `MockData.shared` / `MockData.devices` 等替换成 `ShareEngine.shared` / `ShareEngine.shared.devices`。

参考 `prompts/B-COMMON.md §UI 怎么改` 段。

特别注意 `AppShell.swift` / `Sidebar.swift` / 各 page 顶层，把：

```swift
@StateObject private var mock = MockData.shared
```

改成

```swift
@StateObject private var engine = ShareEngine.shared
```

并把 `mock.devices` 等绑定全部改成 `engine.devices`。

### 2. 错误 / Loading / 空态

按 B-COMMON 的 §错误处理表实装：
- 顶部 status banner: 显示 `engine.isStarting` / `engine.lastError`
- DiscoveryPage 空态："附近没有 MeshDrop 设备…"
- pendingOffers 自动弹 ReceiveCard.swift（之前 mock 是定时器）

### 3. App 启动时

`MeshDropMacApp.swift` 加：

```swift
.onAppear { Task { await ShareEngine.shared.start() } }
.onDisappear { Task { await ShareEngine.shared.stop() } }
```

注：start() 内部启 NWListener + NWBrowser，需要 com.apple.security.network.server + .network.client entitlement —— 已经在 MeshDrop.entitlements 里，**不要改**。

### 4. Web Gateway 模块（新增）

新增文件：

```
apple/Sources/MeshDropKit/WebGateway.swift   # 通用 gateway 实现（共享给 iOS / linux-mac 不用）
apple/MeshDropMac/Sources/gateway/
├── GatewayService.swift          # macOS 端启停 + 端口管理
└── PairingCodeView.swift         # Settings → "Web 访问" 段：显示 6 字符代码 + URL
```

行为：
- 默认监听 `0.0.0.0:7384`（端口可在 Settings 改）
- 实装 `protocol/companion-bridges.md §4.3` 的 5 个路由：
  - `GET /` → 静态返回 Web fallback UI（**直接读 `apple/MeshDropMac/Resources/web-fallback/` 下的 web 端 build 产物**，本轮先放 placeholder index.html 即可）
  - `WS /api/v1/control` → 命令 + 事件双向通道
  - `POST /api/v1/upload` → multipart
  - `GET /api/v1/download/<offerId>`
- TLS：自签证书，CN = `meshdrop.local`，证书 + 密钥用 `Security.framework` 在 keychain 持久化
- 鉴权：6 字符 pairing code `LR · 4K7M`，每 24h 重新生成，session cookie

实现用 `Network.framework` 的 `NWListener` + 手写 HTTP/1.1 parser 即可（不要引第三方 web framework）。

### 5. Settings 页加 "Web 访问" 段

显示当前 gateway URL + 6 字符 pairing code + QR + 开关。

## 验证

```bash
cd apple/MeshDropMac
xcodegen generate
xcodebuild -project MeshDropMac.xcodeproj -scheme MeshDropMac -configuration Debug \
  -destination 'platform=macOS' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

跑两份实例（开两个 mac 用户 / 两台 mac），互发文本 + 一个 5 MB 文件，SHA-256 校验。

启动后用 Safari 进 `https://<mac-ip>:7384`，看到 placeholder 即 gateway OK。

## PR 标题

`backend(macos): UI 接入 ShareEngine + 新增 Web Gateway`

## 互通证据

至少 1 段 ≥ 15s mp4：mac 互发文本 + 5 MB 文件 + 浏览器进 gateway。

## 不能做

- 不删 `mock/MockData.swift`（Preview 还用）
- 不改 `protocol/{discovery,messages,transport,security}.md`
- 不引第三方 web framework（用 Network.framework 手写）
- gateway 端口默认 7384，可改但要在 UI 给得到入口
- 不在 ShareEngine 里加 print，用 OSLog
