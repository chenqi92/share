# MeshDrop 协议规范 v0.1

本目录是 MeshDrop 各端实现的真相。所有 5 端（macOS / iOS / Android / Windows /
Linux）都按此规范实现，互通性由协议合规性而非任何一端的实现保证。

## 协议版本

当前协议版本为 **1**。版本号写在 mDNS TXT 记录的 `v` 字段以及握手消息的
`protocol_versions` 中。客户端选择"双方都支持的最高版本"进行通信；本规范只描述
v1。

## 总览

```
┌─────────────┐                    ┌─────────────┐
│  Device A   │                    │  Device B   │
└──────┬──────┘                    └──────┬──────┘
       │  ① mDNS PTR _meshdrop._tcp     │
       │  广播 / 应答 (含 TXT)            │
       │ ◄──────────────────────────────►│
       │                                  │
       │  ② TCP 连接到 TXT 中声明的端口   │
       │ ──────────────────────────────►  │
       │                                  │
       │  ③ HELLO ↔ HELLO_ACK             │
       │     (含设备 id, name, fp, 版本)  │
       │ ◄──────────────────────────────►│
       │                                  │
       │  ④ 配对（首次连接 / TOFU）       │
       │     接收端 UI 弹窗确认指纹       │
       │                                  │
       │  ⑤ 业务消息                      │
       │     TEXT / FILE_OFFER / ...     │
       │ ◄──────────────────────────────►│
```

四个阶段对应四份子规范：

| 阶段              | 文档                            |
| ----------------- | ------------------------------- |
| ① 服务发现         | [discovery.md](discovery.md)    |
| ② / ③ 连接与握手  | [transport.md](transport.md)    |
| ⑤ 业务消息        | [messages.md](messages.md)      |
| ④ 身份 / 配对 / 加密 | [security.md](security.md)   |

## 字节序与编码

- 多字节整数一律 **大端**（network byte order）。
- 字符串一律 **UTF-8**，无 BOM。
- 控制消息载荷为 **JSON**（UTF-8 编码）；约定字段使用 `snake_case`。
- 二进制载荷（仅 FILE_CHUNK）使用裸字节，长度由 frame header 给出。

## 服务类型

mDNS / DNS-SD 服务类型固定为：

```
_meshdrop._tcp.local.
```

详见 [discovery.md](discovery.md)。

## 端口

应用监听端口在动态端口段（49152–65535）内自选，启动时绑定一个空闲端口，并将
最终端口写入 mDNS TXT 记录的 `port` 字段。**不要**使用固定端口（避免冲突；
mDNS 已经提供了发现机制）。

## 兼容性策略

- TXT 与 JSON 中**未识别的字段必须被忽略**，不能因此报错。
- 接收方对未知 type 的 frame 必须能丢弃并继续读流，不能断开连接。
- 协议升级（v2、v3…）通过新增 type 与字段实现，旧端按上述规则降级。

## 测试向量

各端实现应跑 [protocol/testdata/](testdata/) 下的字节序列做单元测试，
确保 framing、JSON 转义、UUID 编码、UTF-8 字段在跨实现间一致。

当前 11 个黄金向量覆盖 v0.1 所有消息类型（HELLO / HELLO_ACK / TEXT /
FILE_OFFER / FILE_ACCEPT × 2 / FILE_REJECT / FILE_COMPLETE / FILE_CANCEL /
FILE_CHUNK / PING）。Apple 与 Linux 端已在 CI 上跑同一份向量做 decoder
方向断言；其它端跟着加自己语言的等价测试。
