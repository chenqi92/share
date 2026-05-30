//! 顶层引擎：单 task 模型，所有事件（用户命令 + 入站连接 + 连接事件）汇聚到
//! 同一 task 处理，状态无需锁，对外通过 watch::Receiver 暴露快照。

use crate::connection::{ConnEvent, Connection};
use crate::device::{Device, DeviceOS};
use crate::discovery::{self, DiscoveryHandle};
use crate::history::{format_bytes, HistoryItem, HistoryKind, TransferDirection, TransferStatus};
use crate::identity::Identity;
use crate::protocol::*;
use crate::trust::TrustStore;
use anyhow::{Context, Result};
use log::{debug, info, warn};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::fs::{File, OpenOptions};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;
use tokio::sync::{mpsc, watch};
use uuid::Uuid;

const CHUNK_SIZE: usize = 256 * 1024;

// ─── 公开类型 ──────────────────────────────────────────────────────────

#[derive(Debug, Clone)]
pub struct PendingPairing {
    pub id: Uuid,
    pub peer: Device,
}

#[derive(Debug, Clone)]
pub struct PendingFileOffer {
    pub id: Uuid,           // = transfer_id
    pub peer: Device,
    pub file_name: String,
    pub file_size: u64,
    pub sha256: String,
}

impl PendingFileOffer {
    pub fn formatted_size(&self) -> String { format_bytes(self.file_size) }
}

#[derive(Debug, Clone, Copy)]
pub enum PairingDecision { Reject, AllowOnce, Trust }

// ─── 引擎句柄 ──────────────────────────────────────────────────────────

#[derive(Clone)]
pub struct ShareEngine {
    pub identity: Arc<Identity>,
    pub display_name: String,
    pub model: Option<String>,
    pub listen_port: u16,
    pub trust_store: TrustStore,
    cmd_tx: mpsc::UnboundedSender<UserCmd>,
    devices_rx: watch::Receiver<Vec<Device>>,
    history_rx: watch::Receiver<Vec<HistoryItem>>,
    pending_pairings_rx: watch::Receiver<Vec<PendingPairing>>,
    pending_offers_rx: watch::Receiver<Vec<PendingFileOffer>>,
    transfer_metrics_rx: watch::Receiver<HashMap<Uuid, TransferMetrics>>,
    clipboard_rx: watch::Receiver<Vec<ClipboardEntry>>,
    throughput_rx: watch::Receiver<SessionThroughput>,
    /// 设置：收到已信任设备的文件 offer 时自动接受。句柄与主任务共享，持久化到配置文件。
    auto_accept: Arc<AtomicBool>,
}

/// 会话级吞吐时间序列：每秒一个桶，上行 / 下行 bytes/sec。最旧在前，最新在后，
/// 长度上限 [`TP_BUCKETS`]（不足时短）。供传输页速度柱状图绘制真实数据用。
#[derive(Clone, Debug, Default)]
pub struct SessionThroughput {
    pub up: Vec<f64>,
    pub down: Vec<f64>,
}

/// 吞吐环形缓冲保留的秒数（柱状图横轴长度）。
pub const TP_BUCKETS: usize = 32;

/// 剪贴板收件箱条目 —— 对端显式推来的剪贴板内容。
#[derive(Clone, Debug)]
pub struct ClipboardEntry {
    pub id: Uuid,
    pub peer_name: String,
    pub content: String,
    pub kind: String,        // text | link | code
    pub received_at_ms: u64,
}

/// 进行中传输的实时指标。Key 为 history.id；进入 terminal 状态时被移除。
#[derive(Clone, Copy, Debug, Default)]
pub struct TransferMetrics {
    /// 平滑后的字节 / 秒。0 表示未收到足够样本。
    pub bytes_per_sec: f64,
    /// 剩余时间（秒）；速率为 0 或 total<=done 时为 None。
    pub eta_seconds: Option<f64>,
}

impl ShareEngine {
    /// 启动引擎：建 TCP listener + mDNS + 后台主任务。
    pub async fn start(
        identity: Arc<Identity>,
        display_name: String,
        model: Option<String>,
    ) -> Result<Self> {
        let listener = TcpListener::bind("0.0.0.0:0").await.context("bind")?;
        let port = listener.local_addr()?.port();
        info!("ShareEngine listening on port {}", port);

        let discovery = discovery::start(identity.clone(), display_name.clone(), model.clone(), port)?;
        let devices_rx = discovery.devices_rx.clone();

        let (cmd_tx, cmd_rx) = mpsc::unbounded_channel::<UserCmd>();
        let (internal_tx, internal_rx) = mpsc::unbounded_channel::<InternalCmd>();
        let (history_tx, history_rx) = watch::channel(Vec::new());
        let (pp_tx, pp_rx) = watch::channel(Vec::new());
        let (po_tx, po_rx) = watch::channel(Vec::new());
        let (tm_tx, tm_rx) = watch::channel(HashMap::<Uuid, TransferMetrics>::new());
        let (clip_tx, clip_rx) = watch::channel(Vec::<ClipboardEntry>::new());
        let (tp_tx, tp_rx) = watch::channel(SessionThroughput::default());
        let auto_accept = Arc::new(AtomicBool::new(load_auto_accept()));

        // 入站 accept 转发器
        let internal_tx_accept = internal_tx.clone();
        tokio::spawn(async move {
            loop {
                match listener.accept().await {
                    Ok((stream, addr)) => {
                        if internal_tx_accept.send(InternalCmd::Incoming(stream, addr)).is_err() {
                            break;
                        }
                    }
                    Err(_) => break,
                }
            }
        });

        // 主任务
        let trust_store = TrustStore::new()?;
        let state = State {
            identity: identity.clone(),
            display_name: display_name.clone(),
            model: model.clone(),
            trust_store: trust_store.clone(),
            history: Vec::new(),
            pending_pairings: Vec::new(),
            pending_offers: Vec::new(),
            contexts: HashMap::new(),
            history_tx,
            pp_tx,
            po_tx,
            tm_tx,
            transfer_metrics: HashMap::new(),
            clip_tx,
            clipboard: Vec::new(),
            tp_tx,
            throughput: SessionThroughput::default(),
            auto_accept: auto_accept.clone(),
            internal_tx,
            _discovery: discovery,
        };
        tokio::spawn(run_main_loop(state, cmd_rx, internal_rx));

        Ok(ShareEngine {
            identity,
            display_name,
            model,
            listen_port: port,
            trust_store,
            cmd_tx,
            devices_rx,
            history_rx,
            pending_pairings_rx: pp_rx,
            pending_offers_rx: po_rx,
            transfer_metrics_rx: tm_rx,
            clipboard_rx: clip_rx,
            throughput_rx: tp_rx,
            auto_accept,
        })
    }

    /// 当前「已信任设备自动接收」开关。
    pub fn auto_accept_from_trusted(&self) -> bool { self.auto_accept.load(Ordering::Relaxed) }
    /// 设置并持久化「已信任设备自动接收」。
    pub fn set_auto_accept(&self, value: bool) {
        self.auto_accept.store(value, Ordering::Relaxed);
        let _ = save_auto_accept(value);
    }

    pub fn devices_rx(&self) -> watch::Receiver<Vec<Device>> { self.devices_rx.clone() }
    pub fn history_rx(&self) -> watch::Receiver<Vec<HistoryItem>> { self.history_rx.clone() }
    pub fn pending_pairings_rx(&self) -> watch::Receiver<Vec<PendingPairing>> { self.pending_pairings_rx.clone() }
    pub fn pending_offers_rx(&self) -> watch::Receiver<Vec<PendingFileOffer>> { self.pending_offers_rx.clone() }
    pub fn transfer_metrics_rx(&self) -> watch::Receiver<HashMap<Uuid, TransferMetrics>> { self.transfer_metrics_rx.clone() }
    pub fn clipboard_rx(&self) -> watch::Receiver<Vec<ClipboardEntry>> { self.clipboard_rx.clone() }
    pub fn throughput_rx(&self) -> watch::Receiver<SessionThroughput> { self.throughput_rx.clone() }

    pub fn send_text(&self, peer: Device, content: String) {
        let _ = self.cmd_tx.send(UserCmd::SendText { peer, content });
    }

    /// 显式推送剪贴板内容给对端（隐私上仅在用户点按时调用，不后台同步）。
    pub fn push_clipboard(&self, peer: Device, content: String, kind: String) {
        let _ = self.cmd_tx.send(UserCmd::PushClipboard { peer, content, kind });
    }

    pub fn send_file(&self, peer: Device, path: PathBuf) {
        let _ = self.cmd_tx.send(UserCmd::SendFile { peer, path });
    }

    /// 批量发送：每个路径独立 offer + 独立 history 条目，按顺序入队 SendFile。
    /// 当前每文件新建一条连接；后续可改协议层批量。
    pub fn send_files(&self, peer: Device, paths: Vec<PathBuf>) {
        for path in paths {
            let _ = self.cmd_tx.send(UserCmd::SendFile { peer: peer.clone(), path });
        }
    }

    pub fn respond_pairing(&self, id: Uuid, decision: PairingDecision) {
        let _ = self.cmd_tx.send(UserCmd::RespondPairing { id, decision });
    }

    pub fn respond_file_offer(&self, id: Uuid, accept: bool) {
        let _ = self.cmd_tx.send(UserCmd::RespondOffer { id, accept });
    }

    pub fn remove_history(&self, id: Uuid) {
        let _ = self.cmd_tx.send(UserCmd::RemoveHistory(id));
    }

    pub fn clear_history(&self) {
        let _ = self.cmd_tx.send(UserCmd::ClearHistory);
    }

    /// 主动取消进行中的传输（发送方 / 接收方都能调）。
    /// 见 protocol/messages.md §0x25 FILE_CANCEL。
    pub fn cancel_transfer(&self, history_id: Uuid) {
        let _ = self.cmd_tx.send(UserCmd::CancelTransfer { history_id });
    }

    /// 重发失败 / 取消的发送项。查 outgoing 失败项，源文件存在且可读时
    /// 调 send_file 走完整流程（新建独立 history 条目）。源失效时静默不动。
    pub fn retry_transfer(&self, history_id: Uuid) {
        let _ = self.cmd_tx.send(UserCmd::RetryTransfer { history_id });
    }
}

// ─── 命令枚举 ──────────────────────────────────────────────────────────

enum UserCmd {
    SendText { peer: Device, content: String },
    PushClipboard { peer: Device, content: String, kind: String },
    SendFile { peer: Device, path: PathBuf },
    RespondPairing { id: Uuid, decision: PairingDecision },
    RespondOffer { id: Uuid, accept: bool },
    /// 主动取消传输 — 查 ctx by history_id，发 FILE_CANCEL 给对端，关 ctx
    CancelTransfer { history_id: Uuid },
    /// 重发已失败 / 取消的发送项
    RetryTransfer { history_id: Uuid },
    RemoveHistory(Uuid),
    ClearHistory,
}

enum InternalCmd {
    Incoming(tokio::net::TcpStream, std::net::SocketAddr),
    ConnEvent { ctx_id: Uuid, event: ConnEvent },
    /// 后台 sha256 task 算完，主循环继续建连。
    FileHashReady {
        history_id: Uuid,
        peer: Device,
        path: PathBuf,
        size: u64,
        name: String,
        sha256: Result<String, String>,
    },
    /// 接收侧 finish 校验完成。`ok` 表示 sha256 与 expected 一致。
    ReceiveHashVerified {
        ctx_id: Uuid,
        ok: bool,
    },
}

// ─── 主任务状态 ────────────────────────────────────────────────────────

struct State {
    identity: Arc<Identity>,
    display_name: String,
    model: Option<String>,
    trust_store: TrustStore,

    history: Vec<HistoryItem>,
    pending_pairings: Vec<PendingPairing>,
    pending_offers: Vec<PendingFileOffer>,
    contexts: HashMap<Uuid, ConnCtx>,

    history_tx: watch::Sender<Vec<HistoryItem>>,
    pp_tx: watch::Sender<Vec<PendingPairing>>,
    po_tx: watch::Sender<Vec<PendingFileOffer>>,
    tm_tx: watch::Sender<HashMap<Uuid, TransferMetrics>>,
    transfer_metrics: HashMap<Uuid, TransferMetrics>,
    clip_tx: watch::Sender<Vec<ClipboardEntry>>,
    clipboard: Vec<ClipboardEntry>,
    tp_tx: watch::Sender<SessionThroughput>,
    throughput: SessionThroughput,
    auto_accept: Arc<AtomicBool>,
    internal_tx: mpsc::UnboundedSender<InternalCmd>,
    _discovery: DiscoveryHandle,
}

struct ConnCtx {
    #[allow(dead_code)] // 保留备日志 / debug；构造时存但当前无读取者
    id: Uuid,
    connection: Connection,
    role: Role,
    state: ConnState,
    peer: Option<Device>,
    history_id: Option<Uuid>,
    transfer_id: Option<Uuid>,
    pending_offer_id: Option<Uuid>,

    // 文件
    source_path: Option<PathBuf>,
    save_path: Option<PathBuf>,
    expected_sha256: Option<String>,
    file_size: u64,
    sent_bytes: u64,
    received_bytes: u64,
    file_input: Option<File>,
    file_output: Option<File>,

    // 速率窗口（chunk 触发；100ms 节流 + α=0.3 EMA）
    last_sample: Option<Instant>,
    last_sample_bytes: u64,
    ema_bytes_per_sec: f64,
}

enum Role {
    Server,
    Client { target: Device, payload: ClientPayload },
}

enum ClientPayload {
    Text(String),
    Clipboard { content: String, kind: String },
    // path 当前由 ConnCtx.source_path 持有；这里冗余但保留写法清晰
    File { #[allow(dead_code)] path: PathBuf, size: u64, sha256: String, name: String },
}

#[derive(Debug, Clone)]
#[allow(dead_code)]  // Closed 变体保留作未来终止态使用；当前 close_ctx 路径不显式赋
enum ConnState {
    AwaitingHello,
    AwaitingPairApproval(Uuid),  // pairing id
    AwaitingHelloAck,
    AwaitingFileAccept,
    SendingFile,
    Ready,
    ReceivingFile,
    Closed,
}

// ─── 主循环 ────────────────────────────────────────────────────────────

async fn run_main_loop(
    mut state: State,
    mut user_rx: mpsc::UnboundedReceiver<UserCmd>,
    mut internal_rx: mpsc::UnboundedReceiver<InternalCmd>,
) {
    let mut tp_tick = tokio::time::interval(Duration::from_secs(1));
    tp_tick.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
    loop {
        tokio::select! {
            Some(cmd) = user_rx.recv() => handle_user_cmd(&mut state, cmd).await,
            Some(cmd) = internal_rx.recv() => handle_internal_cmd(&mut state, cmd).await,
            _ = tp_tick.tick() => sample_throughput(&mut state),
            else => break,
        }
    }
}

/// 每秒采样一次：把进行中传输的瞬时速率按方向汇总成一个时间桶，推入环形序列。
fn sample_throughput(state: &mut State) {
    let mut up = 0.0;
    let mut down = 0.0;
    for h in &state.history {
        if !matches!(h.status, TransferStatus::Transferring { .. }) { continue; }
        if let Some(m) = state.transfer_metrics.get(&h.id) {
            match h.direction {
                TransferDirection::Outgoing => up += m.bytes_per_sec,
                TransferDirection::Incoming => down += m.bytes_per_sec,
            }
        }
    }
    push_bucket(&mut state.throughput.up, up);
    push_bucket(&mut state.throughput.down, down);
    let _ = state.tp_tx.send(state.throughput.clone());
}

fn push_bucket(buf: &mut Vec<f64>, v: f64) {
    buf.push(v);
    if buf.len() > TP_BUCKETS {
        let excess = buf.len() - TP_BUCKETS;
        buf.drain(0..excess);
    }
}

async fn handle_user_cmd(state: &mut State, cmd: UserCmd) {
    match cmd {
        UserCmd::SendText { peer, content } => start_send_text(state, peer, content).await,
        UserCmd::PushClipboard { peer, content, kind } => start_push_clipboard(state, peer, content, kind).await,
        UserCmd::SendFile { peer, path } => start_send_file(state, peer, path).await,
        UserCmd::RespondPairing { id, decision } => respond_pairing(state, id, decision).await,
        UserCmd::RespondOffer { id, accept } => respond_offer(state, id, accept).await,
        UserCmd::CancelTransfer { history_id } => cancel_transfer(state, history_id).await,
        UserCmd::RetryTransfer { history_id } => retry_transfer(state, history_id).await,
        UserCmd::RemoveHistory(id) => {
            state.history.retain(|h| h.id != id);
            let _ = state.history_tx.send(state.history.clone());
        }
        UserCmd::ClearHistory => {
            state.history.clear();
            let _ = state.history_tx.send(state.history.clone());
        }
    }
}

/// 主动取消传输：找 history_id 对应的 ctx，发 FILE_CANCEL 给对端，关 ctx。
async fn cancel_transfer(state: &mut State, history_id: Uuid) {
    // 查 ctx
    let ctx_id = state.contexts.iter()
        .find(|(_, c)| c.history_id == Some(history_id))
        .map(|(id, _)| *id);
    let Some(ctx_id) = ctx_id else {
        // ctx 已结束（传输完毕 / 早关），只更新历史
        update_status(state, history_id, TransferStatus::Canceled);
        return;
    };

    // 接收态：关 file_output + 删半成品
    let (transfer_id, save_path, is_receiving) = {
        let ctx = state.contexts.get_mut(&ctx_id).unwrap();
        let is_recv = matches!(ctx.state, ConnState::ReceivingFile);
        if is_recv {
            if let Some(mut out) = ctx.file_output.take() { let _ = out.flush().await; }
        }
        (ctx.transfer_id, ctx.save_path.clone(), is_recv)
    };
    if is_receiving {
        if let Some(path) = &save_path {
            let _ = tokio::fs::remove_file(path).await;
        }
    }

    // 发 FILE_CANCEL（whole transfer, index=null）
    if let Some(tid) = transfer_id {
        let cancel = FileCancelMessage {
            transfer_id: tid.to_string(),
            index: None,
            reason: "user_canceled".into(),
        };
        let body = serde_json::to_vec(&cancel).unwrap_or_default();
        if let Some(ctx) = state.contexts.get(&ctx_id) {
            let _ = ctx.connection.send(msg_type::FILE_CANCEL, body);
        }
    }

    update_status(state, history_id, TransferStatus::Canceled);
    close_ctx(state, ctx_id, None).await;
}

async fn handle_internal_cmd(state: &mut State, cmd: InternalCmd) {
    match cmd {
        InternalCmd::Incoming(stream, addr) => {
            let conn = Connection::from_stream(stream, addr);
            let ctx_id = Uuid::new_v4();
            spawn_event_forwarder(&state.internal_tx, ctx_id, conn.events_rx.clone());
            state.contexts.insert(ctx_id, ConnCtx::new_server(ctx_id, conn));
        }
        InternalCmd::ConnEvent { ctx_id, event } => match event {
            ConnEvent::Ready => on_ready(state, ctx_id).await,
            ConnEvent::Frame { msg_type, body } => on_frame(state, ctx_id, msg_type, body).await,
            ConnEvent::Closed(reason) => close_ctx(state, ctx_id, reason).await,
        }
        InternalCmd::FileHashReady { history_id, peer, path, size, name, sha256 } => {
            on_file_hash_ready(state, history_id, peer, path, size, name, sha256).await
        }
        InternalCmd::ReceiveHashVerified { ctx_id, ok } => {
            on_receive_hash_verified(state, ctx_id, ok).await
        }
    }
}

// ─── 出方 ─────────────────────────────────────────────────────────────

async fn start_send_text(state: &mut State, peer: Device, content: String) {
    let item = HistoryItem::new(peer.clone(), TransferDirection::Outgoing,
        HistoryKind::Text(content.clone()), TransferStatus::Pending);
    state.history.insert(0, item.clone());
    let _ = state.history_tx.send(state.history.clone());

    let Some(host) = peer.host.clone() else {
        update_status(state, item.id, TransferStatus::Failed("无可用 IP".into()));
        return;
    };
    let conn = Connection::connect(host, peer.port);
    let ctx_id = Uuid::new_v4();
    spawn_event_forwarder(&state.internal_tx, ctx_id, conn.events_rx.clone());

    let mut ctx = ConnCtx::new_client(ctx_id, conn,
        Role::Client { target: peer, payload: ClientPayload::Text(content) },
        ConnState::AwaitingHelloAck);
    ctx.history_id = Some(item.id);
    state.contexts.insert(ctx_id, ctx);
}

/// 显式推送剪贴板：建客户端连接，HELLO/ACK 后发 CLIPBOARD，不留 history。
async fn start_push_clipboard(state: &mut State, peer: Device, content: String, kind: String) {
    if content.is_empty() { return; }
    let Some(host) = peer.host.clone() else { return };
    let conn = Connection::connect(host, peer.port);
    let ctx_id = Uuid::new_v4();
    spawn_event_forwarder(&state.internal_tx, ctx_id, conn.events_rx.clone());
    let ctx = ConnCtx::new_client(ctx_id, conn,
        Role::Client { target: peer, payload: ClientPayload::Clipboard { content, kind } },
        ConnState::AwaitingHelloAck);
    state.contexts.insert(ctx_id, ctx);
}

/// 重发已失败 / 取消的发送项。查 outgoing 失败项，源文件路径仍可读时
/// 调 start_send_file 走完整流程（新建独立 history 条目）；源失效时静默不动。
async fn retry_transfer(state: &mut State, history_id: Uuid) {
    let Some(item) = state.history.iter().find(|h| h.id == history_id).cloned() else { return };
    if item.direction != TransferDirection::Outgoing { return; }
    let (peer, path) = match &item.kind {
        HistoryKind::File { name: _, size: _, path: Some(p) } => (item.peer.clone(), p.clone()),
        _ => return,
    };
    // 路径仍可读？
    if tokio::fs::metadata(&path).await.is_err() { return; }
    start_send_file(state, peer, path).await;
}

async fn start_send_file(state: &mut State, peer: Device, path: PathBuf) {
    let metadata = match tokio::fs::metadata(&path).await {
        Ok(m) => m,
        Err(e) => {
            warn!("open file failed: {}", e);
            return;
        }
    };
    let size = metadata.len();
    let name = path.file_name().and_then(|n| n.to_str())
        .unwrap_or("file").to_string();

    let item = HistoryItem::new(peer.clone(), TransferDirection::Outgoing,
        HistoryKind::File { name: name.clone(), size, path: Some(path.clone()) },
        TransferStatus::Pending);
    state.history.insert(0, item.clone());
    let _ = state.history_tx.send(state.history.clone());

    // 后台算 sha256，算完通过 InternalCmd::FileHashReady 回主循环建连。
    // 这样大文件（几 GiB）哈希期间主循环仍能处理别的 UserCmd / InternalCmd。
    let history_id = item.id;
    let tx = state.internal_tx.clone();
    let path_for_task = path.clone();
    let peer_for_task = peer.clone();
    let name_for_task = name.clone();
    tokio::spawn(async move {
        let sha = compute_sha256_async(&path_for_task).await
            .map_err(|e| format!("hash: {}", e));
        let _ = tx.send(InternalCmd::FileHashReady {
            history_id,
            peer: peer_for_task,
            path: path_for_task,
            size,
            name: name_for_task,
            sha256: sha,
        });
    });
}

/// 后台 sha256 task 完成后由主循环继续：建连接 + 进 AwaitingHelloAck。
async fn on_file_hash_ready(
    state: &mut State,
    history_id: Uuid,
    peer: Device,
    path: PathBuf,
    size: u64,
    name: String,
    sha256: Result<String, String>,
) {
    let sha = match sha256 {
        Ok(s) => s,
        Err(e) => {
            update_status(state, history_id, TransferStatus::Failed(e));
            return;
        }
    };
    let Some(host) = peer.host.clone() else {
        update_status(state, history_id, TransferStatus::Failed("无可用 IP".into()));
        return;
    };
    let conn = Connection::connect(host, peer.port);
    let ctx_id = Uuid::new_v4();
    spawn_event_forwarder(&state.internal_tx, ctx_id, conn.events_rx.clone());

    let mut ctx = ConnCtx::new_client(ctx_id, conn,
        Role::Client { target: peer, payload: ClientPayload::File {
            path: path.clone(), size, sha256: sha, name,
        }},
        ConnState::AwaitingHelloAck);
    ctx.history_id = Some(history_id);
    ctx.transfer_id = Some(Uuid::new_v4());
    ctx.file_size = size;
    ctx.source_path = Some(path);
    state.contexts.insert(ctx_id, ctx);
    update_status(state, history_id, TransferStatus::WaitingApproval);
}

// ─── 配对决定 / 文件 offer 决定 ───────────────────────────────────────

async fn respond_pairing(state: &mut State, req_id: Uuid, decision: PairingDecision) {
    let req = match state.pending_pairings.iter().position(|p| p.id == req_id) {
        Some(i) => state.pending_pairings.remove(i),
        None => return,
    };
    let _ = state.pp_tx.send(state.pending_pairings.clone());

    let ctx_id = state.contexts.iter().find_map(|(id, c)| {
        if let ConnState::AwaitingPairApproval(pid) = &c.state {
            if *pid == req_id { return Some(*id); }
        }
        None
    });
    let Some(ctx_id) = ctx_id else { return };

    match decision {
        PairingDecision::Reject => close_ctx(state, ctx_id, None).await,
        PairingDecision::AllowOnce => send_ack_and_ready(state, ctx_id, req.peer).await,
        PairingDecision::Trust => {
            state.trust_store.trust(&req.peer.fingerprint, &req.peer.name);
            send_ack_and_ready(state, ctx_id, req.peer).await;
        }
    }
}

async fn respond_offer(state: &mut State, offer_id: Uuid, accept: bool) {
    let offer = match state.pending_offers.iter().position(|o| o.id == offer_id) {
        Some(i) => state.pending_offers.remove(i),
        None => return,
    };
    let _ = state.po_tx.send(state.pending_offers.clone());

    let ctx_id = state.contexts.iter()
        .find_map(|(id, c)| if c.pending_offer_id == Some(offer_id) { Some(*id) } else { None });
    let Some(ctx_id) = ctx_id else { return };

    if !accept {
        if let Some(ctx) = state.contexts.get(&ctx_id) {
            let body = serde_json::to_vec(&FileRejectMessage {
                transfer_id: offer.id.to_string(), index: 0,
                reason: "user_declined".into(),
            }).unwrap_or_default();
            let _ = ctx.connection.send(msg_type::FILE_REJECT, body);
        }
        close_ctx(state, ctx_id, None).await;
        return;
    }

    // 准备保存路径 + 打开 file handle
    let save_dir = default_save_dir(&offer.peer);
    let _ = tokio::fs::create_dir_all(&save_dir).await;
    let save_path = unique_file_path(&save_dir, &offer.file_name);
    let file_out = match OpenOptions::new().create(true).write(true).truncate(true).open(&save_path).await {
        Ok(f) => f,
        Err(e) => {
            warn!("open save file failed: {}", e);
            close_ctx(state, ctx_id, None).await;
            return;
        }
    };

    // 创建 history item
    let item = HistoryItem::new(offer.peer.clone(), TransferDirection::Incoming,
        HistoryKind::File { name: offer.file_name.clone(), size: offer.file_size, path: Some(save_path.clone()) },
        TransferStatus::Transferring { done: 0, total: offer.file_size });
    state.history.insert(0, item.clone());
    let _ = state.history_tx.send(state.history.clone());

    if let Some(ctx) = state.contexts.get_mut(&ctx_id) {
        ctx.file_output = Some(file_out);
        ctx.save_path = Some(save_path);
        ctx.file_size = offer.file_size;
        ctx.expected_sha256 = Some(offer.sha256);
        ctx.transfer_id = Some(offer.id);
        ctx.pending_offer_id = None;
        ctx.state = ConnState::ReceivingFile;
        ctx.history_id = Some(item.id);

        let body = serde_json::to_vec(&FileAcceptMessage {
            transfer_id: offer.id.to_string(), index: 0, resume_offset: 0,
        }).unwrap_or_default();
        let _ = ctx.connection.send(msg_type::FILE_ACCEPT, body);
    }
}

// ─── 连接事件处理 ────────────────────────────────────────────────────

async fn on_ready(state: &mut State, ctx_id: Uuid) {
    // 出方：连上后立即发 HELLO；入方：等对方 HELLO 即可
    let Some(ctx) = state.contexts.get(&ctx_id) else { return };
    if matches!(ctx.role, Role::Client { .. }) {
        let hello = HelloMessage {
            id: state.identity.id.clone(),
            name: state.display_name.clone(),
            os: "linux".into(),
            model: state.model.clone(),
            fp: state.identity.fingerprint.clone(),
            protocol_versions: vec![1],
        };
        let body = serde_json::to_vec(&hello).unwrap_or_default();
        let _ = ctx.connection.send(msg_type::HELLO, body);
    }
}

async fn on_frame(state: &mut State, ctx_id: Uuid, msg_type: u8, body: Vec<u8>) {
    let Some(ctx) = state.contexts.get(&ctx_id) else { return };
    let ctx_state = ctx.state.clone();

    match (ctx_state, msg_type) {
        (ConnState::AwaitingHello, msg_type::HELLO) => server_recv_hello(state, ctx_id, body).await,
        (ConnState::AwaitingHelloAck, msg_type::HELLO_ACK) => client_recv_ack(state, ctx_id, body).await,
        (ConnState::AwaitingFileAccept, msg_type::FILE_ACCEPT) => client_start_send_file(state, ctx_id).await,
        (ConnState::AwaitingFileAccept, msg_type::FILE_REJECT) => {
            let reason = serde_json::from_slice::<FileRejectMessage>(&body)
                .map(|m| m.reason).unwrap_or_else(|_| "rejected".into());
            if let Some(ctx) = state.contexts.get(&ctx_id) {
                if let Some(h) = ctx.history_id { update_status(state, h, TransferStatus::Failed(format!("对方拒收: {}", reason))); }
            }
            close_ctx(state, ctx_id, None).await;
        }
        (ConnState::SendingFile, msg_type::FILE_COMPLETE) => {
            if let Some(ctx) = state.contexts.get(&ctx_id) {
                if let Some(h) = ctx.history_id { update_status(state, h, TransferStatus::Completed); }
            }
            close_ctx(state, ctx_id, None).await;
        }
        (ConnState::Ready, msg_type::TEXT) => handle_received_text(state, ctx_id, body).await,
        (ConnState::Ready, msg_type::CLIPBOARD) => handle_received_clipboard(state, ctx_id, body).await,
        (ConnState::Ready, msg_type::FILE_OFFER) => handle_received_offer(state, ctx_id, body).await,
        (ConnState::ReceivingFile, msg_type::FILE_CHUNK) => handle_received_chunk(state, ctx_id, body).await,
        (_, msg_type::PING) => {
            if let Some(ctx) = state.contexts.get(&ctx_id) {
                let _ = ctx.connection.send(msg_type::PONG, b"{}".to_vec());
            }
        }
        (_, msg_type::PONG) => {}
        _ => {
            debug!("unexpected msg type {} in state of ctx {}", msg_type, ctx_id);
            close_ctx(state, ctx_id, None).await;
        }
    }
}

async fn server_recv_hello(state: &mut State, ctx_id: Uuid, body: Vec<u8>) {
    let hello: HelloMessage = match serde_json::from_slice(&body) {
        Ok(h) => h, Err(_) => { close_ctx(state, ctx_id, None).await; return; }
    };
    if !hello.protocol_versions.contains(&1) { close_ctx(state, ctx_id, None).await; return; }
    let os = DeviceOS::parse(&hello.os).unwrap_or(DeviceOS::Linux);
    let peer = Device {
        id: hello.id, name: hello.name, os, model: hello.model,
        fingerprint: hello.fp, port: 0, protocol_version: 1, host: None,
    };
    if let Some(ctx) = state.contexts.get_mut(&ctx_id) { ctx.peer = Some(peer.clone()); }

    if state.trust_store.is_trusted(&peer.fingerprint) {
        state.trust_store.touch(&peer.fingerprint);
        send_ack_and_ready(state, ctx_id, peer).await;
    } else {
        let req = PendingPairing { id: Uuid::new_v4(), peer: peer.clone() };
        if let Some(ctx) = state.contexts.get_mut(&ctx_id) {
            ctx.state = ConnState::AwaitingPairApproval(req.id);
        }
        state.pending_pairings.push(req);
        let _ = state.pp_tx.send(state.pending_pairings.clone());
    }
}

async fn send_ack_and_ready(state: &mut State, ctx_id: Uuid, peer: Device) {
    let ack = HelloAckMessage {
        id: state.identity.id.clone(),
        name: state.display_name.clone(),
        os: "linux".into(),
        model: state.model.clone(),
        fp: state.identity.fingerprint.clone(),
        protocol_versions: vec![1],
        selected_version: 1,
    };
    let body = serde_json::to_vec(&ack).unwrap_or_default();
    if let Some(ctx) = state.contexts.get_mut(&ctx_id) {
        let _ = ctx.connection.send(msg_type::HELLO_ACK, body);
        ctx.state = ConnState::Ready;
        ctx.peer = Some(peer);
    }
}

async fn client_recv_ack(state: &mut State, ctx_id: Uuid, body: Vec<u8>) {
    let ack: HelloAckMessage = match serde_json::from_slice(&body) {
        Ok(a) => a, Err(_) => { close_ctx(state, ctx_id, None).await; return; }
    };
    let target_fp_payload = {
        let Some(ctx) = state.contexts.get(&ctx_id) else { return };
        match &ctx.role {
            Role::Client { target, payload } => Some((target.clone(), payload_summary(payload))),
            _ => None,
        }
    };
    let Some((target, payload_sum)) = target_fp_payload else { return };
    if ack.fp != target.fingerprint { close_ctx(state, ctx_id, None).await; return; }

    if let Some(ctx) = state.contexts.get_mut(&ctx_id) { ctx.peer = Some(target.clone()); }

    match payload_sum {
        PayloadSummary::Text(content) => {
            let msg = TextMessage {
                id: Uuid::new_v4().to_string(),
                content, ts: now_secs(),
            };
            let body = serde_json::to_vec(&msg).unwrap_or_default();
            let history_id = state.contexts.get(&ctx_id).and_then(|c| c.history_id);
            if let Some(ctx) = state.contexts.get(&ctx_id) {
                let _ = ctx.connection.send(msg_type::TEXT, body);
            }
            if let Some(h) = history_id { update_status(state, h, TransferStatus::Completed); }
            tokio::time::sleep(Duration::from_millis(200)).await;
            close_ctx(state, ctx_id, None).await;
        }
        PayloadSummary::Clipboard { content, kind } => {
            let msg = ClipboardMessage {
                id: Uuid::new_v4().to_string(),
                content, kind, ts: now_secs(),
            };
            let body = serde_json::to_vec(&msg).unwrap_or_default();
            if let Some(ctx) = state.contexts.get(&ctx_id) {
                let _ = ctx.connection.send(msg_type::CLIPBOARD, body);
            }
            tokio::time::sleep(Duration::from_millis(200)).await;
            close_ctx(state, ctx_id, None).await;
        }
        PayloadSummary::File { name, size, sha256 } => {
            let tid = state.contexts.get(&ctx_id).and_then(|c| c.transfer_id)
                .unwrap_or_else(Uuid::new_v4);
            if let Some(ctx) = state.contexts.get_mut(&ctx_id) { ctx.transfer_id = Some(tid); }
            let offer = FileOfferMessage {
                transfer_id: tid.to_string(),
                files: vec![FileMeta { index: 0, name, size, sha256 }],
            };
            let body = serde_json::to_vec(&offer).unwrap_or_default();
            if let Some(ctx) = state.contexts.get_mut(&ctx_id) {
                let _ = ctx.connection.send(msg_type::FILE_OFFER, body);
                ctx.state = ConnState::AwaitingFileAccept;
            }
        }
    }
}

enum PayloadSummary {
    Text(String),
    Clipboard { content: String, kind: String },
    File { name: String, size: u64, sha256: String },
}
fn payload_summary(p: &ClientPayload) -> PayloadSummary {
    match p {
        ClientPayload::Text(s) => PayloadSummary::Text(s.clone()),
        ClientPayload::Clipboard { content, kind } => PayloadSummary::Clipboard {
            content: content.clone(), kind: kind.clone(),
        },
        ClientPayload::File { name, size, sha256, .. } => PayloadSummary::File {
            name: name.clone(), size: *size, sha256: sha256.clone(),
        },
    }
}

async fn client_start_send_file(state: &mut State, ctx_id: Uuid) {
    let path = state.contexts.get(&ctx_id).and_then(|c| c.source_path.clone());
    let Some(path) = path else { return };
    match File::open(&path).await {
        Ok(f) => {
            if let Some(ctx) = state.contexts.get_mut(&ctx_id) {
                ctx.file_input = Some(f);
                ctx.state = ConnState::SendingFile;
                if let Some(h) = ctx.history_id {
                    let size = ctx.file_size;
                    update_status(state, h, TransferStatus::Transferring { done: 0, total: size });
                }
            }
            stream_chunks(state, ctx_id).await;
        }
        Err(e) => {
            if let Some(ctx) = state.contexts.get(&ctx_id) {
                if let Some(h) = ctx.history_id { update_status(state, h, TransferStatus::Failed(e.to_string())); }
            }
            close_ctx(state, ctx_id, None).await;
        }
    }
}

async fn stream_chunks(state: &mut State, ctx_id: Uuid) {
    // 从 ctx 拿出 file_input + transfer_id + file_size + connection 的 clone
    let (mut input, transfer_id, file_size, conn_clone) = {
        let Some(ctx) = state.contexts.get_mut(&ctx_id) else { return };
        let Some(f) = ctx.file_input.take() else { return };
        let Some(tid) = ctx.transfer_id else { return };
        (f, tid, ctx.file_size, ctx.connection.clone())
    };

    let mut offset: u64 = 0;
    let mut buf = vec![0u8; CHUNK_SIZE];

    while offset < file_size {
        let to_read = ((file_size - offset) as usize).min(CHUNK_SIZE);
        let n = match input.read(&mut buf[..to_read]).await {
            Ok(0) => break,
            Ok(n) => n,
            Err(e) => {
                if let Some(ctx) = state.contexts.get(&ctx_id) {
                    if let Some(h) = ctx.history_id { update_status(state, h, TransferStatus::Failed(e.to_string())); }
                }
                close_ctx(state, ctx_id, None).await;
                return;
            }
        };
        let header = FileChunkHeader { transfer_id, index: 0, offset };
        let body = encode_file_chunk(&header, &buf[..n]);
        if conn_clone.send(msg_type::FILE_CHUNK, body).is_err() {
            close_ctx(state, ctx_id, None).await;
            return;
        }
        offset += n as u64;
        if let Some(ctx) = state.contexts.get_mut(&ctx_id) {
            ctx.sent_bytes = offset;
        }
        record_progress(state, ctx_id, offset, file_size);
        if let Some(h) = state.contexts.get(&ctx_id).and_then(|c| c.history_id) {
            update_status(state, h, TransferStatus::Transferring { done: offset, total: file_size });
        }
    }
}

async fn handle_received_text(state: &mut State, ctx_id: Uuid, body: Vec<u8>) {
    let text: TextMessage = match serde_json::from_slice(&body) {
        Ok(t) => t, Err(_) => return,
    };
    let peer = state.contexts.get(&ctx_id).and_then(|c| c.peer.clone());
    let Some(peer) = peer else { return };
    state.history.insert(0, HistoryItem::new(peer, TransferDirection::Incoming,
        HistoryKind::Text(text.content), TransferStatus::Completed));
    let _ = state.history_tx.send(state.history.clone());
}

async fn handle_received_clipboard(state: &mut State, ctx_id: Uuid, body: Vec<u8>) {
    let msg: ClipboardMessage = match serde_json::from_slice(&body) {
        Ok(m) => m, Err(_) => return,
    };
    if msg.content.is_empty() { return; }
    let peer = state.contexts.get(&ctx_id).and_then(|c| c.peer.clone());
    let Some(peer) = peer else { return };
    let entry = ClipboardEntry {
        id: Uuid::new_v4(),
        peer_name: peer.name,
        content: msg.content,
        kind: msg.kind,
        received_at_ms: now_ms(),
    };
    state.clipboard.insert(0, entry);
    // 上限 50 条，超出丢最旧
    state.clipboard.truncate(50);
    let _ = state.clip_tx.send(state.clipboard.clone());
}

async fn handle_received_offer(state: &mut State, ctx_id: Uuid, body: Vec<u8>) {
    let offer: FileOfferMessage = match serde_json::from_slice(&body) {
        Ok(o) => o, Err(_) => return,
    };
    let Some(first) = offer.files.first() else { return };
    let Ok(tid) = Uuid::parse_str(&offer.transfer_id) else { return };
    let peer = state.contexts.get(&ctx_id).and_then(|c| c.peer.clone());
    let Some(peer) = peer else { return };
    let trusted = state.trust_store.is_trusted(&peer.fingerprint);

    let pending = PendingFileOffer {
        id: tid, peer, file_name: first.name.clone(),
        file_size: first.size, sha256: first.sha256.clone(),
    };
    if let Some(ctx) = state.contexts.get_mut(&ctx_id) {
        ctx.pending_offer_id = Some(tid);
    }
    state.pending_offers.push(pending);
    let _ = state.po_tx.send(state.pending_offers.clone());
    // 设置开启且对端已信任 → 自动接受（复用标准流程，会把该项移出 pending）。
    if trusted && state.auto_accept.load(Ordering::Relaxed) {
        respond_offer(state, tid, true).await;
    }
}

async fn handle_received_chunk(state: &mut State, ctx_id: Uuid, body: Vec<u8>) {
    let Some((_, data)) = decode_file_chunk(&body) else { return };
    let mut completed = false;
    let mut h_for_update: Option<Uuid> = None;
    let mut total = 0u64;
    let mut received = 0u64;

    if let Some(ctx) = state.contexts.get_mut(&ctx_id) {
        if let Some(out) = ctx.file_output.as_mut() {
            if let Err(e) = out.write_all(data).await {
                let hid = ctx.history_id;
                // NLL 自然在 hid 取值后结束 ctx 借用；无需显式 drop
                if let Some(h) = hid { update_status(state, h, TransferStatus::Failed(e.to_string())); }
                close_ctx(state, ctx_id, None).await;
                return;
            }
        }
        ctx.received_bytes += data.len() as u64;
        received = ctx.received_bytes;
        total = ctx.file_size;
        h_for_update = ctx.history_id;
        if ctx.received_bytes >= ctx.file_size { completed = true; }
    }
    if let Some(h) = h_for_update {
        record_progress(state, ctx_id, received, total);
        update_status(state, h, TransferStatus::Transferring { done: received, total });
    }

    if completed {
        // 校验 + 发 COMPLETE + 关
        finish_receive(state, ctx_id).await;
    }
}

async fn finish_receive(state: &mut State, ctx_id: Uuid) {
    let (save_path, expected) = {
        let Some(ctx) = state.contexts.get_mut(&ctx_id) else { return };
        if let Some(mut out) = ctx.file_output.take() { let _ = out.flush().await; }
        (ctx.save_path.clone(), ctx.expected_sha256.clone())
    };

    // 大文件 sha256 校验拆到后台 task，避免阻塞主循环（与发送侧 FileHashReady 同理）
    if let (Some(path), Some(expected)) = (save_path, expected) {
        let tx = state.internal_tx.clone();
        tokio::spawn(async move {
            let actual = compute_sha256_async(&path).await.unwrap_or_default();
            let ok = actual == expected;
            let _ = tx.send(InternalCmd::ReceiveHashVerified { ctx_id, ok });
        });
    } else {
        // 无 expected hash（应该不会发生），直接当成功
        let _ = state.internal_tx.send(InternalCmd::ReceiveHashVerified { ctx_id, ok: true });
    }
}

/// 收到 ReceiveHashVerified 后：发 FILE_COMPLETE / 标记历史 / 关 ctx。
async fn on_receive_hash_verified(state: &mut State, ctx_id: Uuid, ok: bool) {
    let (save_path, transfer_id, history_id) = {
        let Some(ctx) = state.contexts.get(&ctx_id) else { return };
        (ctx.save_path.clone(), ctx.transfer_id, ctx.history_id)
    };

    if !ok {
        if let Some(h) = history_id {
            update_status(state, h, TransferStatus::Failed("校验失败".into()));
        }
        if let Some(path) = save_path {
            let _ = tokio::fs::remove_file(&path).await;
        }
        close_ctx(state, ctx_id, None).await;
        return;
    }

    if let Some(tid) = transfer_id {
        let complete = FileCompleteMessage { transfer_id: tid.to_string(), index: 0 };
        let body = serde_json::to_vec(&complete).unwrap_or_default();
        if let Some(ctx) = state.contexts.get(&ctx_id) {
            let _ = ctx.connection.send(msg_type::FILE_COMPLETE, body);
        }
    }
    if let Some(h) = history_id { update_status(state, h, TransferStatus::Completed); }
    tokio::time::sleep(Duration::from_millis(150)).await;
    close_ctx(state, ctx_id, None).await;
}

async fn close_ctx(state: &mut State, ctx_id: Uuid, reason: Option<String>) {
    let Some(ctx) = state.contexts.remove(&ctx_id) else { return };
    if let ConnState::AwaitingPairApproval(pid) = ctx.state {
        state.pending_pairings.retain(|p| p.id != pid);
        let _ = state.pp_tx.send(state.pending_pairings.clone());
    }
    if let Some(oid) = ctx.pending_offer_id {
        state.pending_offers.retain(|o| o.id != oid);
        let _ = state.po_tx.send(state.pending_offers.clone());
    }
    ctx.connection.close();
    if let Some(r) = reason { debug!("ctx {} closed: {}", ctx_id, r); }
}

fn update_status(state: &mut State, history_id: Uuid, status: TransferStatus) {
    let terminal = matches!(
        status,
        TransferStatus::Completed | TransferStatus::Failed(_) | TransferStatus::Canceled
    );
    for it in state.history.iter_mut() {
        if it.id == history_id { it.status = status; break; }
    }
    let _ = state.history_tx.send(state.history.clone());
    // 终态：清掉对应速率条目，UI 上 speed/ETA 立即消失。
    if terminal && state.transfer_metrics.remove(&history_id).is_some() {
        let _ = state.tm_tx.send(state.transfer_metrics.clone());
    }
}

/// ctx 累计字节变化时调一下，刷新 EMA bytes/sec + ETA 写入 state.transfer_metrics。
/// 节流：相邻样本至少 100ms；α=0.3 指数平滑。
fn record_progress(state: &mut State, ctx_id: Uuid, current_bytes: u64, total_bytes: u64) {
    let Some(ctx) = state.contexts.get_mut(&ctx_id) else { return };
    let Some(hid) = ctx.history_id else { return };
    let now = Instant::now();
    if let Some(prev) = ctx.last_sample {
        let dt = now.duration_since(prev).as_secs_f64();
        if dt < 0.1 { return; } // 100ms 节流
        if current_bytes >= ctx.last_sample_bytes && dt > 0.0 {
            let inst = (current_bytes - ctx.last_sample_bytes) as f64 / dt;
            ctx.ema_bytes_per_sec = if ctx.ema_bytes_per_sec == 0.0 {
                inst
            } else {
                0.3 * inst + 0.7 * ctx.ema_bytes_per_sec
            };
        }
    }
    ctx.last_sample = Some(now);
    ctx.last_sample_bytes = current_bytes;

    let bps = ctx.ema_bytes_per_sec;
    let eta = if bps > 1.0 && total_bytes > current_bytes {
        Some((total_bytes - current_bytes) as f64 / bps)
    } else {
        None
    };
    state.transfer_metrics.insert(hid, TransferMetrics { bytes_per_sec: bps, eta_seconds: eta });
    let _ = state.tm_tx.send(state.transfer_metrics.clone());
}

// ─── 辅助：事件转发 / sha256 / 路径 ───────────────────────────────────

fn spawn_event_forwarder(
    internal_tx: &mpsc::UnboundedSender<InternalCmd>,
    ctx_id: Uuid,
    events_rx: async_channel::Receiver<ConnEvent>,
) {
    let tx = internal_tx.clone();
    tokio::spawn(async move {
        while let Ok(ev) = events_rx.recv().await {
            if tx.send(InternalCmd::ConnEvent { ctx_id, event: ev }).is_err() { break; }
        }
    });
}

async fn compute_sha256_async(path: &PathBuf) -> Result<String> {
    let mut f = File::open(path).await?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 1024 * 1024];
    loop {
        let n = f.read(&mut buf).await?;
        if n == 0 { break; }
        hasher.update(&buf[..n]);
    }
    Ok(hex::encode(hasher.finalize()))
}

fn default_save_dir(peer: &Device) -> PathBuf {
    let base = dirs::download_dir()
        .or_else(dirs::home_dir)
        .unwrap_or_else(|| PathBuf::from("/tmp"));
    let name = if peer.name.is_empty() { &peer.id } else { &peer.name };
    base.join("MeshDrop").join(name)
}

fn unique_file_path(dir: &PathBuf, file_name: &str) -> PathBuf {
    let mut candidate = dir.join(file_name);
    if !candidate.exists() { return candidate; }
    let (stem, ext) = match file_name.rsplit_once('.') {
        Some((s, e)) => (s.to_string(), Some(e.to_string())),
        None => (file_name.to_string(), None),
    };
    let mut n = 1;
    loop {
        let name = match &ext {
            Some(e) => format!("{} ({}).{}", stem, n, e),
            None => format!("{} ({})", stem, n),
        };
        candidate = dir.join(name);
        if !candidate.exists() { return candidate; }
        n += 1;
    }
}

fn now_secs() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now().duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs() as i64).unwrap_or(0)
}

fn now_ms() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now().duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as u64).unwrap_or(0)
}

// ─── 设置持久化（自动接收开关）────────────────────────────────────────

fn auto_accept_path() -> Option<PathBuf> {
    dirs::data_local_dir().map(|d| d.join("MeshDrop").join("auto_accept"))
}

fn load_auto_accept() -> bool {
    auto_accept_path()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .map(|s| s.trim() == "1")
        .unwrap_or(false)
}

fn save_auto_accept(value: bool) -> std::io::Result<()> {
    if let Some(p) = auto_accept_path() {
        if let Some(dir) = p.parent() { std::fs::create_dir_all(dir)?; }
        std::fs::write(p, if value { "1" } else { "0" })?;
    }
    Ok(())
}

// ─── ConnCtx 构造 ─────────────────────────────────────────────────────

impl ConnCtx {
    fn new_server(id: Uuid, connection: Connection) -> Self {
        Self {
            id, connection,
            role: Role::Server,
            state: ConnState::AwaitingHello,
            peer: None, history_id: None, transfer_id: None, pending_offer_id: None,
            source_path: None, save_path: None, expected_sha256: None,
            file_size: 0, sent_bytes: 0, received_bytes: 0,
            file_input: None, file_output: None,
            last_sample: None, last_sample_bytes: 0, ema_bytes_per_sec: 0.0,
        }
    }
    fn new_client(id: Uuid, connection: Connection, role: Role, state: ConnState) -> Self {
        Self {
            id, connection, role, state,
            peer: None, history_id: None, transfer_id: None, pending_offer_id: None,
            source_path: None, save_path: None, expected_sha256: None,
            file_size: 0, sent_bytes: 0, received_bytes: 0,
            file_input: None, file_output: None,
            last_sample: None, last_sample_bytes: 0, ema_bytes_per_sec: 0.0,
        }
    }
}
