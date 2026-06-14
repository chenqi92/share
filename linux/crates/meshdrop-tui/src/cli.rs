//! CLI 子命令 — 全部走真实 `meshdrop_core::ShareEngine`。
//!
//! 关键不变量：
//! - 不进 raw mode；不开 alternate screen；任何 panic / exit code != 0 终端不会乱
//! - daemon 模式严格 headless：不读 stdin / 不弹任何交互 prompt
//! - SIGINT / SIGTERM 通过 `tokio::signal` 干净退出（无 raw mode 泄漏）

use anyhow::{Context, Result};
use clap::{Args, Parser, Subcommand};
use log::info;
use meshdrop_core::{
    Device as CoreDevice, HistoryItem as CoreHistoryItem, HistoryKind, PairingDecision,
    ShareEngine, TransferDirection, TransferStatus,
};
use serde::Serialize;
use std::io::{self, Read, Write};
use std::path::PathBuf;
use std::time::Duration;
use tokio::time::Instant;

use crate::engine_bridge;

#[derive(Parser, Debug)]
#[command(
    name = "meshdrop-tui",
    version,
    about = "MeshDrop · 终端版（局域网 · 明文 TCP · v0.1 · 雷达发现）",
    long_about = "MeshDrop CLI / TUI — Intranet drop · radar discovery · plaintext TCP (v0.1).\n\n\
    无参数进入全屏 TUI；带子命令进入 headless CLI（适合 SSH / 脚本 / 容器）。"
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Cmd>,

    /// 启动到指定 demo 场景（截图用 · 不与子命令同用 · 用 mock 数据不接 backend）。
    /// 取值：discovery / transfers / history / settings /
    ///       pairing / offer / help /
    ///       search:<text> / command:<text> /
    ///       radar:sweep|pulse|grid|orbit
    #[arg(long, value_name = "SCENE", global = false)]
    pub demo: Option<String>,
}

#[derive(Subcommand, Debug)]
pub enum Cmd {
    /// 列出附近设备 · list nearby devices
    ListDevices(ListDevicesArgs),
    /// 发文本 · send text to a peer
    Send(SendArgs),
    /// 发文件 · send a file to a peer
    SendFile(SendFileArgs),
    /// 后台接收守护进程 · receive daemon
    Daemon(DaemonArgs),
    /// 把指定 scene 渲染成 SVG（截图用，不进 raw mode）
    Snapshot(SnapshotArgs),
}

#[derive(Args, Debug)]
pub struct ListDevicesArgs {
    /// JSON 输出 · machine-readable
    #[arg(long, conflicts_with = "table")]
    pub json: bool,
    /// 表格输出（默认） · human-readable table
    #[arg(long)]
    pub table: bool,
    /// 扫描等待时长（秒） · 给 mDNS 解析时间
    #[arg(long, default_value_t = 3)]
    pub wait: u64,
    /// 显示名（不传则取 $HOSTNAME / hostname）
    #[arg(long)]
    pub name: Option<String>,
}

#[derive(Args, Debug)]
pub struct SendArgs {
    /// 目标设备：device id / display name / fingerprint 前缀
    pub peer: String,
    /// 文本内容；用 `-` 从 stdin 读 · `-` reads stdin
    pub text: String,
    /// 等待对方出现在 mDNS 发现表的最长时间（秒）
    #[arg(long, default_value_t = 6)]
    pub wait: u64,
    /// 显示名（覆盖 $HOSTNAME）
    #[arg(long)]
    pub name: Option<String>,
}

#[derive(Args, Debug)]
pub struct SendFileArgs {
    /// 目标设备：device id / display name / fingerprint 前缀
    pub peer: String,
    /// 本地文件路径 · local path to file
    pub path: String,
    #[arg(long, default_value_t = 6)]
    pub wait: u64,
    #[arg(long)]
    pub name: Option<String>,
}

#[derive(Args, Debug)]
pub struct SnapshotArgs {
    #[arg(long)]
    pub scene: String,
    #[arg(long)]
    pub out: PathBuf,
    #[arg(long, default_value_t = 140)]
    pub cols: u16,
    #[arg(long, default_value_t = 42)]
    pub rows: u16,
    #[arg(long, default_value = "truecolor")]
    pub color: String,
    #[arg(long, default_value = "full")]
    pub chars: String,
}

#[derive(Args, Debug)]
pub struct DaemonArgs {
    /// 自动接受信任设备的文件 · auto-accept files from trusted devices
    #[arg(long)]
    pub auto_accept_trusted: bool,
    /// 自动接受陌生配对请求并加入信任清单（不安全 · 仅用于受控环境 / 测试）。
    /// 默认 daemon 拒绝陌生配对（"daemon 不替用户决策信任"）。
    #[arg(long)]
    pub trust_all_pairings: bool,
    /// 保存目录 · save dir for incoming files
    #[arg(long, default_value = "~/Downloads/meshdrop/")]
    pub save_dir: String,
    /// 日志写文件（同时 stderr 出）
    #[arg(long)]
    pub log_file: Option<PathBuf>,
    /// 显示名（覆盖 $HOSTNAME）
    #[arg(long)]
    pub name: Option<String>,
}

pub async fn run(cmd: Cmd) -> Result<()> {
    match cmd {
        Cmd::ListDevices(a) => list_devices(a).await,
        Cmd::Send(a) => send_text(a).await,
        Cmd::SendFile(a) => send_file(a).await,
        Cmd::Daemon(a) => daemon(a).await,
        Cmd::Snapshot(a) => {
            crate::snapshot::render(&a.scene, &a.out, a.cols, a.rows, &a.color, &a.chars)
        }
    }
}

/// 解析 --demo SCENE 字符串成 DemoScene；不识别的返回 None。
pub fn parse_demo(spec: &str) -> Option<crate::app::DemoScene> {
    use crate::app::DemoScene;
    use crate::input::{Mode, Page};
    use crate::ui::widgets::radar::Variant;

    let mut scene = DemoScene::default();
    let lower = spec.trim().to_ascii_lowercase();
    let (head, tail) = match lower.split_once(':') {
        Some((h, t)) => (h.trim(), Some(t.trim().to_string())),
        None => (lower.as_str(), None),
    };
    match head {
        "discovery" | "main" => scene.page = Some(Page::Discovery),
        "transfers" | "transfer" => scene.page = Some(Page::Transfers),
        "history" => scene.page = Some(Page::History),
        "trust" => scene.page = Some(Page::Trust),
        "clipboard" | "clip" => scene.page = Some(Page::Clipboard),
        "settings" | "set" => scene.page = Some(Page::Settings),
        "pairing" | "pair" => {
            scene.page = Some(Page::Discovery);
            scene.show_pairing = true;
        }
        "offer" | "fileoffer" | "file-offer" => {
            scene.page = Some(Page::Discovery);
            scene.show_offer = true;
        }
        "help" => {
            scene.page = Some(Page::Discovery);
            scene.mode = Some(Mode::Help);
        }
        "search" => {
            scene.page = Some(Page::Discovery);
            scene.mode = Some(Mode::Search);
            scene.input = tail.clone().or_else(|| Some("孟".into()));
        }
        "command" | "cmd" => {
            scene.page = Some(Page::Discovery);
            scene.mode = Some(Mode::Command);
            scene.input = tail.clone().or_else(|| Some("f /tmp/demo.zip".into()));
        }
        "radar" => {
            scene.page = Some(Page::Discovery);
            scene.radar = tail.as_deref().and_then(Variant::parse).or(Some(Variant::Pulse));
        }
        _ => return None,
    }
    Some(scene)
}

// ── list-devices ────────────────────────────────────────────────────

#[derive(Serialize)]
struct DeviceRow {
    id: String,
    name: String,
    os: String,
    model: Option<String>,
    ip: Option<String>,
    port: u16,
    fingerprint: String,
}

async fn list_devices(args: ListDevicesArgs) -> Result<()> {
    let engine = engine_bridge::start(args.name).await?;
    let devices = wait_for_devices(&engine, Duration::from_secs(args.wait), 1).await;

    let rows: Vec<DeviceRow> = devices
        .iter()
        .map(|d| DeviceRow {
            id: d.id.clone(),
            name: d.name.clone(),
            os: d.os.as_str().into(),
            model: d.model.clone(),
            ip: d.host.clone(),
            port: d.port,
            fingerprint: d.fingerprint.clone(),
        })
        .collect();

    if args.json {
        let stdout = io::stdout();
        let mut out = stdout.lock();
        serde_json::to_writer_pretty(&mut out, &rows)?;
        out.write_all(b"\n")?;
        return Ok(());
    }

    let use_color = atty();
    let bold = ansi("\x1b[1m", use_color);
    let dim = ansi("\x1b[2m", use_color);
    let lime = ansi("\x1b[38;5;190m", use_color);
    let reset = ansi("\x1b[0m", use_color);

    println!(
        "{bold}{:<10} {:<22} {:<8} {:<22} {:<22} {:<5}{reset}",
        "ID", "NAME", "OS", "MODEL", "IP", "PORT",
    );
    println!(
        "{dim}{}{reset}",
        "────────── ────────────────────── ──────── ────────────────────── ────────────────────── ─────",
    );
    if rows.is_empty() {
        println!("{dim}（局域网内未发现 MeshDrop 设备 · 调大 --wait 再试）{reset}");
        return Ok(());
    }
    for r in &rows {
        let model = r.model.clone().unwrap_or_else(|| "—".into());
        let ip = r.ip.clone().unwrap_or_else(|| "—".into());
        let id_short = &r.id[..r.id.len().min(10)];
        println!(
            "{:<10} {:<22} {:<8} {:<22} {:<22} {:>5} {lime}●{reset}",
            id_short, truncate(&r.name, 22), r.os, truncate(&model, 22), truncate(&ip, 22), r.port,
        );
    }
    eprintln!();
    eprintln!("{dim}（mDNS _meshdrop._tcp · {} 台 · 等待 {}s）{reset}", rows.len(), args.wait);
    Ok(())
}

async fn wait_for_devices(
    engine: &ShareEngine,
    max_wait: Duration,
    at_least: usize,
) -> Vec<CoreDevice> {
    let mut rx = engine.devices_rx();
    let deadline = Instant::now() + max_wait;
    loop {
        let snap = rx.borrow().clone();
        if snap.len() >= at_least {
            return snap;
        }
        let remaining = deadline.checked_duration_since(Instant::now());
        match remaining {
            None => return rx.borrow().clone(),
            Some(left) => {
                let _ = tokio::time::timeout(left, rx.changed()).await;
                if Instant::now() >= deadline {
                    return rx.borrow().clone();
                }
            }
        }
    }
}

fn ansi(s: &'static str, on: bool) -> &'static str {
    if on { s } else { "" }
}

fn atty() -> bool {
    #[cfg(unix)]
    unsafe {
        extern "C" { fn isatty(fd: i32) -> i32; }
        isatty(1) == 1
    }
    #[cfg(not(unix))]
    { true }
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max { return s.to_string(); }
    let mut out: String = s.chars().take(max.saturating_sub(1)).collect();
    out.push('…');
    out
}

// ── send (text) ─────────────────────────────────────────────────────

async fn send_text(args: SendArgs) -> Result<()> {
    let text = if args.text == "-" {
        let mut buf = String::new();
        io::stdin().lock().read_to_string(&mut buf)?;
        buf.trim_end().to_string()
    } else {
        args.text
    };

    let engine = engine_bridge::start(args.name).await?;
    let devices = wait_for_devices(&engine, Duration::from_secs(args.wait), 1).await;
    let peer = engine_bridge::resolve_peer(&devices, &args.peer)
        .with_context(|| format!("找不到设备：{}（用 `meshdrop-tui list-devices` 看清单）", args.peer))?;

    let target_name = peer.name.clone();
    eprintln!("→ 发送文本到 {} ({}·{})", target_name, peer.id, peer.os);
    eprintln!("  内容: {}", truncate(&text, 80));

    let mut history_rx = engine.history_rx();
    engine.send_text(peer.clone(), text.clone());

    let outcome = wait_for_outgoing_finish(
        &mut history_rx,
        &peer.id,
        |h| matches!(&h.kind, HistoryKind::Text(t) if t == &text),
        Duration::from_secs(15),
    )
    .await;

    match outcome {
        Outcome::Completed => {
            println!("OK · sent to {} · {} bytes", target_name, text.as_bytes().len());
            Ok(())
        }
        Outcome::Failed(reason) => anyhow::bail!("发送失败：{}", reason),
        Outcome::Timeout => anyhow::bail!("发送超时（>15s 仍未收到完成回执）"),
    }
}

// ── send-file ───────────────────────────────────────────────────────

async fn send_file(args: SendFileArgs) -> Result<()> {
    let path = PathBuf::from(expand_home(&args.path));
    if !path.exists() {
        anyhow::bail!("文件不存在：{}", args.path);
    }
    let metadata = std::fs::metadata(&path).context("读文件 metadata")?;
    let size = metadata.len();
    let name = path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or(&args.path)
        .to_string();

    let engine = engine_bridge::start(args.name).await?;
    let devices = wait_for_devices(&engine, Duration::from_secs(args.wait), 1).await;
    let peer = engine_bridge::resolve_peer(&devices, &args.peer)
        .with_context(|| format!("找不到设备：{}（用 `meshdrop-tui list-devices` 看清单）", args.peer))?;

    let target_name = peer.name.clone();
    eprintln!("→ 发送文件到 {} ({}·{})", target_name, peer.id, peer.os);
    eprintln!("  文件: {}  ({})", name, meshdrop_core::history::format_bytes(size));

    let mut history_rx = engine.history_rx();
    engine.send_file(peer.clone(), path.clone());

    let mut last_pct: i32 = -1;
    let outcome = loop {
        // 每帧打印进度（只在变化时打 stderr，避免刷屏）
        let cur_snapshot = history_rx.borrow().clone();
        if let Some(h) = cur_snapshot
            .iter()
            .find(|h| matches!(&h.kind, HistoryKind::File { name: n, .. } if n == &name)
                && h.peer.id == peer.id
                && matches!(h.direction, TransferDirection::Outgoing))
        {
            match &h.status {
                TransferStatus::Transferring { done, total } if *total > 0 => {
                    let pct = (*done as i64 * 100 / *total as i64) as i32;
                    if pct != last_pct {
                        eprintln!("  {}%  · {}/{}", pct,
                            meshdrop_core::history::format_bytes(*done),
                            meshdrop_core::history::format_bytes(*total));
                        last_pct = pct;
                    }
                }
                TransferStatus::Completed => break Outcome::Completed,
                TransferStatus::Failed(r) => break Outcome::Failed(r.clone()),
                TransferStatus::Canceled => break Outcome::Failed("canceled".into()),
                _ => {}
            }
        }
        let timeout_per_iter = Duration::from_secs(60);
        if tokio::time::timeout(timeout_per_iter, history_rx.changed()).await.is_err() {
            break Outcome::Timeout;
        }
    };

    match outcome {
        Outcome::Completed => {
            // 算一下本地 SHA-256 给人看（接收方也校验过了）
            let sha = sha256_file(&path).await.unwrap_or_else(|_| "—".into());
            println!("OK · file delivered · sha256={}", sha);
            Ok(())
        }
        Outcome::Failed(reason) => anyhow::bail!("发送失败：{}", reason),
        Outcome::Timeout => anyhow::bail!("发送超时（单步 ≥ 60s 无进展）"),
    }
}

enum Outcome {
    Completed,
    Failed(String),
    Timeout,
}

async fn wait_for_outgoing_finish<F>(
    history_rx: &mut tokio::sync::watch::Receiver<Vec<CoreHistoryItem>>,
    peer_id: &str,
    matches_payload: F,
    max_wait: Duration,
) -> Outcome
where
    F: Fn(&CoreHistoryItem) -> bool,
{
    let deadline = Instant::now() + max_wait;
    loop {
        let snap = history_rx.borrow().clone();
        if let Some(h) = snap
            .iter()
            .find(|h| h.peer.id == peer_id
                && matches!(h.direction, TransferDirection::Outgoing)
                && matches_payload(h))
        {
            match &h.status {
                TransferStatus::Completed => return Outcome::Completed,
                TransferStatus::Failed(r) => return Outcome::Failed(r.clone()),
                TransferStatus::Canceled => return Outcome::Failed("canceled".into()),
                _ => {}
            }
        }
        let remaining = deadline.checked_duration_since(Instant::now());
        match remaining {
            None => return Outcome::Timeout,
            Some(left) => {
                if tokio::time::timeout(left, history_rx.changed()).await.is_err() {
                    return Outcome::Timeout;
                }
            }
        }
    }
}

async fn sha256_file(path: &std::path::Path) -> Result<String> {
    use sha2::{Digest, Sha256};
    use tokio::io::AsyncReadExt;
    let mut f = tokio::fs::File::open(path).await?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 1024 * 1024];
    loop {
        let n = f.read(&mut buf).await?;
        if n == 0 { break; }
        hasher.update(&buf[..n]);
    }
    Ok(hex::encode(hasher.finalize()))
}

// ── daemon ──────────────────────────────────────────────────────────

async fn daemon(args: DaemonArgs) -> Result<()> {
    let save_dir = PathBuf::from(expand_home(&args.save_dir));
    std::fs::create_dir_all(&save_dir).context("创建 save dir")?;

    // 可选 log_file —— 之后所有 info!/warn! 都同时进文件
    if let Some(path) = &args.log_file {
        // 简化：把 stderr 重定向到 tee（外部）超出 scope；这里只是 print 提示让运行者自己 redirect
        eprintln!("（提示：env_logger 输出在 stderr · 用 `2>>{}` 持久化）", path.display());
    }

    let engine = engine_bridge::start(args.name).await?;

    let stderr = io::stderr();
    let mut e = stderr.lock();
    writeln!(e, "meshdrop · daemon starting")?;
    writeln!(e, "  display name      : {}", engine.display_name)?;
    writeln!(e, "  fingerprint       : {}", engine.identity.fingerprint)?;
    writeln!(e, "  service           : _meshdrop._tcp.local.")?;
    writeln!(e, "  save dir          : {}", save_dir.display())?;
    writeln!(
        e,
        "  auto-accept       : {}",
        if args.auto_accept_trusted { "trusted only" } else { "manual only（仅记录，不自动接收）" }
    )?;
    writeln!(
        e,
        "  pairing           : {}",
        if args.trust_all_pairings { "trust-all（不安全 · 仅测试）" } else { "auto-reject（默认）" }
    )?;
    writeln!(e, "  mode              : headless · 不读 stdin · 不弹交互 prompt")?;
    writeln!(e, "READY · SIGINT/SIGTERM 干净退出")?;
    drop(e);

    // 装事件监听：incoming offer / pairing / history
    let mut offers_rx = engine.pending_offers_rx();
    let mut pairings_rx = engine.pending_pairings_rx();
    let mut history_rx = engine.history_rx();

    let engine_for_acceptor = engine.clone();
    let auto_accept = args.auto_accept_trusted;
    let trust_all = args.trust_all_pairings;

    // SIGINT / SIGTERM —— 用 tokio::signal，避免引入 ctrlc/libc 新 crate
    use tokio::signal::unix::{signal, SignalKind};
    let mut sigterm = signal(SignalKind::terminate()).context("注册 SIGTERM")?;
    let sigint = tokio::signal::ctrl_c();
    let mut sigint_box = std::pin::pin!(sigint);

    info!("daemon main loop started");

    loop {
        tokio::select! {
            _ = &mut sigint_box => {
                eprintln!("daemon stopping · SIGINT · 干净退出");
                break;
            }
            _ = sigterm.recv() => {
                eprintln!("daemon stopping · SIGTERM · 干净退出");
                break;
            }
            res = offers_rx.changed() => {
                if res.is_err() { break; }
                let offers = offers_rx.borrow().clone();
                for o in offers {
                    handle_incoming_offer(&engine_for_acceptor, &o, auto_accept);
                }
            }
            res = pairings_rx.changed() => {
                if res.is_err() { break; }
                let pairings = pairings_rx.borrow().clone();
                for p in pairings {
                    if trust_all {
                        eprintln!("[pair] 来自 {} 的配对请求 — 已信任（--trust-all-pairings · 仅测试）", p.peer.name);
                        engine_for_acceptor.respond_pairing(p.id, PairingDecision::Trust);
                    } else {
                        eprintln!("[pair] 来自 {} 的配对请求 — 已自动拒绝（daemon 不替用户决策信任）", p.peer.name);
                        engine_for_acceptor.respond_pairing(p.id, PairingDecision::Reject);
                    }
                }
            }
            res = history_rx.changed() => {
                if res.is_err() { break; }
                let hist = history_rx.borrow().clone();
                if let Some(h) = hist.iter().find(|h|
                    matches!(h.direction, TransferDirection::Incoming)
                    && matches!(h.status, TransferStatus::Completed)
                ) {
                    if let HistoryKind::File { name, size, path } = &h.kind {
                        eprintln!("[recv] {} ({}) ← {} · 保存路径 {}",
                            name,
                            meshdrop_core::history::format_bytes(*size),
                            h.peer.name,
                            path.as_ref().map(|p| p.display().to_string()).unwrap_or_else(|| "?".into()),
                        );
                    } else if let HistoryKind::Text(t) = &h.kind {
                        eprintln!("[text] {} ← {}", truncate(t, 80), h.peer.name);
                    }
                }
            }
        }
    }

    Ok(())
}

fn handle_incoming_offer(
    engine: &ShareEngine,
    offer: &meshdrop_core::PendingFileOffer,
    auto_accept_trusted: bool,
) {
    eprintln!(
        "[offer] {} ({}) ← {} · sha256={}…",
        offer.file_name,
        offer.formatted_size(),
        offer.peer.name,
        &offer.sha256[..offer.sha256.len().min(16)],
    );
    if auto_accept_trusted {
        // 仅自动接受「已信任」对端的文件；陌生 peer 即便开了 --auto-accept-trusted
        // 也保持挂起（headless 下等同拒绝交互，由发起方超时）。
        if engine.is_trusted(&offer.peer.fingerprint) {
            engine.respond_file_offer(offer.id, true);
            eprintln!("[offer] 已自动接受（已信任设备 · --auto-accept-trusted）");
        } else {
            eprintln!("[offer] 未自动接受（{} 不在信任列表 · 先在 TUI / GUI 配对信任）", offer.peer.name);
        }
    } else {
        // 不弹 prompt（headless）；仅记录、不自动接受
        eprintln!("[offer] 未自动接受（需 --auto-accept-trusted 或 TUI 模式手动）");
    }
}

fn expand_home(s: &str) -> String {
    if let Some(rest) = s.strip_prefix("~/") {
        if let Ok(home) = std::env::var("HOME") {
            return format!("{}/{}", home, rest);
        }
    }
    if s == "~" {
        if let Ok(home) = std::env::var("HOME") {
            return home;
        }
    }
    s.to_string()
}
