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

命令 `payload` **平铺**（字段直接挂 `payload` 下，不再嵌子键）。

| `type` | payload 字段 | 说明 |
| --- | --- | --- |
| `list_devices` | (空 / `{}`) | 让 B 返回当前 LAN 设备清单 |
| `send_text` | `{ peerId, text }` | 让 B 替 A 发文本给指定 peer |
| `send_file_ref` | `{ peerId, fileRef, name, sizeBytes, mime }` | 让 B 替 A 发文件。`fileRef` 取值见 §4 各桥接文件代发约定（**Wear 必须是完整 DataItem path，非裸 id**） |
| `accept_offer` | `{ offerId }` | 接受待审的 incoming file offer（offerId 由 B 推送的事件给出） |
| `reject_offer` | `{ offerId }` | 拒绝 |
| `accept_pairing` | `{ pairingId, trust: bool }` | 接受配对（trust=true 时长信任） |
| `reject_pairing` | `{ pairingId }` | 拒绝配对 |
| `clear_history` | `{ scope: "all" | "sent" | "received" }` | 清历史 |
| `delete_history_item` | `{ itemId }` | 删单条 |
| `get_state` | (空 / `{}`) | 让 B 返回完整状态快照（设备 / 历史 / 待审项） |

### 1.2 命令回执（CMD_RESP，B → A）

**回执 ≠ 事件。** 回执是命令的同步应答，与请求 `id` 一一对应；事件是 B 主动推送、无 `id` 关联（见 §2）。两者的路由约定：

- **Watch Bridge**：回执走 `sendMessage` 的 `replyHandler`（同一次 `sendMessage` 调用内返回），事件走另一条无 `replyHandler` 的 `sendMessage`。靠通道区分，不靠字段。
- **Wear Bridge**：回执走 path `/meshdrop/cmdresp`，事件走 path `/meshdrop/evt`。靠 path 区分。
- 接收方判定：**带 `ok` 字段 ⇒ 回执**；**带 `type` 字段 ⇒ 事件**。两者互斥，A 端按此兜底分流。

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

## 2 · 事件集（EVT，B → A 推送）

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

### 2.1 ⚠ envelope 包裹方式：**payload 平铺（FLAT）**

**这是此前 4 条互通断裂里最致命的一条，定死如下，两侧实现必须一致：**

> `payload` **本身就是** 对应 DTO / 字段集，**不再嵌** `device` / `offer` / `pairing` / `history` 子键。

即：

```json
// ✅ 正确（FLAT）：device_added 的 payload 直接是 Device 对象
{ "type": "device_added", "payload": { "id": "...", "displayName": "...", "kind": "ios", ... } }

// ❌ 错误（嵌套）：不要再包一层 device 子键
{ "type": "device_added", "payload": { "device": { "id": "...", ... } } }
```

所有事件一律 FLAT。各 `payload` 内容见下表（列里的 `Device` / `Offer` / `Pairing` / `HistoryItem` / `InboxItem` 指 §3 的完整 DTO，整体平铺到 `payload`）：

| `type` | payload（FLAT） | id 字段名 | 说明 |
| --- | --- | --- | --- |
| `device_added` | `Device` | — | LAN 新发现一台 |
| `device_removed` | `{ "id": "<deviceId>" }` | `id` | LAN 失联一台。字段名是 **`id`**（不是 `deviceId`） |
| `device_updated` | `Device` | — | 设备元数据变（rename / busy / trusted） |
| `pairing_pending` | `Pairing` | — | 收到新配对请求 |
| `offer_pending` | `Offer` | — | 收到新 incoming file offer |
| `transfer_progress` | `{ "id", "bytesSent", "totalBytes", "speedBps" }` | `id` | 进行中传输进度（节流 ≥ 200ms / 帧）。id 字段名是 **`id`**（不是 `transferId`） |
| `transfer_done` | `{ "id", "ok": bool, "error": string\|null }` | `id` | 传输完成。id 字段名是 **`id`** |
| `history_added` | `HistoryItem` | — | 历史新增（含发送和接收） |
| `inbox_text` | `InboxItem`（`kind="text"`） | — | **仅 Watch Bridge**：phone 收到入站文本 → 内联推 watch |
| `inbox_file_ready` | `InboxItem`（`kind="file"`） | — | **仅 Watch Bridge**：phone 收到入站文件并经 `transferFile` 送达 → 推此事件携 `fileRef` 关联落盘文件 |

> 跨平台一致性约束：
> - **id 字段一律叫 `id`**——`device_removed` / `transfer_progress` / `transfer_done` 的 payload 用 `id`，**禁止** `deviceId` / `transferId`。
> - `inbox_text` / `inbox_file_ready` 是 Watch Bridge 的入站内容中转扩展；Wear Bridge **当前不发**这两类事件（wear 端入站内容仍由 phone 上查看，watch 端只显示 history / offer）。Wear 端可忽略未知 `type`。

事件**单向**，A 收到后更新本地 UI 即可，不需 ack。

---

## 3 · 共享状态 schema（DTO 字段集 = 唯一真相）

下面是**完整字段集**。implementer 的 struct / data class 字段名、类型、可选性必须严格对齐本节（含此前缺的 `ip` / `busy` / `code` / `files[]`）。

### 3.1 字段表

**Device**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | 设备稳定 id（LAN peer id） |
| `displayName` | string | ✅ | 展示名 |
| `kind` | string | ✅ | `mac`/`ios`/`ipad`/`android`/`win`/`linux`/`tv`/`vision`/`watch`/`wear`/`web` |
| `model` | string | 否（默认 `""`） | 型号，如 `MacBook Pro 14 (M3)` |
| `ip` | string | 否（默认 `""`） | LAN IP；watch/wear 仅展示 |
| `rttMs` | int | 否（默认 `0`） | 往返延迟 ms |
| `online` | bool | ✅ | 是否在线 |
| `trusted` | bool | ✅ | 是否已长信任 |
| `busy` | bool | ✅ | 是否忙（传输中等，不可发起新传输） |

**Pairing**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | 配对请求 id（UUID 字符串） |
| `peerName` | string | ✅ | 对端展示名 |
| `code` | string | 否（默认 `""`） | 配对短码（4 字符分组大写，如 `QX8K·L2M`）；无则空串 |
| `fingerprint` | string | ✅ | Ed25519 公钥指纹（32 hex，UI 4 字符分组大写展示） |
| `createdAt` | int64 | ✅ | unix sec |

**FileMeta**（Offer / HistoryItem 的 `files[]` 元素）

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `name` | string | ✅ | 文件名 |
| `sizeBytes` | int64 | ✅ | 字节数 |
| `mime` | string | 否（默认 `application/octet-stream`） | MIME |

**Offer**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | offer id（UUID 字符串） |
| `peerId` | string | ✅ | 来源设备 id |
| `peerName` | string | ✅ | 来源展示名 |
| `kind` | string | ✅ | `text` / `file` / `files` |
| `files` | FileMeta[] | ✅（可空数组） | 文件清单；`kind="text"` 时为 `[]`。**统一用数组，不再用 `fileName`/`sizeBytes` 单字段** |
| `noteText` | string\|null | 否 | 附言 |
| `createdAt` | int64 | ✅ | unix sec |

**HistoryItem**

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | 历史项 id |
| `direction` | string | ✅ | `sent` / `received` |
| `peerName` | string | ✅ | 对端展示名 |
| `kind` | string | ✅ | `text` / `file` / `files` |
| `text` | string\|null | 否 | `kind="text"` 时的内容 |
| `files` | FileMeta[] | 否（默认 `[]`） | `kind` 含 file 时的清单。**统一用数组** |
| `bytesTransferred` | int64 | 否（默认 `0`） | 已传字节 |
| `ok` | bool | ✅ | 是否成功 |
| `completedAt` | int64 | ✅ | unix sec |

**InboxItem**（仅 Watch Bridge，`inbox_text` / `inbox_file_ready` 的 payload）

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | ✅ | = phone 端 history id |
| `peerName` | string | ✅ | 发件人展示名 |
| `kind` | string | ✅ | `text` / `file` |
| `text` | string\|null | 否 | `kind="text"` 的正文 |
| `fileName` | string\|null | 否 | `kind="file"` 文件名 |
| `sizeBytes` | int64\|null | 否 | `kind="file"` 字节数 |
| `fileRef` | string\|null | 否 | `transferFile` 落盘引用（= history id）；文件已送 watch 时非空，超限只推元数据则为 null |
| `receivedAt` | int64 | ✅ | unix sec |

### 3.2 JSON 示例

```json
// Device
{ "id":"uuid", "displayName":"李莉", "kind":"mac", "model":"MacBook Pro 14 (M3)",
  "ip":"192.168.1.42", "rttMs":18, "online":true, "trusted":true, "busy":false }

// Pairing
{ "id":"pairing-uuid", "peerName":"嘉伟", "code":"QX8K·L2M",
  "fingerprint":"zx8kl72m9fq3...", "createdAt":1700000000 }

// Offer
{ "id":"offer-uuid", "peerId":"device-uuid", "peerName":"嘉伟", "kind":"file",
  "files":[{ "name":"slides.pdf", "sizeBytes":1048576, "mime":"application/pdf" }],
  "noteText":"帮我看第 3 节", "createdAt":1700000000 }

// HistoryItem
{ "id":"hist-uuid", "direction":"received", "peerName":"孟茜", "kind":"text",
  "text":"下午发那版改完了吗？", "files":[], "bytesTransferred":0,
  "ok":true, "completedAt":1700000000 }

// get_state / list_devices 的 result
{ "devices":[Device...], "history":[HistoryItem...],
  "pendingPairings":[Pairing...], "pendingOffers":[Offer...] }
```

> `get_state` 的 `result` 四个 key 固定为 `devices` / `history` / `pendingPairings` / `pendingOffers`；`list_devices` 的 `result` 可只含 `devices`（也允许返回完整 `result` 形状的 `devices` 子集）。

---

## 4 · 各桥接的传输层约定

### 4.1 Watch Bridge（WatchConnectivity）

- 命令-回执：`WCSession.sendMessage(_:replyHandler:errorHandler:)`，回执从 `replyHandler` 拿（同一调用内）。
- 事件：另一条 `sendMessage`，`replyHandler` 传 `nil`（单向）。watch 端 `didReceiveMessage` 收到后按「带 `type` ⇒ 事件」分流。
- iPhone 必须保持 `WCSession.default.activate()`，断连由 watch 端重连。

**watch → phone 文件代发（`send_file_ref`）**

1. watch 端 `transferFile(url, metadata:)`，metadata 至少含：
   `{ "v":1, "id":"cmd-<uuid>", "type":"send_file_ref", "peerId":"<peer>", "name":"<filename>", "ref":"<ref>" }`
   `ref` 取 watch 自生成的唯一串（如 `cmd-<uuid>`）；它就是后续命令的 `fileRef`。
2. phone 端 `didReceive file:` 把临时文件移到约定路径
   `Library/Caches/com.welape.meshdrop.watchbridge/<ref>`（ref 取 `metadata["ref"]`）。
3. watch 端**待 transferFile 入队后**再发 `send_file_ref` 命令，`payload.fileRef = "<ref>"`（与 metadata 里的 `ref` 同值）。
4. phone 端命令处理：由 `fileRef` 拼出上述 caches 路径读取文件，交 `ShareEngine.sendFile`。

> 即：Watch 的 `fileRef` = transferFile metadata 里的 `ref`，是一个**裸 token**（不是路径），两端按固定 caches 子目录约定还原路径。

**phone → watch 入站内容中转（`inbox_text` / `inbox_file_ready`）**

- 文本：phone 直接推 `inbox_text`，`payload` = InboxItem（`kind="text"`，正文在 `text`）。
- 文件：phone 先 `transferFile(fileURL, metadata:)`，metadata 含 `{ "ref":"<historyId>", "kind":"inbox_file", "name":..., "peerName":..., "historyId":... }`；再推 `inbox_file_ready`，`payload` = InboxItem（`kind="file"`，`fileRef="<historyId>"`）。watch 端 `didReceive file:` 落到 `Library/Caches/com.welape.meshdrop.inbox/<ref>-<name>`，凭 `ref` 关联到该 InboxItem。
- 文件超 **32 MiB** 时 phone 只推元数据（`fileRef=null`），不传字节，watch 端展示「请在 iPhone 上查看」。

### 4.2 Wear Bridge（WearableDataLayer）

- 命令：`MessageClient.sendMessage(nodeId, "/meshdrop/cmd", bytes)`。
- 回执：phone → wear path `/meshdrop/cmdresp`。
- 事件：phone → wear path `/meshdrop/evt`。
- nodeId 通过 `NodeClient.getConnectedNodes()` 发现，**只选 nearby companion 节点**（`isNearby` 优先），禁止 hardcode。

**wear → phone 文件代发（`send_file_ref`）—— ⚠ 此前断裂点，定死如下**

1. wear 端生成 `transferId`（如 `wear-<uuid>`），DataItem path = `FILES_PREFIX + transferId` 即 `"/meshdrop/files/<transferId>"`。
2. wear 端 `PutDataMapRequest.create(path)`：
   - `dataMap.putAsset("file", asset)` —— **asset key 固定为 `"file"`**；
   - 可附 `putLong("ts", ...)` / `putString("nodeId", ...)`；
   - `.setUrgent()` 后 `DataClient.putDataItem(...)`。
3. wear 端发 `send_file_ref` 命令，**`payload.fileRef` = 完整 DataItem path**（`"/meshdrop/files/<transferId>"`），**不是裸 `transferId`**。`payload` 同时带 `name` / `sizeBytes` / `mime`。
4. phone 端用 `fileRef`（完整 path）查 DataItem：`getDataItems(Uri.parse("wear:" + fileRef))` → 取 `DataMapItem.getDataMap().getAsset("file")` → `DataClient.getFdForAsset(asset)` 读字节落本地缓存 → 得本地 `Uri` 交 `ShareEngine.sendFile`。
   - **必须用 `getAsset("file") + getFdForAsset`**，不能直接读 `DataItem.getData()`（那是 DataMap 序列化体，不是文件字节）。

> 一句话约定：**Wear 的 `fileRef` = 完整 path `/meshdrop/files/<transferId>`；asset key = `"file"`；phone 用 `getAsset("file")+getFdForAsset` 读。** 三者缺一即断。
>
> Wear Bridge 当前不做 phone → wear 的入站文件中转（无 `inbox_*` 事件）；wear 端入站文件仍在 phone 上查看。

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
