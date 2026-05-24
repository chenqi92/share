//! MeshDrop · 终端版入口。
//! - 无参数 → 进全屏 TUI（raw mode + alternate screen）
//! - 带子命令 → 走 CLI headless 路径，不进 raw mode、不开 alternate screen
//!
//! 这是关键：CLI 路径 panic / exit code != 0 时终端不会乱。

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
use std::time::Duration;
use tokio::sync::mpsc;

mod app;
mod cli;
mod input;
mod mock;
mod ui;

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("warn"))
        .target(env_logger::Target::Stderr)
        .init();

    let parsed = cli::Cli::parse();
    match parsed.command {
        Some(cmd) => cli::run(cmd),
        None => run_tui().await,
    }
}

async fn run_tui() -> Result<()> {
    // ── 终端进入 ───────────────────────────────────────────────
    enable_raw_mode()?;
    let mut out = stdout();
    execute!(out, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(out);
    let mut terminal = Terminal::new(backend)?;

    // 一旦进了 raw mode，任何 panic 都必须 best-effort 恢复终端
    let _guard = TerminalGuard;

    // ── 键盘事件 → tokio channel ───────────────────────────────
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

    let result = app::run(&mut terminal, key_rx).await;

    // ── 终端恢复 ───────────────────────────────────────────────
    let _ = disable_raw_mode();
    let _ = execute!(terminal.backend_mut(), LeaveAlternateScreen, DisableMouseCapture);
    let _ = terminal.show_cursor();

    result
}

/// Panic safety：unwind 时也得把终端复位。
struct TerminalGuard;
impl Drop for TerminalGuard {
    fn drop(&mut self) {
        let _ = disable_raw_mode();
        let _ = execute!(stdout(), LeaveAlternateScreen, DisableMouseCapture);
    }
}
