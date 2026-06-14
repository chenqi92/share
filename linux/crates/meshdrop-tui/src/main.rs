//! MeshDrop · 终端版入口。
//! - 无参数 / `--demo` → 进全屏 TUI
//!   · 无 `--demo`：拉起 `meshdrop_core::ShareEngine`，UI 接真 backend
//!   · 带 `--demo`：mock 路径（截图 / 演示用，不动网络）
//! - 带子命令 → 走 CLI headless 路径，不进 raw mode、不开 alternate screen
//!
//! 关键：CLI / daemon 路径 panic / exit code != 0 时终端不会乱。

use anyhow::Result;
use clap::Parser;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use std::io::stdout;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::mpsc;

// i18n：locales/ 下 zh-CN.yml（默认/简体中文）+ en.yml（English）。
// fallback=zh-CN，缺键回退中文而非空串。
#[macro_use]
extern crate rust_i18n;
i18n!("locales", fallback = "zh-CN");

mod app;
mod cli;
mod engine_bridge;
mod input;
mod mock;
mod settings;
mod snapshot;
mod ui;

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("warn"))
        .target(env_logger::Target::Stderr)
        .init();

    init_locale();

    let parsed = cli::Cli::parse();
    match parsed.command {
        Some(cmd) => cli::run(cmd).await,
        None => {
            let demo = parsed.demo.as_deref().and_then(cli::parse_demo);
            if demo.is_some() {
                run_tui_demo(demo).await
            } else {
                run_tui_engine().await
            }
        }
    }
}

async fn run_tui_engine() -> Result<()> {
    // 启 Engine 在 raw mode 之前 —— Engine 启动失败可以正常 print 错误退出，不会污染终端。
    let engine = match engine_bridge::start(None).await {
        Ok(e) => Arc::new(e),
        Err(e) => {
            eprintln!("MeshDrop · 启动失败：{:#}", e);
            eprintln!("（提示：可改用 `meshdrop-tui --demo discovery` 看 UI mock 演示）");
            std::process::exit(1);
        }
    };

    enable_raw_mode()?;
    let mut out = stdout();
    execute!(out, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(out);
    let mut terminal = Terminal::new(backend)?;

    let _guard = TerminalGuard;

    let (key_tx, key_rx) = mpsc::unbounded_channel();
    std::thread::spawn(move || {
        loop {
            if event::poll(Duration::from_millis(100)).unwrap_or(false) {
                if let Ok(Event::Key(k)) = event::read() {
                    if k.kind == KeyEventKind::Press && key_tx.send(k).is_err() {
                        break;
                    }
                }
            }
            if key_tx.is_closed() {
                break;
            }
        }
    });

    let result = app::run(&mut terminal, key_rx, engine).await;

    let _ = disable_raw_mode();
    let _ = execute!(terminal.backend_mut(), LeaveAlternateScreen, DisableMouseCapture);
    let _ = terminal.show_cursor();

    result
}

async fn run_tui_demo(demo: Option<app::DemoScene>) -> Result<()> {
    enable_raw_mode()?;
    let mut out = stdout();
    execute!(out, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(out);
    let mut terminal = Terminal::new(backend)?;

    let _guard = TerminalGuard;

    let (key_tx, key_rx) = mpsc::unbounded_channel();
    std::thread::spawn(move || {
        loop {
            if event::poll(Duration::from_millis(100)).unwrap_or(false) {
                if let Ok(Event::Key(k)) = event::read() {
                    if k.kind == KeyEventKind::Press && key_tx.send(k).is_err() {
                        break;
                    }
                }
            }
            if key_tx.is_closed() {
                break;
            }
        }
    });

    let result = app::run_demo(&mut terminal, key_rx, demo).await;

    let _ = disable_raw_mode();
    let _ = execute!(terminal.backend_mut(), LeaveAlternateScreen, DisableMouseCapture);
    let _ = terminal.show_cursor();

    result
}

/// 按环境变量选择界面语言；默认简体中文（zh-CN）。
/// 识别 MESHDROP_LANG（优先）/ LC_ALL / LANG 中的 en/zh 前缀。
fn init_locale() {
    let env_lang = std::env::var("MESHDROP_LANG")
        .or_else(|_| std::env::var("LC_ALL"))
        .or_else(|_| std::env::var("LANG"))
        .unwrap_or_default()
        .to_ascii_lowercase();
    let locale = if env_lang.starts_with("en") { "en" } else { "zh-CN" };
    rust_i18n::set_locale(locale);
}

/// Panic safety：unwind 时也得把终端复位。
struct TerminalGuard;
impl Drop for TerminalGuard {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(stdout(), LeaveAlternateScreen, DisableMouseCapture);
    }
}
