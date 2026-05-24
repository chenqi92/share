# MeshDrop · watch 端 Backend 接入完整 Prompt（自动拼接）

> 这份 prompt 由 prompts/feed.sh 拼接生成：
>   B-COMMON.md + ../protocol/companion-bridges.md + B09-watch.md + B-TESTING.md
> 复制整段给 AI，它将拥有把 watch 端 UI 接入真实 backend 的全部信息。

---

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


---

# 附录：Companion 桥接协议（protocol/companion-bridges.md）

# MeshDrop · Companion 桥接协议（v0.1）

这份文档规范 3 类 **不直接连 LAN** 的端如何通过 **配对的主机端** 间接收发：

| 桥接 | 端 A（不连 LAN） | 端 B（连 LAN 当代理） | 传输层 |
| --- | --- | --- | --- |
| **Watch Bridge** | Apple Watch (watchOS) | iPhone (iOS) | `WatchConnectivity` (`WCSession`) |
| **Wear Bridge** | Wear OS | Android phone | `WearableDataLayer` (Bluetooth/Wi-Fi) |
| **Web Gateway** | 浏览器 (任意 OS) | macOS / Windows / Linux GUI 上的 native client | HTTPS + WebSocket，**LAN 同段** |

三个桥接共用同一组**命令集 + 事件集**（下方），只是传输层不同。

---

## 1 · 命令集（A → B 发起）

端 A 通过桥接给端 B 发命令，端 B 在 LAN 上代为执行。命令用 JSON，按桥接的传输层规范分发。

```json
{
  "v": 1,                       // 协议版本
  "id": "cmd-<uuid>",          // 命令 id，回执用
  "type": "<command>",         // 见下表
  "ts": 1700000000,            // unix sec
  "payload": { ... }           // 命令体
}
```

### 1.1 命令类型

| `type` | payload 字段 | 说明 |
| --- | --- | --- |
| `list_devices` | (空) | 让 B 返回当前 LAN 设备清单 |
| `send_text` | `{ peerId, text }` | 让 B 替 A 发文本给指定 peer |
| `send_file_ref` | `{ peerId, fileRef, name, sizeBytes, mime }` | 让 B 替 A 发文件。`fileRef` 是 A 端的资源标识（Watch: `URL` / Wear: `Asset` / Web: `blob upload token`） |
| `accept_offer` | `{ offerId }` | 接受待审的 incoming file offer（offerId 由 B 推送的事件给出） |
| `reject_offer` | `{ offerId }` | 拒绝 |
| `accept_pairing` | `{ pairingId, trust: bool }` | 接受配对（trust=true 时长信任） |
| `reject_pairing` | `{ pairingId }` | 拒绝配对 |
| `clear_history` | `{ scope: "all" | "sent" | "received" }` | 清历史 |
| `delete_history_item` | `{ itemId }` | 删单条 |
| `get_state` | (空) | 让 B 返回完整状态快照（设备 / 历史 / 待审项） |

### 1.2 命令回执（B → A）

```json
{
  "v": 1,
  "id": "cmd-<uuid>",          // 同请求 id
  "ok": true | false,
  "error": "<msg>" | null,     // ok=false 时
  "result": { ... } | null     // 命令-specific 结果
}
```

`list_devices` / `get_state` 的 `result` 见 §3 状态 schema。

---

## 2 · 事件集（B → A 推送）

LAN 上发生的事，B 主动推给 A。

```json
{
  "v": 1,
  "id": "evt-<uuid>",
  "type": "<event>",
  "ts": 1700000000,
  "payload": { ... }
}
```

| `type` | payload | 说明 |
| --- | --- | --- |
| `device_added` | `Device` | LAN 新发现一台 |
| `device_removed` | `{ id }` | LAN 失联一台 |
| `device_updated` | `Device` | 设备元数据变（rename / busy） |
| `pairing_pending` | `Pairing` | 收到新配对请求 |
| `offer_pending` | `Offer` | 收到新 incoming file offer |
| `transfer_progress` | `{ id, bytesSent, totalBytes, speedBps }` | 进行中传输进度（节流 ≥ 200ms / 帧） |
| `transfer_done` | `{ id, ok: bool, error }` | 传输完成 |
| `history_added` | `HistoryItem` | 历史新增（含发送和接收） |

事件**单向**，A 收到后更新本地 UI 即可，不需 ack。

---

## 3 · 共享状态 schema

### Device

```json
{
  "id": "uuid",
  "displayName": "李莉",
  "kind": "mac" | "ios" | "ipad" | "android" | "win" | "linux" | "tv" | "vision" | "watch" | "wear" | "web",
  "model": "MacBook Pro 14 (M3)",
  "ip": "192.168.1.42",
  "rttMs": 18,
  "online": true,
  "trusted": true,
  "busy": false
}
```

### Pairing

```json
{
  "id": "pairing-uuid",
  "peerName": "嘉伟",
  "code": "QX·8K7·L2M",
  "fingerprint": "ZX8K-L72M-9FQ3-...",
  "createdAt": 1700000000
}
```

### Offer

```json
{
  "id": "offer-uuid",
  "peerId": "device-uuid",
  "peerName": "嘉伟",
  "kind": "text" | "file" | "files",
  "files": [{ "name": "...", "sizeBytes": 1024, "mime": "image/png" }],
  "noteText": "帮我看第 3 节",
  "createdAt": 1700000000
}
```

### HistoryItem

```json
{
  "id": "hist-uuid",
  "direction": "sent" | "received",
  "peerName": "孟茜",
  "kind": "text" | "file" | "files",
  "text": "下午发那版改完了吗？",
  "files": [...],
  "bytesTransferred": 14200000,
  "ok": true,
  "completedAt": 1700000000
}
```

---

## 4 · 各桥接的传输层约定

### 4.1 Watch Bridge（WatchConnectivity）

- 用 `WCSession.sendMessage(_:replyHandler:errorHandler:)` 走命令-回执
- 用 `WCSession.transferUserInfo(_:)` 推送大对象（历史 / 设备列表快照）
- 实时事件（progress / device_added 等）用 `sendMessage` 单向（`replyHandler` 设 nil）
- iPhone 必须保持 `WCSession.default.activate()`，断了由 watch 端重连
- `send_file_ref` 的 `fileRef` 用 `WCSession.transferFile(_:metadata:)`，把 watch 端的文件 URL 转给 phone

### 4.2 Wear Bridge（WearableDataLayer）

- 命令 / 回执用 `MessageClient.sendMessage(nodeId, "/meshdrop/cmd", payload)` 走 path `/meshdrop/cmd`
- 事件用 `MessageClient` 反向 path `/meshdrop/evt`
- 大文件用 `DataClient.putDataItem(...)`，path `/meshdrop/files/<id>`，watch 端订阅 `DataListener` 拉
- nodeId 通过 `NodeClient.getConnectedNodes()` 发现，**只选 nearby + companion 节点**

### 4.3 Web Gateway（HTTPS + WebSocket）

- Gateway 监听 `0.0.0.0:7384`（**默认端口**，可在设置改）
- 路由：
  - `GET /` → 静态 web fallback UI（直接嵌入 native client 二进制）
  - `WS /api/v1/control` → 命令 / 事件 + 回执，all-in-one 双向通道
  - `POST /api/v1/upload` (multipart) → web 端的 `send_file_ref` 前置：先 POST 文件得到 `uploadToken`，再用 `uploadToken` 作为 `send_file_ref.fileRef` 发命令
  - `GET /api/v1/download/<offerId>` → 接受 offer 后下载文件流
- 鉴权：**首次访问**浏览器看 native client UI 上的 6 字符代码 `LR · 4K7M`，填入网页弹框，gateway 校验通过后下发 session cookie（24h 有效）
- TLS：gateway 用自签证书（CN = `meshdrop.local`），首次访问要让用户在浏览器里接受证书（mac 上提示用户加入 keychain）

---

## 5 · 错误处理

- 桥接通道断（watch 离 phone 远 / wear 关蓝牙 / web 网断）：端 A UI 顶部显示 "离线 · OFFLINE · 等待回连"
- 命令超时（无回执 ≥ 10s）：返回 `{ ok: false, error: "timeout" }` 给 UI
- 文件传输中通道断：B 端继续在 LAN 上跑，结束后通过事件 `transfer_done` 补告诉 A

---

## 6 · 版本

`v` 字段每个 message 都带。本规范是 **v=1**。后续协议升级走 `v=2`，B 端要兼容旧 A 端（向后兼容）。


---

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


# MeshDrop · Backend 接入轮测试 + 验收标准

## 测试矩阵（C1~C8）

每端 PR 必须通过其中 **至少 3 个用例**（含 C1）。所有用例都对 `macOS` 这个 reference 端互通。

| 用例 | 内容 | 必过 |
| --- | --- | --- |
| **C1** | 与 macOS 互发一段文本（≤ 100 字符），双方 history 出现该条 | ✅ |
| **C2** | 与 macOS 互发一个 1~10 MB 文件，SHA-256 校验通过 | 推荐 |
| **C3** | 与 macOS 完成一次配对（TOFU），下次连接不再提示 | 推荐 |
| **C4** | 大文件（≥ 100 MB）分片传输，中途无中断 | 可选 |
| **C5** | 与 macOS 同时双向发文件（双工） | 可选 |
| **C6** | 拔网 → 等 ≥ 30s → 重连，对端能自动重新发现并标 online | 可选 |
| **C7** | 拒绝 incoming offer，对端能看到 "已拒绝" 状态 | 可选 |
| **C8** | 中文文件名 / emoji 文件名传输不乱码 | 可选 |

## Companion 端的额外用例

| 端 | 用例 | 说明 |
| --- | --- | --- |
| Apple Watch | C-W1: 通过 iPhone 桥接发文本给 mac | 用 WatchConnectivity 走通 |
| Apple Watch | C-W2: phone 断连时 watch UI 提示 OFFLINE | |
| Wear OS | C-W3: 通过 Android 桥接发文本给 mac | DataLayer |
| Wear OS | C-W4: phone 断连时 wear UI 提示 OFFLINE | |
| Web | C-W5: Safari 进 mac gateway 收发文本 | TLS 自签证书首次接受流程 |
| Web | C-W6: 浏览器关页 → 重开，session 失效 / 重新输入 6 字符码 | |

## 验收 checklist（PR 必带）

```
- [ ] UI 已删 MockData 引用（Preview 仍用 mock 不计）
- [ ] Engine 已接入（grep ShareEngine.shared / MeshDropEngine.Instance / Engine::new 等可见）
- [ ] Loading 态 / 错误态 / 空态都已实装（COMMON §错误处理）
- [ ] 跑过 C1（至少与 mac 互发文本成功）
- [ ] 屏录 ≥ 10s 演示真实互通（不是 mock）
- [ ] commit 中文，无 AI 署名
- [ ] git status 显示只动了本端目录
- [ ] 没动 protocol/{discovery,messages,transport,security}.md
- [ ] 编译一次过（各端 build 命令在 B-prompt 末尾）
```

## 跨端互通测试矩阵（最终回归测试，所有端都合后跑一遍）

```
         mac  ios  ipd  and  win  lgu  ltu  tv   vis  wch  wer  web
   mac    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   ios    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   ipd    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   and    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   win    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓    ✓
   lgu    ✓    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓    ✓
   ltu    ✓    ✓    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓    ✓
   tv     ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓    ✓
   vis    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    ✓    ✓    ✓
   wch    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    -    -
   wer    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    -    -
   web    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    ✓    -    -    -
```

`-` 表示**不要求**互通（companion 端不直接互发）。

回归测试不是每端 PR 必须，是 **本轮全部 PR 合完后**单独做一次。

## PR 模板（复制到 PR body）

```markdown
## 端
<端名>

## 接入方式
- [ ] Native LAN（用 Engine.shared）
- [ ] Watch Bridge（WatchConnectivity）
- [ ] Wear Bridge（WearableDataLayer）
- [ ] Web Gateway client

## 跑过的用例
- [ ] C1 文本互通 ✓ <附 mp4 链接>
- [ ] C2 文件互通 ✓ <附 mp4 链接>
- [ ] C3 配对  
- [ ] ...

## 互通证据
- 屏录 mp4: <附件>
- 日志摘要:
  ```
  <log>
  ```

## 协议歧义（如有）
PROTOCOL ISSUE: <无 / 描述>

## 验收 checklist
- [ ] UI 已删 MockData 引用
- [ ] Loading/错误/空态都有
- [ ] commit 无 AI 署名
- [ ] git status 只动本端目录
- [ ] 编译一次过
```
