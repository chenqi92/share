# C3 — windows → linux-gui 16 KiB 小文件 — 2026-05-25

| 项             | 值                            |
| -------------- | ----------------------------- |
| 发送端 commit  | 587b2ffe140d41721a0c32062507aa4eaa501d0c (windows) |
| 接收端 commit  | 587b2ffe140d41721a0c32062507aa4eaa501d0c (linux-gui) |
| 网络           | N/A                           |
| 结果           | BLOCKED                       |
| 耗时           | N/A                           |

## 关键观察

未执行。conformance owner 当前运行宿主为 macOS 26.5（arm64），缺少本用例所需的两个 VM/物理机：

- **Windows VM（发送端）**：未配置；本机未安装 .NET 8 SDK，`dotnet` 不可用，无法 `dotnet build windows/MeshDrop.sln`。
- **Linux VM（接收端）**：未配置；无法 `cd linux && cargo build --release -p meshdrop-gui` 并启动 GUI。

由于发送端与接收端均缺失，本次 PR 仅落规范要求的目录骨架与 RESULT.md，证据资产
（`send.mp4` / `recv.mp4` / `send.log` / `recv.log` / `sha256.txt`）留待具备双端环境
后补齐。

## 偏离 / 异常

- 缺少 Windows 与 Linux 双端执行环境，无法采集屏录、日志与 sha256 证据。
- 预期观察项（合规通过时应满足）已在 §协议层引用 与 §预期观察 列出，待复跑时逐项核对。

## 预期观察（待复跑时校验）

依据 [protocol/conformance-tests.md §C3](../../../../protocol/conformance-tests.md) 与
[protocol/messages.md §0x30](../../../../protocol/messages.md)：

- `small.bin` 大小 = 16 384 字节，单一 FILE_CHUNK (`0x30`) 即完成传输，双方 log 中
  chunk frame 计数恰好 = 1。
- FILE_CHUNK header（`Windows.Protocol.Messages.FileChunkHeader`，详见
  [windows/MeshDrop/Protocol/Messages.cs:76](../../../MeshDrop/Protocol/Messages.cs)）：
  - `transfer_id` 16 bytes，UUID 大端表示（`Guid.ToByteArray(bigEndian: true)`）。
  - `index = 0`（FILE_OFFER 中该文件 `index = 0`）。
  - `offset = 0`（首字节起始）。
  - frame body length = 29 + 16 384 = 16 413 bytes。
- 发送端（.NET）与接收端（Rust meshdrop-gui via meshdrop-core）双方 `sha256sum` 完全一致。
- 总耗时 < 1s。

## 协议层引用

- [protocol/conformance-tests.md §一 §C3](../../../../protocol/conformance-tests.md)
- [protocol/messages.md §0x30 FILE_CHUNK](../../../../protocol/messages.md)
- [protocol/transport.md §大小限制](../../../../protocol/transport.md)

## 缺失资产清单

- `send.mp4` — 待 Windows VM 上屏录
- `recv.mp4` — 待 Linux VM 上屏录
- `send.log` — 待 Windows MeshDrop console + frame trace 节选
- `recv.log` — 待 Linux meshdrop-gui frame trace 节选
- `sha256.txt` — 待双方 `sha256sum small.bin` 输出
- `small.bin` — 待 `dd if=/dev/urandom bs=1 count=16384 of=small.bin` 生成
