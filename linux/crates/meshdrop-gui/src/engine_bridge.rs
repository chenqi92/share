//! 把 meshdrop-core Engine + Web Gateway 接到 GTK 主循环。
//!
//! 设计要点：
//!   * tokio runtime 跑在独立线程；GTK widget 不直调 tokio API。
//!   * 引擎/网关状态通过 `tokio::sync::watch::Receiver` 暴露；
//!     GUI 用 `glib::MainContext::spawn_local` 在 GLib runtime 里 `.await`，
//!     由 GLib 自己分发到 GTK 主循环。Tokio Notify 用裸 waker，跨 runtime 安全。
//!   * 命令（send_text / 决定 pairing 等）由 GTK 回调直接调 ShareEngine 的同步
//!     方法（这些方法只把命令塞进 mpsc::UnboundedSender，不阻塞）。

use anyhow::{Context, Result};
use gtk::glib;
use log::info;
use meshdrop_core::device::Device;
use meshdrop_core::history::HistoryItem;
use meshdrop_core::{GatewayHandle, Identity, PendingFileOffer, PendingPairing, ShareEngine};
use std::cell::{Cell, RefCell};
use std::future::Future;
use std::path::PathBuf;
use std::rc::Rc;
use std::sync::Arc;
use tokio::runtime::Runtime;
use tokio::sync::watch;

#[allow(dead_code)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum EngineStatus {
    Starting,
    Running,
    Error,
}

/// 共享给 UI 各处的句柄。`AppHandle::engine` 提供命令面；`AppHandle::*_rx`
/// 提供观察面。
#[allow(dead_code)]
pub struct AppHandle {
    pub engine: ShareEngine,
    pub gateway: Option<GatewayHandle>,
    pub runtime: Arc<Runtime>,
    pub status: Rc<Cell<EngineStatus>>,
    pub last_error: Rc<RefCell<Option<String>>>,
    pub self_ip: Rc<RefCell<Option<String>>>,
}

// 一些 send_file / clear_history 等 API 当前 UI 没接，留给后续 settings / context
// menu 使用。Rust 默认对 unused public 也报 warn —— 该 impl 整块允许 dead_code
#[allow(dead_code)]
impl AppHandle {
    /// 在专用线程启动 tokio runtime，构造 Engine + Gateway。
    /// 失败时返回 `Err` —— UI 应渲染错误态而不是退出。
    pub fn start() -> Result<Self> {
        let runtime = Arc::new(
            tokio::runtime::Builder::new_multi_thread()
                .enable_all()
                .worker_threads(2)
                .thread_name("meshdrop-tokio")
                .build()
                .context("build tokio runtime")?,
        );

        let identity = Arc::new(Identity::load_or_create().context("identity")?);
        let display_name = default_display_name();
        let model = Some("Linux GUI".to_string());

        let engine = runtime
            .block_on(ShareEngine::start(
                identity.clone(),
                display_name.clone(),
                model.clone(),
            ))
            .context("start ShareEngine")?;

        info!("ShareEngine ready (id={} port={})", identity.id, engine.listen_port);

        // Gateway 启动失败不致命（端口被占 / 缺权限等）。
        let gateway = match runtime.block_on(meshdrop_core::gateway::start(
            engine.clone(),
            meshdrop_core::GATEWAY_DEFAULT_PORT,
        )) {
            Ok(g) => {
                info!("Web Gateway ready (port={}, code={})", g.port, g.pairing_code());
                Some(g)
            }
            Err(e) => {
                log::warn!("Web Gateway 启动失败 — UI 仍可用：{}", e);
                None
            }
        };

        Ok(Self {
            engine,
            gateway,
            runtime,
            status: Rc::new(Cell::new(EngineStatus::Running)),
            last_error: Rc::new(RefCell::new(None)),
            self_ip: Rc::new(RefCell::new(detect_lan_ip())),
        })
    }

    /// 把 watch::Receiver 桥到 GTK 回调。每当 `rx` 更新，
    /// 在 GTK 主线程上调用 `cb(&snapshot)`。
    pub fn observe<T, F>(&self, mut rx: watch::Receiver<T>, cb: F)
    where
        T: Clone + 'static,
        F: Fn(&T) + 'static,
    {
        spawn_local(async move {
            // 初始快照
            cb(&rx.borrow_and_update().clone());
            while rx.changed().await.is_ok() {
                cb(&rx.borrow_and_update().clone());
            }
        });
    }

    pub fn send_text(&self, peer: Device, text: String) {
        self.engine.send_text(peer, text);
    }

    pub fn send_file(&self, peer: Device, path: PathBuf) {
        self.engine.send_file(peer, path);
    }

    pub fn send_files(&self, peer: Device, paths: Vec<PathBuf>) {
        self.engine.send_files(peer, paths);
    }

    pub fn respond_pairing(&self, id: uuid::Uuid, decision: meshdrop_core::PairingDecision) {
        self.engine.respond_pairing(id, decision);
    }

    pub fn respond_offer(&self, id: uuid::Uuid, accept: bool) {
        self.engine.respond_file_offer(id, accept);
    }

    pub fn clear_history(&self) { self.engine.clear_history(); }

    /// 重置身份（security.md §设备身份）。
    /// 删除磁盘上的 id / 私钥文件；当前 engine 仍持旧身份运行，需要 app 重启
    /// 才能让新身份生效。UI 应在 Settings 里点完后提示用户重启。
    pub fn reset_identity_storage() -> anyhow::Result<()> {
        meshdrop_core::Identity::reset_storage()
    }
    pub fn remove_history(&self, id: uuid::Uuid) { self.engine.remove_history(id); }

    pub fn fingerprint(&self) -> String {
        let raw = self.engine.identity.fingerprint.to_uppercase();
        let chars: Vec<char> = raw.chars().collect();
        chars.chunks(4)
            .map(|c| c.iter().collect::<String>())
            .collect::<Vec<_>>()
            .join(" · ")
    }

    pub fn pairing_code(&self) -> Option<String> {
        self.gateway.as_ref().map(|g| g.pairing_code())
    }

    pub fn gateway_port(&self) -> Option<u16> {
        self.gateway.as_ref().map(|g| g.port)
    }

    pub fn devices(&self) -> Vec<Device> { self.engine.devices_rx().borrow().clone() }
    pub fn history(&self) -> Vec<HistoryItem> { self.engine.history_rx().borrow().clone() }
    pub fn pending_pairings(&self) -> Vec<PendingPairing> {
        self.engine.pending_pairings_rx().borrow().clone()
    }
    pub fn pending_offers(&self) -> Vec<PendingFileOffer> {
        self.engine.pending_offers_rx().borrow().clone()
    }
}

fn spawn_local<F: Future<Output = ()> + 'static>(fut: F) {
    glib::MainContext::default().spawn_local(fut);
}

fn default_display_name() -> String {
    if let Ok(host) = std::env::var("HOSTNAME") {
        if !host.is_empty() { return host; }
    }
    std::fs::read_to_string("/etc/hostname")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "MeshDrop Linux".to_string())
}

fn detect_lan_ip() -> Option<String> {
    // 简单做法：连一个 UDP socket 到外部地址（不实际发包）取本地端 IP
    let sock = std::net::UdpSocket::bind("0.0.0.0:0").ok()?;
    sock.connect("198.51.100.1:80").ok()?;   // RFC5737 reserved
    sock.local_addr().ok().map(|a| a.ip().to_string())
}
