# MeshDrop · iOS + iPadOS Backend 接入 Prompt

## 端特定任务

把 `apple/MeshDropiOS/Sources/` 里的 UI 从 MockData 切到真实 `ShareEngine.shared`。
**并新增 Watch Companion Bridge 模块**（iOS 端兼任 Apple Watch 的 LAN 桥）。

## 工作范围

- ✅ `apple/MeshDropiOS/Sources/`（除 mock 子目录）
- ✅ `apple/Sources/MeshDropKit/`（只允许新增 `WatchBridge.swift`）
- ✅ `apple/MeshDropiOS/Resources/Info.plist`（NSLocalNetworkUsageDescription / NSBonjourServices 已有就跳）
- ❌ 其他端目录

## 必做

### 1. UI 切到真 Engine

参考 `prompts/B-COMMON.md`，把所有 `MockData.shared` 引用换成 `ShareEngine.shared`。

iOS 特别要做的：
- `ChatDetailView` 滑入待 incoming offer 时弹 `FileOfferSheet`（之前 mock 是 timer）
- `DiscoveryView` 设备列表绑定 `engine.devices`
- `MeView` 显示 `engine.selfDevice`

iPadOS（SizeClass 分支）：左侧 Sidebar 也接 `engine.devices`，右侧 detail 切到选中 peer 的对话。

### 2. Share Extension 接入

`MeshDropiOS-ShareExtension/` 里 share extension 处理 SLComposeServiceViewController 后调：

```swift
try await ShareEngine.shared.sendFile(to: peerId, fileURL: tempURL)
```

注意：share extension 是独立 process，需要 App Group + Engine 状态共享。本轮可以走简化路径：

- Share extension 启动时 spawn 一个 short-lived ShareEngine，发完即销
- 或：用 App Group 写入 "pending send" 队列，主 app 启动时排队发

选 **App Group 队列** 方案（更稳）。

### 3. Live Activity

`LiveActivityMock.swift` rename → `LiveActivityController.swift`。订阅 `engine.activeTransfers`（新增 publisher），按真实进度更新 Dynamic Island。

### 4. Watch Bridge 模块（新增）

新增：

```
apple/Sources/MeshDropKit/WatchBridge.swift
apple/MeshDropiOS/Sources/bridge/
└── WatchSessionController.swift    # 启动 WCSession + 命令/事件路由
```

实装 `protocol/companion-bridges.md §1+§2+§4.1`：

- iPhone 端启动 `WCSession.default.activate()`
- `WCSession.delegate.didReceiveMessage` 解析命令（list_devices / send_text / send_file_ref / accept_* / get_state）→ 转给 `ShareEngine.shared` → 把 `result` 通过 `replyHandler` 回执
- LAN 事件（device_added / offer_pending / ...）通过 `sendMessage(_:replyHandler: nil)` 推给 watch
- 收到 `send_file_ref` 时，从 watch 端 `WCSession.transferFile` 拿到文件 URL，然后用 `ShareEngine.shared.sendFile(...)` 发出
- 错误处理：watch 断连 30s 自动停 stream（节流事件不再推）

## 验证

```bash
cd apple/MeshDropiOS
xcodegen generate
xcodebuild -project MeshDropiOS.xcodeproj -scheme MeshDropiOS -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  build
```

互通：装到 2 台 iOS 真机（不能用 simulator 测 mDNS）+ 1 台 mac，三方互发。

## PR 标题

`backend(ios): UI 接入 ShareEngine + 新增 Watch Companion Bridge`

## 互通证据

- 1 段 ≥ 15s mp4：iPhone ↔ iPad ↔ mac 互发
- 1 段 ≥ 10s mp4：测试 Watch Bridge 命令收发（用 watch simulator 也行）

## 不能做

- 不删 mock 文件
- 不改 protocol/ 核心规范
- Share Extension 不要直接调 Engine.shared（用 App Group 队列）
- Watch Bridge 命令处理走 WatchBridge.swift，**不允许**在 SwiftUI View 里直接调 WCSession
