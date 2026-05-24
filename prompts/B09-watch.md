# MeshDrop · Apple Watch Backend 接入 Prompt（Companion via WatchConnectivity）

## 端特定任务

Apple Watch 端 **不直连 LAN**，所有操作通过 `WatchConnectivity` 桥接 iPhone（companion）。
iPhone 端的 `WatchBridge` 由 **B02 iOS prompt** 实装。本 prompt 只做 watch 侧。

## 工作范围

- ✅ `apple/MeshDropWatch/Sources/`（除 mock 子目录）
- ✅ `apple/MeshDropWatch/project.yml`（不加 MeshDropKit 依赖——watch 不直接用 engine）
- ❌ 其他端、MeshDropKit、iPhone 端的 bridge 代码（B02 负责）

## 必做

### 1. WCSession 客户端

新增：

```
apple/MeshDropWatch/Sources/bridge/
├── WatchSessionClient.swift     # WCSession activate + 命令发送 + 事件接收
├── WatchEngineProxy.swift       # 模拟 ShareEngine 的接口（让 UI 无感切换）
└── CommandTypes.swift           # 命令 / 事件 JSON 编解码（按 protocol/companion-bridges.md）
```

`WatchEngineProxy` 暴露的 API 必须**和 `ShareEngine` 形状一致**，让 UI 切换时只改类型：

```swift
@MainActor
final class WatchEngineProxy: ObservableObject {
    @Published var devices: [Device] = []
    @Published var history: [HistoryItem] = []
    @Published var pendingOffers: [Offer] = []
    @Published var isOnline: Bool = false        // companion 桥接状态（注意：不是 LAN 状态）

    func sendText(to peerId: String, text: String) async throws { ... }
    func sendFileRef(to peerId: String, fileURL: URL, name: String) async throws { ... }
    func acceptOffer(_ offerId: String) async throws { ... }
    func rejectOffer(_ offerId: String) async throws { ... }
}
```

内部实装：

- 命令：组装 JSON → `WCSession.default.sendMessage(_:replyHandler:)`，replyHandler 里解析回执
- 事件：实现 `WCSessionDelegate.session(_:didReceiveMessage:)`，把事件分发更新 `@Published` 状态
- 文件 send：用 `WCSession.transferFile(_:metadata:)`，metadata 里写 `peerId` + 命令 id

### 2. UI 切到 Proxy

把 watch 端 7 个 mock 文件改成 `WatchEngineProxy.shared`。

特别处理：
- `WCSession.isReachable == false` → 顶部 status 显示 "OFFLINE · iPhone 不在身边"，**禁用所有发送 CTA**（灰底）
- 接收 incoming offer → 弹接收 sheet（沿用现有 UI）
- Complication "● 5 LIVE" 接 `engine.devices.count`

### 3. App 启动

`MeshDropWatchApp.swift`：

```swift
.onAppear { WatchEngineProxy.shared.start() }
```

`start()` 内部 `WCSession.default.delegate = self; WCSession.default.activate()`。

### 4. 错误处理

- `WCSession.activationDidCompleteWith error` → 显示在 UI
- 命令 10s 无回执 → 显示"命令超时"
- iPhone 端 `WatchBridge` 不存在（旧版 iOS app）→ 友好降级

## 验证

```bash
cd apple/MeshDropWatch
xcodegen generate
xcodebuild -project MeshDropWatch.xcodeproj -scheme MeshDropWatch -configuration Debug \
  -destination 'platform=watchOS Simulator,name=Apple Watch Ultra 2 (49mm)' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

互通：watch simulator + iPhone simulator pair + mac 同 LAN。watch 转表冠选 peer → 按发文本 → mac 收到。

## 依赖

**前置依赖：** B02 iOS prompt 必须先合（实装了 iPhone 端的 WatchBridge 服务）。

如果 B02 还没合，先用 mock proxy（保持 UI 工作）+ 在 PR 描述里标 "blocked on B02"。

## PR 标题

`backend(watch): 实装 WatchConnectivity companion proxy`

## 互通证据

- 1 段 ≥ 15s mp4：watch 选 peer 发文本 → iPhone 中转 → mac 收到 → mac 回发 → watch 显示

## 不能做

- 不在 watch 端 import MeshDropKit / 调 NWConnection（不直连 LAN）
- 不删 mock
- 不改 protocol/companion-bridges.md（用规范，别改）
- 不在 SwiftUI View 直接调 WCSession API（统一走 bridge/）
