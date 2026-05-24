//! CLI 子命令 stub。本轮全部 mock，下一轮接 backend。
//! 关键：不进 raw mode；不弹交互 prompt（daemon 模式 headless 友好）。

use anyhow::Result;
use clap::{Args, Parser, Subcommand};
use serde::Serialize;
use std::io::{self, Read, Write};
use std::time::Duration;

use crate::mock;

/// MeshDrop · 终端版（CLI + TUI）。
///
/// 无参数进入全屏 TUI；带子命令进入 headless 模式。
#[derive(Parser, Debug)]
#[command(
    name = "meshdrop-tui",
    version,
    about = "MeshDrop · 终端版（局域网 · 端到端加密 · 雷达发现）",
    long_about = "MeshDrop CLI / TUI — Intranet drop · radar discovery · E2E encryption.\n\n\
    无参数进入全屏 TUI；带子命令进入 headless CLI（适合 SSH / 脚本 / 容器）。"
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Cmd>,

    /// 启动到指定 demo 场景（截图用 · 不与子命令同用）。
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
}

#[derive(Args, Debug)]
pub struct ListDevicesArgs {
    /// JSON 输出 · machine-readable
    #[arg(long, conflicts_with = "table")]
    pub json: bool,
    /// 表格输出（默认） · human-readable table
    #[arg(long)]
    pub table: bool,
}

#[derive(Args, Debug)]
pub struct SendArgs {
    /// 目标设备名 / 中文姓名 / id · peer name or id
    pub peer: String,
    /// 文本内容；用 `-` 从 stdin 读 · `-` reads stdin
    pub text: String,
}

#[derive(Args, Debug)]
pub struct SendFileArgs {
    /// 目标设备名 / 中文姓名 / id · peer name or id
    pub peer: String,
    /// 本地文件路径 · local path to file
    pub path: String,
}

#[derive(Args, Debug)]
pub struct DaemonArgs {
    /// 自动接受信任设备的文件 · auto-accept files from trusted devices
    #[arg(long)]
    pub auto_accept_trusted: bool,
    /// 保存目录 · save dir for incoming files
    #[arg(long, default_value = "~/Downloads/meshdrop/")]
    pub save_dir: String,
}

pub fn run(cmd: Cmd) -> Result<()> {
    match cmd {
        Cmd::ListDevices(a) => list_devices(a),
        Cmd::Send(a) => send_text(a),
        Cmd::SendFile(a) => send_file(a),
        Cmd::Daemon(a) => daemon(a),
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
struct DeviceRow<'a> {
    id: &'a str,
    name: &'a str,
    who: &'a str,
    kind: &'a str,
    os: &'a str,
    rtt_ms: u32,
    online: bool,
}

fn list_devices(args: ListDevicesArgs) -> Result<()> {
    let devs = mock::devices();
    let rows: Vec<DeviceRow> = devs
        .iter()
        .map(|d| DeviceRow {
            id: d.id,
            name: d.name,
            who: d.who,
            kind: d.kind.short(),
            os: d.kind.os(),
            rtt_ms: d.rtt_ms,
            online: true,
        })
        .collect();

    if args.json {
        let stdout = io::stdout();
        let mut out = stdout.lock();
        serde_json::to_writer_pretty(&mut out, &rows)?;
        out.write_all(b"\n")?;
        return Ok(());
    }

    // 表格输出（默认 / --table）
    // 不在 TTY 时也不上色：避免 piped 输出夹带 ANSI 转义符
    let use_color = atty();
    let bold = ansi("\x1b[1m", use_color);
    let dim = ansi("\x1b[2m", use_color);
    let lime = ansi("\x1b[38;5;190m", use_color);
    let reset = ansi("\x1b[0m", use_color);

    println!(
        "{bold}{:<8} {:<26} {:<10} {:<10} {:>6} {:<6}{reset}",
        "ID", "NAME", "WHO", "KIND", "RTT", "STATE",
    );
    println!(
        "{dim}{}{reset}",
        "──────── ────────────────────────── ────────── ────────── ────── ──────",
    );
    for r in &rows {
        println!(
            "{:<8} {:<26} {:<10} {:<10} {:>3} ms {lime}●{reset} {}",
            r.id, r.name, r.who, r.kind, r.rtt_ms, if r.online { "online" } else { "offline" },
        );
    }
    eprintln!();
    eprintln!("{dim}（mock 数据 · 5 个设备 · {} TTY · service _meshdrop._tcp）{reset}", if use_color { "color" } else { "plain" });
    Ok(())
}

fn ansi(s: &'static str, on: bool) -> &'static str {
    if on { s } else { "" }
}

fn atty() -> bool {
    // 用 isatty(STDOUT_FILENO) — std 还没稳定 IsTerminal，自己 libc
    #[cfg(unix)]
    unsafe {
        extern "C" { fn isatty(fd: i32) -> i32; }
        isatty(1) == 1
    }
    #[cfg(not(unix))]
    {
        true
    }
}

// ── send (text) ─────────────────────────────────────────────────────

fn send_text(args: SendArgs) -> Result<()> {
    let text = if args.text == "-" {
        let mut buf = String::new();
        io::stdin().lock().read_to_string(&mut buf)?;
        buf.trim_end().to_string()
    } else {
        args.text
    };

    let peer = resolve_peer(&args.peer)?;
    eprintln!("→ 发送文本到 {} ({})", peer.who, peer.name);
    eprintln!("  内容: {}", truncate_preview(&text, 80));
    eprintln!("  state: TRANSFERRING ↑");
    fake_progress(3, 100);
    println!("OK · sent to {} · {} bytes", peer.who, text.len());
    Ok(())
}

// ── send-file ───────────────────────────────────────────────────────

fn send_file(args: SendFileArgs) -> Result<()> {
    let peer = resolve_peer(&args.peer)?;
    let path = std::path::PathBuf::from(&args.path);
    let name = path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or(&args.path)
        .to_string();
    let size = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);

    eprintln!("→ 发送文件到 {} ({})", peer.who, peer.name);
    eprintln!("  文件: {}  ({})", name, format_bytes(size));
    eprintln!("  state: WAITING_APPROVAL");
    std::thread::sleep(Duration::from_millis(200));
    eprintln!("  state: TRANSFERRING ↑");
    fake_progress(8, 100);
    println!("OK · file delivered · sha256={}", fake_sha256(&name));
    Ok(())
}

// ── daemon ──────────────────────────────────────────────────────────

fn daemon(args: DaemonArgs) -> Result<()> {
    let me = mock::self_card();
    let stderr = io::stderr();
    let mut e = stderr.lock();
    writeln!(e, "meshdrop · daemon starting")?;
    writeln!(e, "  display name      : {}", me.name)?;
    writeln!(e, "  fingerprint       : {}", me.fingerprint)?;
    writeln!(e, "  service           : _meshdrop._tcp.local.")?;
    writeln!(e, "  save dir          : {}", args.save_dir)?;
    writeln!(
        e,
        "  auto-accept       : {}",
        if args.auto_accept_trusted { "trusted only" } else { "no" }
    )?;
    writeln!(e, "  mode              : headless · 不弹交互 prompt")?;
    writeln!(e, "READY · Ctrl-C 退出")?;
    drop(e);

    // 装一个简单的 SIGINT/SIGTERM handler，干净退出（无 raw mode 泄漏）
    let running = std::sync::Arc::new(std::sync::atomic::AtomicBool::new(true));
    let r = running.clone();
    ctrlc_like(move || {
        r.store(false, std::sync::atomic::Ordering::SeqCst);
    });

    // 主循环：每 5s 在 stderr 打一行心跳，绝不读 stdin（headless）
    let mut tick: u64 = 0;
    while running.load(std::sync::atomic::Ordering::SeqCst) {
        std::thread::sleep(Duration::from_millis(500));
        tick += 1;
        if tick % 10 == 0 {
            eprintln!("[heartbeat #{}] peers=5 · transfers=0 · uptime={}s", tick / 10, tick / 2);
        }
    }
    eprintln!("daemon stopping · 干净退出");
    Ok(())
}

#[cfg(unix)]
fn ctrlc_like<F: FnOnce() + Send + 'static>(f: F) {
    // 简化：用一个独立线程读 stdin 也行；但我们更想要 Ctrl-C → SIGINT。
    // 这里我们退而求其次：在另一个线程里阻塞 wait SIGINT 信号集。
    use std::sync::Mutex;
    let f = Arc::new(Mutex::new(Some(f)));
    let f1 = f.clone();
    std::thread::spawn(move || {
        // 朴素的 sigaction-free 方案：等 SIGINT 通过 ctrl-c crate 也行；
        // 但我们不引入新 crate；直接用 nix-free 的 std + libc。
        extern "C" {
            fn signal(signum: i32, handler: usize) -> usize;
        }
        const SIGINT: i32 = 2;
        const SIGTERM: i32 = 15;

        unsafe extern "C" fn handler(_: i32) {
            // 不能在信号处理里释放 mutex；用全局原子标记
            FIRED.store(true, std::sync::atomic::Ordering::SeqCst);
        }
        unsafe {
            signal(SIGINT, handler as *const () as usize);
            signal(SIGTERM, handler as *const () as usize);
        }

        while !FIRED.load(std::sync::atomic::Ordering::SeqCst) {
            std::thread::sleep(Duration::from_millis(100));
        }
        if let Ok(mut g) = f1.lock() {
            if let Some(cb) = g.take() {
                cb();
            }
        }
    });
}

#[cfg(not(unix))]
fn ctrlc_like<F: FnOnce() + Send + 'static>(_f: F) {
    // 其他平台留空；本 crate 主战场就是 unix
}

use std::sync::atomic::AtomicBool;
use std::sync::Arc;
static FIRED: AtomicBool = AtomicBool::new(false);

// ── 辅助 ────────────────────────────────────────────────────────────

fn resolve_peer(input: &str) -> Result<mock::Device> {
    let devs = mock::devices();
    let lower = input.to_lowercase();
    if let Some(d) = devs.iter().find(|d| {
        d.id.eq_ignore_ascii_case(input)
            || d.who == input
            || d.name.to_lowercase() == lower
            || d.name.to_lowercase().contains(&lower)
    }) {
        return Ok(d.clone());
    }
    anyhow::bail!("找不到设备：{}（试试 `meshdrop-tui list-devices`）", input);
}

fn truncate_preview(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        return s.to_string();
    }
    let mut out: String = s.chars().take(max).collect();
    out.push('…');
    out
}

fn format_bytes(n: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;
    if n >= GB {
        format!("{:.2} GB", n as f64 / GB as f64)
    } else if n >= MB {
        format!("{:.2} MB", n as f64 / MB as f64)
    } else if n >= KB {
        format!("{:.2} KB", n as f64 / KB as f64)
    } else {
        format!("{} B", n)
    }
}

fn fake_progress(steps: u32, max: u32) {
    let stderr = io::stderr();
    let mut e = stderr.lock();
    for i in 1..=steps {
        std::thread::sleep(Duration::from_millis(150));
        let p = i * max / steps;
        let _ = writeln!(e, "  {p}%  · mock");
    }
}

fn fake_sha256(name: &str) -> String {
    // mock 一个稳定的 hash，避免每次跑都不一样（测试可重现）
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for b in name.as_bytes() {
        h ^= *b as u64;
        h = h.wrapping_mul(0x0000_0100_0000_01B3);
    }
    format!("{:016x}{:016x}", h, h.wrapping_mul(0x9E37_79B9_7F4A_7C15))
}
