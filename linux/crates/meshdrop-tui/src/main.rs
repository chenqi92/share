//! MeshDrop TUI — ratatui 终端界面，适合 SSH / headless / 容器场景。
//!
//! 按键：
//!   ↑/k, ↓/j      切换设备
//!   Enter         发送文本到选中设备（i 进入输入模式）
//!   :             进入命令模式（:f <path> 发文件）
//!   a / r         接受 / 拒绝待审请求（配对或文件 offer）
//!   t             接受配对并信任
//!   d             删除选中的历史项
//!   c             清空历史
//!   q / Esc       退出
//!
mod app;

use anyhow::Result;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use meshdrop_core::{Identity, ShareEngine};
use ratatui::backend::CrosstermBackend;
use ratatui::Terminal;
use std::io::stdout;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::mpsc;

#[tokio::main]
async fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("warn"))
        .target(env_logger::Target::Stderr)
        .init();

    let identity = Arc::new(Identity::load_or_create()?);
    let display_name = std::env::var("HOSTNAME")
        .ok()
        .or_else(|| std::fs::read_to_string("/etc/hostname").ok().map(|s| s.trim().to_string()))
        .unwrap_or_else(|| "Linux".to_string());
    let model = std::fs::read_to_string("/sys/class/dmi/id/product_name")
        .ok().map(|s| s.trim().to_string()).filter(|s| !s.is_empty());

    let engine = ShareEngine::start(identity, display_name, model).await?;

    // 终端初始化
    enable_raw_mode()?;
    let mut out = stdout();
    execute!(out, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(out);
    let mut terminal = Terminal::new(backend)?;

    // 键盘事件 → tokio channel（不阻塞 render）
    let (key_tx, key_rx) = mpsc::unbounded_channel();
    std::thread::spawn(move || -> Result<()> {
        loop {
            if event::poll(Duration::from_millis(100))? {
                if let Event::Key(k) = event::read()? {
                    if k.kind == KeyEventKind::Press {
                        if key_tx.send(k).is_err() { break; }
                        if k.code == KeyCode::Char('q') || k.code == KeyCode::Esc { break; }
                    }
                }
            }
        }
        Ok(())
    });

    let result = app::run(&mut terminal, engine, key_rx).await;

    // 终端恢复
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen, DisableMouseCapture)?;
    terminal.show_cursor()?;

    result
}
