# MeshDrop · Linux GUI Backend 接入 + Web Gateway Prompt

## 端特定任务

把 `linux/crates/meshdrop-gui/src/` 里的 UI 从 mock 切到真实 `meshdrop_core::Engine`。
**并新增 Web Gateway 模块**（linux GUI 端兼任浏览器的 LAN 桥）。

## 工作范围

- ✅ `linux/crates/meshdrop-gui/`
- ✅ `linux/crates/meshdrop-core/`（只允许新增 web gateway 相关模块，**不动既有协议层**）
- ✅ `linux/Cargo.toml`（workspace 加新依赖时**先问**）
- ❌ 其他端 / `meshdrop-tui/`

## 必做

### 1. UI 切到真 Engine

GTK4 + libadwaita 项目里 18 个 mock 文件。grep：

```bash
grep -rln "mock\|MockData" linux/crates/meshdrop-gui/src
```

每个 view 把 mock 数据源换成 `meshdrop_core::Engine` 的 channel / signal。

GTK4 推荐做法：
- 启动 GUI 时新建 `Engine` actor 跑在 tokio runtime（单独线程）
- 用 `glib::MainContext::channel` 或 `async-channel` 把 engine 事件桥到 GTK 主循环
- ListStore / Sections 模型绑定 engine.devices

### 2. Engine 启动 / 关闭

`main.rs` 启动时：

```rust
let rt = tokio::runtime::Runtime::new()?;
let engine = rt.block_on(async { Engine::new(config).await? });
rt.spawn(async move { engine.run().await });
```

Application::activate 退出钩子里 `engine.stop().await`。

### 3. 错误 / Loading / 空态

`HeaderBar` 顶部 banner: 显示 `engine.status_stream`（Starting / Running / Error）。
`DiscoveryView` 空态 GtkBox 含 "附近没有 MeshDrop 设备…"。

### 4. Web Gateway 模块（新增）

新增：

```
linux/crates/meshdrop-core/src/gateway/    # 跨 linux/mac/win 可复用，但本轮只 mac/win/linux-gui 用
├── mod.rs
├── http.rs        # 简单 HTTP/1.1 server
├── ws.rs          # WebSocket 升级 + 帧解析
├── cert.rs        # 自签 x509
└── pairing.rs     # 6 字符 code 校验

linux/crates/meshdrop-gui/src/gateway/
├── service.rs    # 启动/停止 + 端口管理
└── settings_view.rs  # Settings → Web 访问段
```

实装 `protocol/companion-bridges.md §4.3`：

- `tokio::net::TcpListener` 监听 `0.0.0.0:7384`
- TLS 用 `rustls` + `rustls-pemfile`（**新增依赖，先问**），自签证书 CN = `meshdrop.local`
- 证书 + 密钥存到 `~/.config/meshdrop/cert.pem` / `key.pem`
- 命令路由调 `engine.{send_text, send_file, accept_*}`
- WebSocket 实装：用 `tungstenite` 或 `tokio-tungstenite`（**新增依赖，先问**）
- `GET /` 返回 `linux/data/web-fallback/index.html`（先放 placeholder）

### 5. 加依赖（先问）

`linux/Cargo.toml` 新增（先问 reviewer）：

```toml
[workspace.dependencies]
rustls = "0.23"
rustls-pemfile = "2"
tokio-tungstenite = { version = "0.24", features = ["rustls-tls-native-roots"] }
rcgen = "0.13"  # 自签证书生成
```

## 验证

```bash
cd linux
cargo build --release -p meshdrop-gui
./target/release/meshdrop-gui
```

互通：1 台 linux + 1 台 mac，互发文本 + 5 MB 文件。

浏览器进 `https://<linux-ip>:7384`，看到 placeholder + pairing code。

## PR 标题

`backend(linux-gui): UI 接入 meshdrop-core::Engine + 新增 Web Gateway`

## 互通证据

- 1 段 ≥ 15s mp4：linux ↔ mac 互发
- 1 段截图：浏览器进 gateway

## 不能做

- 不动 `linux/crates/meshdrop-core/` 既有协议层
- 不删 `mock` 文件（dev preview 用）
- 不改 protocol/ 核心规范
- 不在 GTK widget 里直接调 tokio API（统一通过 channel）
- 不引 web framework crate（用 hyper / tokio-tungstenite 手搭）
