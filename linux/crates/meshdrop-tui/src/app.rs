//! TUI 主循环 + 视图渲染。
//!
//! 状态机：
//!   Normal     -> 主屏（设备列表 + 历史 + 状态栏）
//!   InputText  -> 输入文本待发送
//!   Command    -> ":" 命令（:f <path>、:q 等）
//!   Pairing    -> 自动弹（pending_pairings 非空时）
//!   FileOffer  -> 自动弹（pending_offers 非空时）

use anyhow::Result;
use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};
use meshdrop_core::{
    history::format_bytes, Device, HistoryItem, HistoryKind, PairingDecision,
    PendingFileOffer, PendingPairing, ShareEngine, TransferDirection, TransferStatus,
};
use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Clear, List, ListItem, ListState, Paragraph, Wrap},
    Frame, Terminal,
};
use std::path::PathBuf;
use std::time::Duration;
use tokio::sync::mpsc::UnboundedReceiver;

pub enum Mode {
    Normal,
    InputText,
    Command,
}

pub struct App {
    engine: ShareEngine,
    devices: Vec<Device>,
    history: Vec<HistoryItem>,
    pending_pairings: Vec<PendingPairing>,
    pending_offers: Vec<PendingFileOffer>,

    selected: ListState,
    mode: Mode,
    input: String,
    status: String,
    quit: bool,
}

pub async fn run<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    engine: ShareEngine,
    mut key_rx: UnboundedReceiver<KeyEvent>,
) -> Result<()> {
    let mut app = App::new(engine);
    app.refresh();

    let tick = Duration::from_millis(100);

    loop {
        terminal.draw(|f| ui(f, &mut app))?;

        tokio::select! {
            // 周期性刷新（拿 watch 的最新值）
            _ = tokio::time::sleep(tick) => app.refresh(),
            // 键盘事件
            Some(key) = key_rx.recv() => {
                handle_key(&mut app, key);
                if app.quit { break; }
            }
        }
    }
    Ok(())
}

impl App {
    fn new(engine: ShareEngine) -> Self {
        Self {
            engine,
            devices: Vec::new(),
            history: Vec::new(),
            pending_pairings: Vec::new(),
            pending_offers: Vec::new(),
            selected: { let mut s = ListState::default(); s.select(Some(0)); s },
            mode: Mode::Normal,
            input: String::new(),
            status: "↑↓ 选择 · Enter 发文本 · : 命令 · q 退出".into(),
            quit: false,
        }
    }

    fn refresh(&mut self) {
        self.devices = self.engine.devices_rx().borrow().clone();
        self.history = self.engine.history_rx().borrow().clone();
        self.pending_pairings = self.engine.pending_pairings_rx().borrow().clone();
        self.pending_offers = self.engine.pending_offers_rx().borrow().clone();

        // 选中索引夹紧
        if self.devices.is_empty() {
            self.selected.select(None);
        } else {
            let cur = self.selected.selected().unwrap_or(0);
            self.selected.select(Some(cur.min(self.devices.len() - 1)));
        }
    }

    fn selected_device(&self) -> Option<&Device> {
        self.selected.selected().and_then(|i| self.devices.get(i))
    }
}

// ─── 事件处理 ────────────────────────────────────────────────────────

fn handle_key(app: &mut App, key: KeyEvent) {
    // 模态优先级：FileOffer > Pairing > Normal/Input/Command
    if let Some(offer) = app.pending_offers.first().cloned() {
        match key.code {
            KeyCode::Char('a') => { app.engine.respond_file_offer(offer.id, true); app.status = format!("已接受 {}", offer.file_name); }
            KeyCode::Char('r') => { app.engine.respond_file_offer(offer.id, false); app.status = "已拒绝".into(); }
            _ => {}
        }
        return;
    }
    if let Some(pair) = app.pending_pairings.first().cloned() {
        match key.code {
            KeyCode::Char('a') => { app.engine.respond_pairing(pair.id, PairingDecision::AllowOnce); app.status = "允许一次".into(); }
            KeyCode::Char('t') => { app.engine.respond_pairing(pair.id, PairingDecision::Trust); app.status = "已信任".into(); }
            KeyCode::Char('r') => { app.engine.respond_pairing(pair.id, PairingDecision::Reject); app.status = "已拒绝".into(); }
            _ => {}
        }
        return;
    }

    match app.mode {
        Mode::Normal => handle_normal(app, key),
        Mode::InputText => handle_input_text(app, key),
        Mode::Command => handle_command(app, key),
    }
}

fn handle_normal(app: &mut App, key: KeyEvent) {
    match key.code {
        KeyCode::Char('q') | KeyCode::Esc => app.quit = true,
        KeyCode::Up | KeyCode::Char('k') => {
            if app.devices.is_empty() { return; }
            let i = app.selected.selected().unwrap_or(0);
            app.selected.select(Some(if i == 0 { app.devices.len() - 1 } else { i - 1 }));
        }
        KeyCode::Down | KeyCode::Char('j') => {
            if app.devices.is_empty() { return; }
            let i = app.selected.selected().unwrap_or(0);
            app.selected.select(Some((i + 1) % app.devices.len()));
        }
        KeyCode::Enter | KeyCode::Char('i') => {
            if app.selected_device().is_some() {
                app.mode = Mode::InputText;
                app.input.clear();
                app.status = "输入文本，Enter 发送，Esc 取消".into();
            }
        }
        KeyCode::Char(':') => {
            app.mode = Mode::Command;
            app.input.clear();
            app.status = "命令模式：:f <文件路径> 发送文件   :q 退出".into();
        }
        KeyCode::Char('d') => {
            // 删除最近一条历史
            if let Some(first) = app.history.first() {
                let id = first.id;
                app.engine.remove_history(id);
                app.status = "删除一条历史".into();
            }
        }
        KeyCode::Char('c') => {
            app.engine.clear_history();
            app.status = "已清空历史".into();
        }
        _ => {}
    }
}

fn handle_input_text(app: &mut App, key: KeyEvent) {
    match key.code {
        KeyCode::Esc => { app.mode = Mode::Normal; app.input.clear(); app.status = "已取消".into(); }
        KeyCode::Enter => {
            if let Some(dev) = app.selected_device().cloned() {
                if !app.input.is_empty() {
                    let content = std::mem::take(&mut app.input);
                    app.engine.send_text(dev.clone(), content);
                    app.status = format!("已发送到 {}", dev.name);
                }
            }
            app.mode = Mode::Normal;
        }
        KeyCode::Backspace => { app.input.pop(); }
        KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => app.input.push(c),
        _ => {}
    }
}

fn handle_command(app: &mut App, key: KeyEvent) {
    match key.code {
        KeyCode::Esc => { app.mode = Mode::Normal; app.input.clear(); app.status = String::new(); }
        KeyCode::Enter => {
            let cmd = std::mem::take(&mut app.input);
            run_command(app, &cmd);
            app.mode = Mode::Normal;
        }
        KeyCode::Backspace => { app.input.pop(); }
        KeyCode::Char(c) if !key.modifiers.contains(KeyModifiers::CONTROL) => app.input.push(c),
        _ => {}
    }
}

fn run_command(app: &mut App, cmd: &str) {
    let parts: Vec<&str> = cmd.splitn(2, ' ').collect();
    match parts.as_slice() {
        ["q"] => app.quit = true,
        ["f", path] => {
            if let Some(dev) = app.selected_device().cloned() {
                let p = PathBuf::from(path);
                if !p.exists() {
                    app.status = format!("文件不存在: {}", path);
                    return;
                }
                app.engine.send_file(dev.clone(), p);
                app.status = format!("发送文件到 {}", dev.name);
            }
        }
        ["c"] => { app.engine.clear_history(); app.status = "已清空".into(); }
        _ => app.status = format!("未知命令: {}", cmd),
    }
}

// ─── 渲染 ────────────────────────────────────────────────────────────

fn ui(f: &mut Frame, app: &mut App) {
    let area = f.area();
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),  // 顶部状态条
            Constraint::Min(5),     // 中间：设备 | 历史
            Constraint::Length(3),  // 底部输入 / 状态
        ])
        .split(area);

    render_top(f, chunks[0], app);
    let mid = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(40), Constraint::Percentage(60)])
        .split(chunks[1]);
    render_devices(f, mid[0], app);
    render_history(f, mid[1], app);
    render_bottom(f, chunks[2], app);

    // 模态层
    if let Some(offer) = app.pending_offers.first().cloned() {
        render_file_offer_popup(f, area, &offer);
    } else if let Some(pair) = app.pending_pairings.first().cloned() {
        render_pairing_popup(f, area, &pair);
    }
}

fn render_top(f: &mut Frame, area: Rect, app: &App) {
    let title = format!(
        " MeshDrop · {} · 指纹 {} · 设备 {}",
        app.engine.display_name,
        &app.engine.identity.fingerprint[..8],
        app.devices.len(),
    );
    let block = Block::default().borders(Borders::ALL).title(title);
    f.render_widget(block, area);
}

fn render_devices(f: &mut Frame, area: Rect, app: &mut App) {
    let items: Vec<ListItem> = app.devices.iter().map(|d| {
        let model = d.model.as_deref().unwrap_or("");
        let suffix = if model.is_empty() { d.os.as_str().to_string() } else { format!("{} · {}", d.os, model) };
        let line = Line::from(vec![
            Span::styled(format!(" {} ", d.name), Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
            Span::styled(suffix, Style::default().fg(Color::DarkGray)),
        ]);
        ListItem::new(line)
    }).collect();

    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title(" 附近设备 "))
        .highlight_style(Style::default().bg(Color::Indexed(24)).add_modifier(Modifier::BOLD))
        .highlight_symbol("▶ ");

    if app.devices.is_empty() {
        let placeholder = Paragraph::new("\n   正在搜索附近设备…\n   按 q 退出")
            .block(Block::default().borders(Borders::ALL).title(" 附近设备 "));
        f.render_widget(placeholder, area);
    } else {
        f.render_stateful_widget(list, area, &mut app.selected);
    }
}

fn render_history(f: &mut Frame, area: Rect, app: &App) {
    let items: Vec<ListItem> = app.history.iter().take(50).map(|h| {
        let arrow = match h.direction {
            TransferDirection::Outgoing => Span::styled("↗ ", Style::default().fg(Color::Cyan)),
            TransferDirection::Incoming => Span::styled("↙ ", Style::default().fg(Color::Green)),
        };
        let content = match &h.kind {
            HistoryKind::Text(s) => Span::raw(truncate(s, area.width as usize - 20)),
            HistoryKind::File { name, size, .. } => Span::styled(
                format!("📄 {} ({})", name, format_bytes(*size)),
                Style::default().fg(Color::Yellow),
            ),
        };
        let status = match &h.status {
            TransferStatus::Pending => Span::styled(" 准备中", Style::default().fg(Color::DarkGray)),
            TransferStatus::WaitingApproval => Span::styled(" 待对方接受", Style::default().fg(Color::DarkGray)),
            TransferStatus::Transferring { done, total } => Span::styled(
                format!(" {}/{}", format_bytes(*done), format_bytes(*total)),
                Style::default().fg(Color::Yellow),
            ),
            TransferStatus::Completed => Span::styled(" ✓", Style::default().fg(Color::Green)),
            TransferStatus::Failed(r) => Span::styled(format!(" ✗ {}", r), Style::default().fg(Color::Red)),
            TransferStatus::Canceled => Span::styled(" 已取消", Style::default().fg(Color::DarkGray)),
        };
        ListItem::new(Line::from(vec![
            arrow,
            Span::styled(format!("{} ", h.peer.name), Style::default().fg(Color::White)),
            content,
            status,
        ]))
    }).collect();

    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title(format!(" 历史 {} ", app.history.len())));
    f.render_widget(list, area);
}

fn render_bottom(f: &mut Frame, area: Rect, app: &App) {
    let prefix = match app.mode {
        Mode::Normal => "",
        Mode::InputText => "✎ ",
        Mode::Command => ":",
    };
    let text = match app.mode {
        Mode::Normal => Line::from(Span::styled(app.status.clone(), Style::default().fg(Color::DarkGray))),
        _ => Line::from(vec![
            Span::styled(prefix, Style::default().fg(Color::Cyan)),
            Span::raw(app.input.clone()),
            Span::styled("_", Style::default().add_modifier(Modifier::SLOW_BLINK)),
        ]),
    };
    let title = match app.mode {
        Mode::Normal => " 操作 ",
        Mode::InputText => " 输入文本 ",
        Mode::Command => " 命令 ",
    };
    let p = Paragraph::new(text)
        .block(Block::default().borders(Borders::ALL).title(title))
        .wrap(Wrap { trim: false });
    f.render_widget(p, area);
}

fn render_pairing_popup(f: &mut Frame, full: Rect, pair: &PendingPairing) {
    let area = centered(60, 9, full);
    f.render_widget(Clear, area);
    let body = format!(
        "  {} 想要连接\n\n  指纹: {}\n\n  [a] 允许一次   [t] 信任并记住   [r] 拒绝",
        pair.peer.name,
        pair.peer.human_fingerprint(),
    );
    let p = Paragraph::new(body)
        .block(Block::default().borders(Borders::ALL).title(" 配对请求 ").style(Style::default().fg(Color::Yellow)));
    f.render_widget(p, area);
}

fn render_file_offer_popup(f: &mut Frame, full: Rect, offer: &PendingFileOffer) {
    let area = centered(60, 8, full);
    f.render_widget(Clear, area);
    let body = format!(
        "  {} 想发送文件\n\n  文件: {}  ({})\n\n  [a] 接受   [r] 拒绝",
        offer.peer.name, offer.file_name, offer.formatted_size(),
    );
    let p = Paragraph::new(body)
        .block(Block::default().borders(Borders::ALL).title(" 收到文件 ").style(Style::default().fg(Color::Cyan)));
    f.render_widget(p, area);
}

fn centered(w: u16, h: u16, full: Rect) -> Rect {
    let x = full.x + full.width.saturating_sub(w) / 2;
    let y = full.y + full.height.saturating_sub(h) / 2;
    Rect { x, y, width: w.min(full.width), height: h.min(full.height) }
}

fn truncate(s: &str, max: usize) -> String {
    let max = max.max(8);
    if s.len() <= max { s.to_string() }
    else { format!("{}…", &s[..max.min(s.len()).saturating_sub(1)]) }
}
