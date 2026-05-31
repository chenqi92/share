# Linux

Cargo workspace，拆成 **共享 core + GUI binary + TUI binary** 三个 crate。
GUI 用 GTK4 / libadwaita；TUI 用 ratatui + crossterm，适合 SSH / headless /
容器场景。

```
linux/
├── Cargo.toml                  # workspace 定义
├── crates/
│   ├── meshdrop-core/          # 协议 + mDNS + 传输 + 引擎 (tokio)
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── protocol.rs     # Frame / Messages / FileChunkHeader
│   │       ├── connection.rs   # tokio TCP 异步帧 I/O
│   │       ├── engine.rs       # 单 task 模型：握手 + 文件传输完整链路
│   │       ├── discovery.rs    # mdns-sd register + browse
│   │       ├── identity.rs     # Ed25519
│   │       ├── trust.rs        # SharedPreferences 风格 JSON 信任库
│   │       ├── history.rs      # HistoryItem / TransferStatus
│   │       ├── device.rs / txt.rs
│   ├── meshdrop-gui/           # bin: meshdrop  (GTK4 + libadwaita)
│   └── meshdrop-tui/           # bin: meshdrop-tui  (ratatui)
├── data/
│   ├── meshdrop.desktop
│   └── icons/hicolor/*/apps/com.welape.meshdrop.linux.png
└── README.md
```

## 系统依赖（仅 GUI 需要）

- **Ubuntu 24.04+**: `sudo apt install libgtk-4-dev libadwaita-1-dev`
- **Fedora 40+**:    `sudo dnf install gtk4-devel libadwaita-devel`
- **Arch**:           `sudo pacman -S gtk4 libadwaita`

TUI 零系统依赖，纯 Rust。

## 构建

```bash
cd linux
cargo build --release                  # 编 core + gui + tui
cargo run --release --bin meshdrop     # GUI
cargo run --release --bin meshdrop-tui # TUI
```

只想编 TUI（开发机无 GTK4 时）：

```bash
cargo build --release -p meshdrop-tui
```

## TUI 操作键

| 按键        | 行为                          |
| ----------- | ----------------------------- |
| `↑/k ↓/j`   | 切换选中设备                  |
| `Enter / i` | 进入文本输入，再按 Enter 发送 |
| `:`         | 命令模式：`:f <路径>` 发文件  |
| `a`         | 接受待审请求（pairing / 文件）|
| `t`         | 接受配对并写入信任库          |
| `r`         | 拒绝待审请求                  |
| `d`         | 删除最近一条历史              |
| `c`         | 清空历史                      |
| `q / Esc`   | 退出                          |

收到配对请求或文件 offer 时自动弹出居中的浮窗，状态机会暂时只接受
`a/t/r` 三种按键直到处理完。

## 安装（GUI 桌面集成）

```bash
sudo install -Dm755 target/release/meshdrop /usr/local/bin/meshdrop
sudo install -Dm755 target/release/meshdrop-tui /usr/local/bin/meshdrop-tui
sudo install -Dm644 data/meshdrop.desktop \
    /usr/local/share/applications/meshdrop.desktop
for size in 48 64 128 256 512; do
  sudo install -Dm644 "data/icons/hicolor/${size}x${size}/apps/com.welape.meshdrop.linux.png" \
    "/usr/share/icons/hicolor/${size}x${size}/apps/com.welape.meshdrop.linux.png"
done
sudo gtk-update-icon-cache /usr/share/icons/hicolor 2>/dev/null || true
```

## 当前覆盖

- ✅ 协议层完整（Frame / 11 个消息 / FileChunkHeader）
- ✅ mDNS 发现 + 信任库 (TOFU)
- ✅ HELLO 握手 + 配对 + 文本 / 文件双向传输（SHA-256 校验）
- ✅ GUI：libadwaita shell 已接 ShareEngine + Web Gateway；`--screenshots` 模式才跳过 engine 使用 mock
- ✅ TUI：ratatui 全键盘 + 自动弹窗，零系统依赖
- ✅ Web Gateway：TLS 自签证书 + `/api/v1/pair` + WebSocket control + upload/download

## TODO

- [ ] 私钥落 libsecret
- [ ] TLS 1.3 双向证书校验（rustls）
- [x] `FILE_ACCEPT.resume_offset` 断点续传
- [ ] GUI 顶部全局 Send 流程继续打磨（逐设备发送已接）
- [ ] Flatpak 打包
