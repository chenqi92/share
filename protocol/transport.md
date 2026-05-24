# 传输与帧（transport）

mDNS 完成发现后，发起方与目标方之间建立一条 TCP 长连接，所有业务消息都在
这条连接上以"帧"为单位收发。

## 连接

- 发起方根据 TXT 记录中的 `port` 和已解析的 IP 建立 TCP 连接。
- IPv4 / IPv6 都需支持。优先级：IPv6 → IPv4，与系统 `getaddrinfo` 顺序一致。
- 建立连接后进入 **握手阶段**，握手完成前不得发送业务消息。
- 同一对设备之间允许多条并发连接（用于并发多文件传输）；每条连接独立握手。

## 帧格式

所有数据以 frame 为单位，结构如下：

```
 0                   1                   2                   3
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                          length (u32 BE)                      |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|     type      |                                               |
+-+-+-+-+-+-+-+-+                                               |
|                          body  (length - 1 bytes)             |
|                              ...                               |
```

字段：

| 字段     | 类型    | 说明                                                                    |
| -------- | ------- | ----------------------------------------------------------------------- |
| `length` | u32 BE  | `type + body` 的字节数；最大 16 MiB（16 × 1024 × 1024 = 16 777 216）   |
| `type`   | u8      | 消息类型，见 [messages.md](messages.md)                                 |
| `body`   | bytes   | `length - 1` 字节                                                        |

**body 的解释取决于 type**：

- 控制消息（type ∈ {0x01, 0x02, 0x10, 0x20, 0x21, 0x22 except chunk, 0x23, 0x24,
  0x25, 0xF0, 0xF1}）：body 是 **UTF-8 JSON 文本**。
- 二进制载荷（仅 `0x30 FILE_CHUNK`）：body 是固定头部 + 裸字节，结构在
  [messages.md](messages.md) 中给出。

## 大小限制

| 限制项                  | 值                         |
| ----------------------- | -------------------------- |
| 单帧 length             | ≤ 16 MiB                    |
| FILE_CHUNK data 段      | 推荐 256 KiB，硬上限 4 MiB |
| HELLO / 控制消息 JSON   | ≤ 64 KiB                    |
| 单次 FILE_OFFER 文件数  | ≤ 1024                      |
| 单文件大小              | ≤ 2^63 - 1 字节 (u64)       |

接收方必须先读完 4 字节 length，校验范围（`1 ≤ length ≤ 16 MiB`）后才继续读
body；否则一个恶意构造的 frame header 可能让接收方分配过大缓冲区。

## 错误处理

- length 越界 → 关闭连接，不发响应。
- 未识别 type → 丢弃该 frame（按 length 跳过），继续读下一帧。
- JSON 解析失败 → 关闭连接。
- 连接中断 → 进行中的 FILE 传输状态记入接收端持久化存储，重连后通过
  `FILE_ACCEPT.resume_offset` 续传（见 messages.md）。

## TLS / 加密

v0.1 骨架阶段允许 **明文 TCP**（仅限同局域网；同等于 LocalSend 默认配置）。
正式版本要求所有 TCP 连接 **必须** 包裹在 TLS 1.3 内，证书使用设备自签名
Ed25519 证书，对端身份由 mDNS TXT 中的 `fp` 字段校验。详见
[security.md](security.md)。

骨架与正式版可通过端口号或额外 TXT 字段区分（计划 v1.0 起强制加密）。

## 各端 API 对照

| 平台    | TCP                                                         |
| ------- | ----------------------------------------------------------- |
| Apple   | `Network.framework`: `NWListener` / `NWConnection`         |
| Android | `java.net.ServerSocket` / `Socket` + Kotlin coroutines     |
| Windows | `System.Net.Sockets.TcpListener` / `TcpClient`             |
| Linux   | `tokio::net::{TcpListener, TcpStream}`                     |
