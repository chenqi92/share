# C6 — linux-tui → windows 拒收 — 2026-05-25

| 项             | 值                                                |
| -------------- | ------------------------------------------------- |
| 发送端 commit  | 587b2ffe140d41721a0c32062507aa4eaa501d0c (linux-tui) |
| 接收端 commit  | 587b2ffe140d41721a0c32062507aa4eaa501d0c (windows)   |
| 网络           | N/A                                               |
| 结果           | BLOCKED                                           |
| 耗时           | N/A                                               |

## 关键观察

未执行端到端。conformance owner 当前运行宿主为 macOS 26.5（arm64），
**Windows 接收端无环境**：

- 本机未安装 `dotnet` SDK；[windows/MeshDrop/MeshDrop.csproj](../../../MeshDrop/MeshDrop.csproj)
  TFM 为 `net8.0-windows10.0.19041.0`（WinUI 3 + Windows App SDK 1.6），
  **只能在 Windows 主机上构建**，无法在 macOS / Linux 上 `dotnet build` 出可运行
  WinUI 3 GUI。
- 无 Windows 11 物理机 / VM，故无法弹出 [windows/MeshDrop/Views/Dialogs/FileOfferDialog.xaml](../../../MeshDrop/Views/Dialogs/FileOfferDialog.xaml)
  → 点「拒绝」按钮。

发送端 Linux TUI 的对照说明见
[linux/screenshots/tui/conformance/C6-20260525/RESULT.md](../../../../linux/screenshots/tui/conformance/C6-20260525/RESULT.md)。

## 偏离 / 异常

- 缺少 Windows 11 host，无法 `dotnet build windows/MeshDrop.sln`、无法运行 WinUI 3 GUI、
  无法采集 `recv.mp4` / `recv.log` / `windows-downloads.png`。
- 实装代码层 reject 路径已检视：[windows/MeshDrop/Transport/ShareEngine.cs:299](../../../MeshDrop/Transport/ShareEngine.cs)
  在 `RespondToFileOffer(offerId, accept: false)` 分支：
  1. 编码 `FileRejectMessage(transferId, 0, "user_declined")` 并发 `MessageType.FILE_REJECT`（`0x22`）；
  2. **不分配 `FileStream`，不创建 save dir**；
  3. 立即 `CloseContextAsync(ctx.Id, null)`。

  → 与 spec §C6「Windows Downloads 目录无 reject-test.bin」一致；
  → 与 spec「双方 log 中可见 FILE_OFFER 与 FILE_REJECT frame；无 FILE_CHUNK」一致。

## 预期观察（待复跑时校验）

依据 [protocol/conformance-tests.md §C6](../../../../protocol/conformance-tests.md)
与 [protocol/messages.md §0x22](../../../../protocol/messages.md)：

1. Windows MeshDrop 主窗口接收到 FILE_OFFER（`transfer_id` 16 bytes UUID + `index=0`
   + `name="reject-test.bin"` + `size=1048576`），UI 弹出 FileOfferDialog；
   文件名、大小、对端名显示无乱码。
2. 用户在 FileOfferDialog 点「拒绝」（中文本地化下按钮文案）。
3. Windows console / log 中可见：
   - `rx FILE_OFFER 0x21` × 1（来自 linux-tui）
   - `tx FILE_REJECT 0x22` × 1（reason="user_declined"）
   - 之后连接 closed；**`rx FILE_CHUNK 0x30` 计数 = 0**。
4. `%USERPROFILE%\Downloads\MeshDrop\<linux-host>\` 目录内：
   - 拒绝完成后**不存在** `reject-test.bin`（连同 `_1`、`_2` 等去重后缀）。
5. Linux 端：
   - stderr 末行同义中文 `Error: 发送失败：对方拒收: user_declined`
   - `echo $?` 非 0（当前实装 = 1）

## 协议层引用

- [protocol/conformance-tests.md §一 §C6](../../../../protocol/conformance-tests.md)
- [protocol/messages.md §0x21 FILE_OFFER](../../../../protocol/messages.md)
- [protocol/messages.md §0x22 FILE_REJECT](../../../../protocol/messages.md)
- [protocol/transport.md §错误处理](../../../../protocol/transport.md)

## 缺失资产清单

- `recv.mp4` — 待 Windows 11 host 上屏录（MeshDrop 主窗口 → FileOfferDialog 弹出 → 点「拒绝」）
- `recv.log` — 待 Windows 端 MeshDrop 进程 stderr / debug console 节选 `FILE_OFFER` / `FILE_REJECT` frame 行
- `windows-downloads.png` — 待 Windows 资源管理器打开 `%USERPROFILE%\Downloads\MeshDrop\` 截图（证明 `reject-test.bin` 未落盘）
- （`send.cast` / `send.log` / `exit-code.txt` / `reject-test.bin` 见
  [linux/screenshots/tui/conformance/C6-20260525/RESULT.md](../../../../linux/screenshots/tui/conformance/C6-20260525/RESULT.md)
  缺失清单）
