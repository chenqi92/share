# 业务消息（messages）

承载在 [transport.md](transport.md) 定义的 frame 中。本文档逐一列出每个 type
的语义、body 编码与字段。

| type   | 名称           | body 编码 | 方向     |
| ------ | -------------- | --------- | -------- |
| `0x01` | HELLO          | JSON      | 双方     |
| `0x02` | HELLO_ACK      | JSON      | 双方     |
| `0x10` | TEXT           | JSON      | 任意     |
| `0x20` | FILE_OFFER     | JSON      | 发送方→接收方 |
| `0x21` | FILE_ACCEPT    | JSON      | 接收方→发送方 |
| `0x22` | FILE_REJECT    | JSON      | 接收方→发送方 |
| `0x23` | FILE_COMPLETE  | JSON      | 接收方→发送方 |
| `0x25` | FILE_CANCEL    | JSON      | 任意     |
| `0x30` | FILE_CHUNK     | binary    | 发送方→接收方 |
| `0xF0` | PING           | JSON `{}` | 任意     |
| `0xF1` | PONG           | JSON `{}` | 任意     |

未列出的 type 接收方必须按 [transport.md](transport.md) 的规则丢弃并继续。

## 0x01 HELLO

发起方在 TCP 连接建立后立即发送；目标方收到后回 `HELLO_ACK`。

```json
{
  "id": "8b3f...c1",            // 32 hex
  "name": "陈奇 的 MacBook",     // 已解码的原始 UTF-8
  "os": "macos",
  "model": "Mac15,7",
  "fp": "ab12...ef",            // 32 hex (公钥指纹)
  "protocol_versions": [1]      // 本端支持的版本列表
}
```

接收端按以下顺序处理：
1. 选定双方支持的最高版本号；若交集为空，发 `FILE_REJECT` 风格的关闭消息后
   断开。
2. 在本机信任库中查 `fp`：命中则进入 ⑤；未命中则进入 ④（配对，见 security.md）。

## 0x02 HELLO_ACK

字段与 HELLO 完全相同；附加字段 `selected_version: u8` 指明本次连接采用的协议
版本。后续所有 frame 的语义按该版本解释。

## 0x10 TEXT

```json
{
  "id": "uuid v4 字符串",       // 消息 ID，去重用
  "content": "要发的文本",      // UTF-8
  "ts": 1716537600              // 发送方 Unix 时间戳（秒）
}
```

接收方应在 UI 弹一条通知 + 写入"接收记录"。无需 ACK。

## 0x20 FILE_OFFER

```json
{
  "transfer_id": "uuid v4",
  "files": [
    {
      "index": 0,
      "name": "report.pdf",     // 文件名（不含路径分隔符）
      "size": 1048576,          // 字节
      "sha256": "..."           // 64 hex，整文件 SHA-256
    },
    { "index": 1, ... }
  ]
}
```

接收方为每个 `index` 单独发 `FILE_ACCEPT` 或 `FILE_REJECT`。可全部接受、部分
接受、全部拒绝。

## 0x21 FILE_ACCEPT

```json
{
  "transfer_id": "...",
  "index": 0,
  "resume_offset": 0            // 已有的字节数；断点续传 > 0
}
```

发送方收到后从 `resume_offset` 开始按 `FILE_CHUNK` 发数据。

## 0x22 FILE_REJECT

```json
{
  "transfer_id": "...",
  "index": 0,
  "reason": "user_declined"     // user_declined | disk_full | unsupported_name | ...
}
```

## 0x23 FILE_COMPLETE

接收方在收齐某个 `index` 的全部 chunk 且 SHA-256 校验通过后发送：

```json
{ "transfer_id": "...", "index": 0 }
```

校验失败则发 `FILE_CANCEL`（带 reason）替代。

## 0x25 FILE_CANCEL

任意一方可在任何时刻发送，主动放弃一个传输：

```json
{
  "transfer_id": "...",
  "index": null,                // null 表示整个 transfer 全取消；具体 index 仅取消该文件
  "reason": "user_canceled"     // user_canceled | timeout | hash_mismatch | ...
}
```

## 0x30 FILE_CHUNK（二进制）

唯一的二进制 type。body 结构：

```
+-------------------+-------------------+-------------------+
|  transfer_id (16) |   index  (u32 BE) |   offset (u64 BE) |
+-------------------+-------------------+-------------------+
|                    data (剩余字节)                         |
+------------------------------------------------------------+
```

- `transfer_id`：UUID 的 16 字节大端表示（同 RFC 4122）。
- `index`：对应 FILE_OFFER 中文件的 `index`。
- `offset`：本 chunk 在文件中的字节偏移。
- `data`：本 chunk 的实际数据。长度 = frame length - 1 (type) - 16 - 4 - 8 = frame length - 29。

**chunk 大小**：建议 256 KiB；硬上限 4 MiB（见 transport.md）。最后一个 chunk
可短于建议值。

## 0xF0 / 0xF1 PING / PONG

body 固定为 JSON `{}`。任意一方可发，对方收到 PING 必须立即回 PONG。建议每
30 秒一次心跳；连续 3 次未收到 PONG 则关闭连接。
