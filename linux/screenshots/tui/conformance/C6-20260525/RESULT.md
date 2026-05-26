# C6 — linux-tui → windows 拒收 — 2026-05-25

| 项             | 值                                                |
| -------------- | ------------------------------------------------- |
| 发送端 commit  | 587b2ffe140d41721a0c32062507aa4eaa501d0c (linux-tui) |
| 接收端 commit  | 587b2ffe140d41721a0c32062507aa4eaa501d0c (windows)   |
| 网络           | N/A                                               |
| 结果           | BLOCKED                                           |
| 耗时           | N/A                                               |

## 关键观察

未执行端到端。conformance owner 当前运行宿主为 macOS 26.5（arm64），缺少本用例
所需的物理 Windows 11 / WinUI 3 接收端：

- **Linux 发送端** — `cargo build --release -p meshdrop-tui` 在本机 macOS host
  上跑通（`linux/target/release/meshdrop-tui --version` → `meshdrop-tui 0.1.0`），
  CLI 子命令 `send-file <PEER> <PATH>` 与 spec §C6 步骤 1 用法签名一致：

  ```
  Usage: meshdrop-tui send-file [OPTIONS] <PEER> <PATH>
  Options:
        --wait <WAIT>  [default: 6]
        --name <NAME>
  ```

  但 macOS 上的二进制无法替代 Linux 端：linux-tui 的 conformance 资格要求宿主
  操作系统本身是 Linux（matrix 单元格 `linux-tui ↔ win`）。

- **Windows 接收端** — 本机无 `dotnet` SDK，且 [windows/MeshDrop/MeshDrop.csproj](../../../MeshDrop/MeshDrop.csproj)
  TFM 为 `net8.0-windows10.0.19041.0`（WinUI 3 + Windows App SDK 1.6），**只能在
  Windows 主机上构建**。无 Windows VM / 物理机，无法弹出 FileOfferSheet → 点
  「拒绝」。

由于发送端宿主操作系统与接收端 SDK 均不可用，本次 PR 仅落规范要求的目录骨架
+ RESULT.md（双侧），实际证据资产（`send.cast` / `recv.mp4` / `send.log` /
`recv.log` / `exit-code.txt` / `windows-downloads.png` / `reject-test.bin`）
留待具备 Linux + Windows 双端环境后补齐。

## 偏离 / 异常

- 缺少 Linux host 与 Windows 11 host，无法采集屏录、日志、exit code 截图、
  Windows Downloads 目录截图。
- 预期观察项已在「预期观察（待复跑时校验）」与「实装代码层面 dry-trace」中
  逐条列出，复跑时按编号核对。

## 实装代码层面 dry-trace（C6 reject 路径，纸面验证）

以下不替代真实跑通，仅证明实装在 reject 分支上的关键不变量已就位。

### 1. 发送端 · Linux TUI

入口：[linux/crates/meshdrop-tui/src/cli.rs:355](../../../crates/meshdrop-tui/src/cli.rs)
`async fn send_file(args)`：

- 行 378：`engine.send_file(peer.clone(), path.clone())` —— 走真实
  `meshdrop_core::ShareEngine`，触发 FILE_OFFER (`0x21`) 出帧。
- 行 401：`TransferStatus::Failed(r) => break Outcome::Failed(r.clone())`
  —— 拿到 core 写入的失败 reason。
- 行 419：`Outcome::Failed(reason) => anyhow::bail!("发送失败：{}", reason)`
  —— 经 `anyhow::Result` 冒泡到 `#[tokio::main] async fn main()`
  （[linux/crates/meshdrop-tui/src/main.rs:33](../../../crates/meshdrop-tui/src/main.rs)），
  最终进程退出码为 **1**（anyhow 默认行为）。

→ stderr 实际文案：`Error: 发送失败：对方拒收: user_declined`（同义中文，与
spec「rejected: user_declined（或同义中文）」一致）。
→ exit code = 1（spec PASS 判据要求「非 0」即可；spec §C6 注「约定 3 for
rejected」加注「未来加 CLI 规范文档时固定」，为已知 TODO，非本次阻断项）。

### 2. core · Reject 状态机

[linux/crates/meshdrop-core/src/engine.rs:478](../../../crates/meshdrop-core/src/engine.rs)：

```rust
(ConnState::AwaitingFileAccept, msg_type::FILE_REJECT) => {
    let reason = serde_json::from_slice::<FileRejectMessage>(&body)
        .map(|m| m.reason).unwrap_or_else(|_| "rejected".into());
    if let Some(ctx) = state.contexts.get(&ctx_id) {
        if let Some(h) = ctx.history_id { update_status(state, h, TransferStatus::Failed(format!("对方拒收: {}", reason))); }
    }
    close_ctx(state, ctx_id, None).await;
}
```

→ 收到 FILE_REJECT 后 **立刻 close_ctx**，不会迁入 `SendingFile` 状态，
**绝无 FILE_CHUNK 发出**。

### 3. 接收端 · Windows

[windows/MeshDrop/Transport/ShareEngine.cs:299](../../../../windows/MeshDrop/Transport/ShareEngine.cs)：

```csharp
if (!accept)
{
    _ = Task.Run(async () =>
    {
        try
        {
            var body = MessageCodec.Encode(new FileRejectMessage(offer.Id.ToString(), 0, "user_declined"));
            await ctx.Connection.SendAsync(MessageType.FILE_REJECT, body);
        }
        catch { }
        await CloseContextAsync(ctx.Id, null);
    });
    return;
}
```

→ 拒绝路径 **不分配 FileStream，不调 `Directory.CreateDirectory(dir)`**，
对应 `~/Downloads/MeshDrop/<peer>/reject-test.bin` **不会出现**。

## 预期观察（待复跑时校验）

依据 [protocol/conformance-tests.md §C6](../../../../protocol/conformance-tests.md)
与 [protocol/messages.md §0x22](../../../../protocol/messages.md)：

1. `reject-test.bin` 大小 = 1 048 576 字节，由
   `dd if=/dev/urandom bs=1M count=1 of=reject-test.bin` 生成。
2. Linux stderr 末行包含「rejected」与「user_declined」（中文/英文同义即可），
   形如 `Error: 发送失败：对方拒收: user_declined`。
3. `echo $?` 输出非 0（当前实装为 `1`）。
4. Windows 端 `~/Downloads/MeshDrop/` 下无任何与 `reject-test.bin` 同名/相似文件
   （文件名匹配，含 `_1`、`_2` 等去重后缀也应不存在）。
5. 双方 wire log 中 frame trace：
   - linux send.log：`tx FILE_OFFER 0x21` × 1 → `rx FILE_REJECT 0x22` × 1 → 连接关闭。
   - windows recv.log：`rx FILE_OFFER 0x21` × 1 → `tx FILE_REJECT 0x22` × 1 → 连接关闭。
   - **双侧 `0x30 FILE_CHUNK` 计数恰为 0**。
6. linux-tui 进程退出后无遗留：`ps -ef | grep meshdrop-tui` 应只有当次 `grep` 自身。

## 协议层引用

- [protocol/conformance-tests.md §一 §C6](../../../../protocol/conformance-tests.md)
- [protocol/messages.md §0x21 FILE_OFFER](../../../../protocol/messages.md)
- [protocol/messages.md §0x22 FILE_REJECT](../../../../protocol/messages.md)
- [protocol/transport.md §错误处理](../../../../protocol/transport.md)

## 缺失资产清单

- `reject-test.bin` — 待用 `dd if=/dev/urandom bs=1M count=1 of=reject-test.bin` 在 Linux host 生成
- `send.cast` 或 `send.mp4` — 待 Linux host 上 `asciinema rec send.cast` 包住整个 `meshdrop-tui send-file ...` 调用
- `recv.mp4` — 待 Windows host 屏录（FileOfferSheet 弹出 → 点「拒绝」全过程）
- `send.log` — 待 Linux 端 `RUST_LOG=meshdrop_core=debug` 节选 `FILE_OFFER` / `FILE_REJECT` frame 行
- `recv.log` — 待 Windows 端 console 节选同名 frame 行
- `exit-code.txt` — 待 `meshdrop-tui send-file ...; echo $? > exit-code.txt` 或 `echo $?` 截图
- `windows-downloads.png` — 待 Windows 资源管理器打开 `%USERPROFILE%\Downloads\MeshDrop\` 截图
