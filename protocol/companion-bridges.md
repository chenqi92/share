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
