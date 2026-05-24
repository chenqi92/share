# MeshDrop · Backend 接入共同规范

> 这是 backend 接入轮的 COMMON 文档。每个端的 backend prompt 都引用这份。

## 上一轮回顾

UI mock 阶段完成了——10 个端的 UI 都按 MeshDrop 设计语言重做，但还在用 MockData 假数据。这一轮**把 UI 接到真 backend**。

## 本轮总目标

每端的具体目标只有 1 句：

> **删 MockData，把 UI 接到该端原生的 Engine（或 companion bridge），跑通 LAN 互通。**

## 4 类端的接入方式

| 类 | 端 | 接入方式 |
| --- | --- | --- |
| **Native LAN** | macOS / iOS+iPadOS / Android / Windows / Linux GUI / Linux TUI / tvOS / visionOS | 各自 Engine 已有，UI 切到 `Engine.shared` |
| **Watch Bridge** | Apple Watch | 通过 `WatchConnectivity` 桥接 iPhone（不直连 LAN） |
| **Wear Bridge** | Wear OS | 通过 `WearableDataLayer` 桥接 Android phone |
| **Web Gateway** | Web 浏览器 | 通过 WebSocket 连 native client 上的 gateway |

桥接协议规范见 `protocol/companion-bridges.md`（**必读**）。

## 各端的 Engine 入口

| 端 | Engine 入口 | 文件 |
| --- | --- | --- |
| macOS / iOS / iPadOS / tvOS / visionOS | `ShareEngine.shared` (`@MainActor ObservableObject`) | `apple/Sources/MeshDropKit/ShareEngine.swift` |
| Android | `ShareEngine` 单例（Hilt 注入） | `android/app/src/main/java/com/welape/meshdrop/transport/ShareEngine.kt` |
| Windows | `MeshDropEngine.Instance` (CommunityToolkit.Mvvm) | `windows/MeshDrop/Transport/ShareEngine.cs` |
| Linux GUI / TUI | `meshdrop_core::Engine` (tokio actor) | `linux/crates/meshdrop-core/src/engine.rs` |

## Engine 的最小契约（跨端一致）

无论 Swift / Kotlin / C# / Rust，Engine 必须暴露以下能力（具体方法名各端原生命名风格）：

```
状态（observable / publisher / signal）：
  devices: [Device]
  history: [HistoryItem]
  pendingPairings: [Pairing]
  pendingOffers: [Offer]
  selfDevice: Device

命令（async / suspend / Task）：
  sendText(to: peerId, text: String) async throws
  sendFile(to: peerId, fileURL: URL) async throws -> taskId
  acceptOffer(offerId) / rejectOffer(offerId)
  acceptPairing(pairingId, trust: Bool) / rejectPairing(pairingId)
  clearHistory(scope) / deleteHistoryItem(id)

生命周期：
  start() / stop()    // 启动 / 停止 mDNS + listener
  setDisplayName(name: String)
```

UI 层用观察机制（@Published / StateFlow / INotifyPropertyChanged / signals）绑定这些状态。

## MockData 怎么删 / 怎么改

**禁止删除 MockData 文件本身**——它仍用于 SwiftUI Preview / Compose `@Preview` / Storybook。

**改的是 UI 文件里的引用**：

```swift
// 之前
@StateObject private var data = MockData.shared

// 改后
@StateObject private var engine = ShareEngine.shared
```

```kotlin
// 之前
val devices = MockData.devices.collectAsState()

// 改后  
val devices by shareEngine.devices.collectAsState()
```

```csharp
// 之前
var devices = MockData.Devices;
// 改后
var devices = MeshDropEngine.Instance.Devices;
```

UI 文件里只剩 Preview 用 mock，运行时用 real engine。

## 错误处理 / Loading 态 / 空态

UI 接 real engine 后必须新增以下状态展示（mock 阶段没有）：

| 状态 | UI 表现 |
| --- | --- |
| `engine.isStarting` | 顶部 banner "扫描中 · scanning LAN 192.168.1.0/24" |
| `engine.lastError != nil` | toast / snack "网络出错 — `<错误描述>`" |
| `devices.isEmpty && !isStarting` | 空态卡片 "附近没有 MeshDrop 设备 · 让朋友也打开试试" |
| `pendingOffers.isNotEmpty` | 弹 FileOfferSheet / Dialog（mock 阶段是定时器触发的，现在是真事件） |
| `transfer.progress` | TransferRow 进度条按真实 byte 数实时更新 |

## 跨端互通验收

每端 PR 必须附**真实互通证据**（不是模拟）：

```
1. 至少一段 ≥ 10s 屏录（mp4 / gif），演示：
   你的端 ↔ macOS（reference 端）互发文本 + 互发一个 ≥ 1MB 文件
2. 命令行 dump 帧 traffic 验证协议合规：
   - macOS / iOS: log stream --predicate 'subsystem == "com.welape.meshdrop"'
   - Android: adb logcat | grep MeshDrop
   - Windows: dotnet run + log file
   - Linux: RUST_LOG=meshdrop_core=debug cargo run
3. SHA-256 校验：发送方 + 接收方文件指纹一致
```

## Companion 端的特殊要求

- **Apple Watch / Wear OS / Web** 各自端 PR 的"互通证据"指通过桥接走通：
  - Watch: 屏录 watch ↔ iPhone-companion ↔ mac 三段
  - Wear OS: 屏录 wear ↔ android-companion ↔ mac 三段  
  - Web: 屏录 browser ↔ mac/win/linux-gateway ↔ 另一台 native client
- **作为代理的端**（iOS / Android / mac+win+linux-gui）的 PR 要新增桥接服务模块

## Protocol 改动规则

**冻结**。本轮**不允许改 `protocol/discovery.md` / `messages.md` / `transport.md` / `security.md`** 这 4 个核心 spec。

允许：`protocol/companion-bridges.md` 可以**澄清**（不改语义，加示例 / 错误码补充）。

发现协议有歧义 / 缺字段 → 在 PR 描述里写 "PROTOCOL ISSUE: ..."，不要擅自改协议。等本轮收完，下一轮统一升级到 v0.2。

## Git workflow

- 工作分支 `backend/<端>`
- commit message 中文，无 AI 署名
- PR 标题 `backend(<端>): 接入真实 MeshDropEngine` 或 `backend(<端>): 实装 <bridge> 桥接`
- 必须附跨端互通证据（见 §跨端互通验收）

## 11 条不能做

1. 不删 MockData.swift / mockData.ts 文件（Preview 还要用）
2. 不动 `protocol/{discovery,messages,transport,security}.md`
3. 不动其他端目录
4. 不直推 main
5. 不写任何 AI 署名 / 🤖 / Co-Authored-By
6. 不在 PR 里附 mock 数据生成的截图当"互通证据"
7. 不为了"让代码跑起来"在 UI 层绕过 Engine 自己实现网络
8. 不在 watch / wear / web 端绕过桥接直接连 LAN（除非桥接协议 §1 明确允许）
9. 不在 Engine 里加 print/println 调试 — 用各端原生 logger
10. 不引入新的网络库（每端用原生 Network framework / NsdManager / Makaretu.Dns / mdns-sd）
11. 不在 backend 接入时改 UI 视觉（除非新增 §错误处理 里要求的状态展示）
