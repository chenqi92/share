# MeshDrop · Linux TUI Backend 接入 Prompt

## 端特定任务

把 `linux/crates/meshdrop-tui/src/` 里的 UI 从 mock 切到真实 `meshdrop_core::Engine`。

**TUI 不做 Web Gateway**（只 linux-gui 端做）。

## 工作范围

- ✅ `linux/crates/meshdrop-tui/`
- ❌ `meshdrop-core/` 不动
- ❌ 其他端目录

## 必做

### 1. UI 切到真 Engine

ratatui 项目里 12 个 mock 文件。grep：

```bash
grep -rln "mock" linux/crates/meshdrop-tui/src
```

TUI 接入做法：

- `app.rs` 主循环里启 tokio `Engine`，事件用 `async-channel` 桥进 TUI 事件循环
- 每个 widget 的 data source 改成 `engine.devices` 等 channel
- terminal 重绘节流（≥ 100ms / 帧）避免 CPU 飙

### 2. CLI 子命令真实化

之前 prompt 说 cli 子命令可以是 stub，**本轮全部实装真功能**：

```bash
meshdrop-tui list-devices --json
meshdrop-tui send <peer> "<text>"
meshdrop-tui send-file <peer> ./report.pdf
meshdrop-tui daemon --auto-accept-trusted
```

每个子命令内部启 `Engine`，做完即销（daemon 长跑除外）。

### 3. 错误 / Loading / 空态

TUI status bar 显示 `engine.status` (Starting / Live / Error)。
设备列表为空时显示 "扫描中…" 或 "未发现设备 · 按 r 重试"。

### 4. Daemon 模式实装

`meshdrop-tui daemon` 必须能：
- 后台跑 mDNS + listener
- 自动接受 `trusted` peer 的文件 offer 并保存到 `--save-dir`
- 收到 SIGTERM / Ctrl+C 干净退出
- 不产生交互 prompt（headless 友好）
- 日志走 `tracing` → stderr（可配 `--log-file`）

## 验证

```bash
cd linux
cargo build --release -p meshdrop-tui
./target/release/meshdrop-tui                          # 全屏 TUI
./target/release/meshdrop-tui list-devices --table
./target/release/meshdrop-tui send <peer-name> "hi"
./target/release/meshdrop-tui daemon --save-dir ~/Downloads/meshdrop/
```

互通：1 台 linux 跑 TUI + 1 台 mac，互发文本 + 5 MB 文件。

在 alacritty / kitty / WezTerm 跑过都 OK。

## PR 标题

`backend(linux-tui): UI 接入 meshdrop-core::Engine + CLI 子命令真实化 + daemon 模式`

## 互通证据

- 1 段 ≥ 15s asciinema cast：TUI 中选 peer 发文本
- 1 段截图：`list-devices --table` 真实输出
- 1 段日志：`daemon` 模式收到一个 incoming offer 并自动保存

## 不能做

- 不动 `meshdrop-core/`
- 不删 mock 文件
- 不改 protocol/ 核心规范
- daemon 模式不能弹交互式 prompt
- cli 模式不能泄漏 raw mode 状态
- 不在 widget 里 block 主循环（重 I/O 必须 async）
