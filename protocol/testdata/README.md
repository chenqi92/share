# Protocol 测试向量

各端实装 frame / message 编解码时应跑这些向量做单元测试，保证字节级跨端兼容
（防止字节序、JSON 转义、UTF-8 / UUID 编码不一致）。

## 文件格式

每个 `frames/<name>.json` 描述一个完整 frame：

```jsonc
{
  "name": "hello-minimal",
  "type_hex": "0x01",
  "type_name": "HELLO",
  "body_json": { ... },                       // 控制消息：JSON 对象
  "body_bytes_hex": "...",                    // 控制消息：JSON 紧凑序列化后的 UTF-8 字节
                                              // FILE_CHUNK：完整 binary body（含 16+4+8 byte 头）
  "frame_bytes_hex": "..."                    // 整 frame：length(u32 BE) + type(u8) + body
}
```

JSON 紧凑序列化约定（与 spec 一致）：
- `separators=(",", ":")`
- `ensure_ascii=False`（UTF-8 原文输出，不转 `\uXXXX`）
- 键序按生成方便，不固定（消费方按 key 解析，不假设顺序）

## 用法重点：**Decoder 测试**

由于 JSON 字段顺序在不同语言 / 库下不能保证一致（Swift JSONEncoder、Kotlin
kotlinx.serialization、Rust serde_json、C# System.Text.Json 各有差异），向量
里固化的 `frame_bytes_hex` 不能直接用来断言 *encoder* 输出。

各端应优先用向量做 **decoder 测试**：

```swift
let spec = try JSONDecoder().decode(FrameSpec.self, from: specJson)
let frameBytes = Data(hex: spec.frameBytesHex)

// 1) frame parse
let (type, body) = try Frame.parse(frameBytes)
XCTAssertEqual(type, 0x10)

// 2) body JSON parse → 字段比较
let msg = try JSONDecoder().decode(TextMessage.self, from: body)
XCTAssertEqual(msg.content, "你好 · world 🌧️")
XCTAssertEqual(msg.ts, 1716537600)
```

这保证不同端互通时，对方发来的字节序列能被本端正确解析。

## Encoder 测试（弱形式）

可以 encode 后只断言：
- frame length 字段对（u32 BE，等于 1 + body.count）
- type byte 对
- body 是合法 UTF-8 JSON 且解析后字段等价

而不要 byte-level 比较 encoder 输出。

## 当前向量

| 名称 | type | 用途 |
| --- | --- | --- |
| `hello-minimal.json` | 0x01 | HELLO，中文 name |
| `text-zh-emoji.json` | 0x10 | TEXT，中文 + Emoji + ASCII，验 UTF-8 安全 |
| `file-offer-single.json` | 0x20 | 单文件 FILE_OFFER |
| `file-chunk-min.json` | 0x30 | FILE_CHUNK binary body（含 11 字节 data）|
| `ping.json` | 0xF0 | 心跳 |

JSON 字段顺序按生成方便排版，消费方不依赖。

## 加新向量

1. 在 `frames/` 加 `<name>.json`，确保 `frame_bytes_hex` 是真的从该 spec 计算出来
2. 在本表添加一行
3. 每端的 frame 编码测试加一组断言

向量永远 append 不删；如发现旧向量与协议规范冲突，先修向量再同步修 spec / 实装。
