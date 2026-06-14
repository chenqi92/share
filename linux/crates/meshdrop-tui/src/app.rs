//! 全屏 TUI 主循环。
//!
//! 数据源：
//! - 默认（无 `--demo`）：`meshdrop_core::ShareEngine`。Engine 通过
//!   `engine_bridge::spawn_watchers` 把 4 个 watch::Receiver 合并成 mpsc::EngineUpdate，
//!   主 select! 消费并更新 App 状态。
//! - `--demo <scene>`：用 `mock::*` 静态数据填充 App（截图 / 演示用），不启 Engine。
//!
//! 状态机由 input.rs 提供；模态优先级：Help > Pairing > FileOffer > Normal。

use anyhow::Result;
use crossterm::event::KeyEvent;
use meshdrop_core::{Device as CoreDevice, PairingDecision, PendingFileOffer as CorePendingOffer, PendingPairing as CorePendingPairing, ShareEngine};
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, ListState, Paragraph};
use ratatui::{Frame, Terminal};
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::mpsc::UnboundedReceiver;

use crate::engine_bridge::{self, EngineUpdate};
use crate::input::{translate, Action, Focus, Mode, Page};
use crate::mock;
use crate::settings::{SetResult, Settings};
use crate::ui::modals::{self, file_offer, pairing as pairing_modal, send};
use crate::ui::theme::Theme;
use crate::ui::widgets::{
    ascii_divider, chip, device_list, history as history_widget, radar, settings_page, status_bar,
    transfer_row,
};
use crate::ui::{help, widgets::meshdrop_logo};

/// 启动场景（--demo 给截图用）
#[derive(Clone, Debug, Default)]
pub struct DemoScene {
    pub page: Option<Page>,
    pub mode: Option<Mode>,
    pub input: Option<String>,
    pub show_pairing: bool,
    pub show_offer: bool,
    pub radar: Option<crate::ui::widgets::radar::Variant>,
}

#[derive(Clone, Debug)]
#[allow(dead_code)] // Error 分支为未来 watcher 失联场景预留
pub enum EngineStatus {
    Starting,
    Live,
    Error(String),
    Mock, // --demo 路径
}

pub struct App {
    pub theme: Theme,
    pub me: mock::SelfCard,
    pub settings: Settings,

    /// Engine 句柄；--demo 模式为 None。
    pub engine: Option<Arc<ShareEngine>>,
    pub engine_status: EngineStatus,

    // 显示层：widget 渲染只读这里
    pub devices: Vec<mock::Device>,
    pub history: Vec<mock::HistoryItem>,
    pub transfers: Vec<mock::Transfer>,
    pub clip: Vec<mock::ClipItem>,
    /// 速度柱状图序列（已按各自序列 max 归一到 0..100）。空 = 用 mock（demo/截图）。
    pub tp_up: Vec<u8>,
    pub tp_down: Vec<u8>,
    pub tp_session: Vec<u8>,
    pub pending_pairing: Option<mock::PendingPairing>,
    pub pending_offer: Option<mock::PendingOffer>,

    // Engine 原始列表：执行命令时拿对应 CoreDevice / Pending* / history UUID
    pub core_devices: Vec<CoreDevice>,
    pub core_history: Vec<meshdrop_core::history::HistoryItem>,
    pub core_pairings: Vec<CorePendingPairing>,
    pub core_offers: Vec<CorePendingOffer>,
    pub transfer_metrics: std::collections::HashMap<uuid::Uuid, meshdrop_core::TransferMetrics>,

    pub page: Page,
    pub focus: Focus,
    pub mode: Mode,

    pub device_state: ListState,
    pub history_state: ListState,

    pub input: String,
    pub filter: String,
    pub status: String,

    pub start: Instant,
    pub quit: bool,
}

impl App {
    /// 截图 / demo 路径 — 全 mock 数据，不接 engine。
    pub fn new_demo() -> Self {
        let theme = Theme::detect();
        let me = mock::self_card();
        let devices = mock::devices();
        let history = mock::history();
        let transfers = mock::transfers();
        let clip = mock::clipboard();
        let mut settings = Settings::default();
        settings.display_name = me.name.clone();

        let mut device_state = ListState::default();
        device_state.select(Some(0));
        let mut history_state = ListState::default();
        history_state.select(Some(0));

        Self {
            theme,
            me,
            settings,
            engine: None,
            engine_status: EngineStatus::Mock,
            devices,
            history,
            transfers,
            clip,
            tp_up: Vec::new(),
            tp_down: Vec::new(),
            tp_session: Vec::new(),
            pending_pairing: None,
            pending_offer: None,
            core_devices: Vec::new(),
            core_history: Vec::new(),
            core_pairings: Vec::new(),
            core_offers: Vec::new(),
            transfer_metrics: std::collections::HashMap::new(),
            page: Page::Discovery,
            focus: Focus::Devices,
            mode: Mode::Normal,
            device_state,
            history_state,
            input: String::new(),
            filter: String::new(),
            status: String::new(),
            start: Instant::now(),
            quit: false,
        }
    }

    /// 真实 engine 路径。
    pub fn new_with_engine(engine: Arc<ShareEngine>) -> Self {
        let theme = Theme::detect();
        let me = engine_bridge::self_card(&engine);
        let mut settings = Settings::default();
        settings.display_name = me.name.clone();
        // 用 engine 持久化的真实开关初始化 Settings，避免 TUI 显示与实际不符。
        settings.auto_accept_trusted = engine.auto_accept_from_trusted();
        settings.visible_on_lan = engine.visible_on_lan();
        settings.trusted_only = engine.trusted_only();
        settings.verify_before_receive = engine.verify_before_receive();
        settings.auto_accept_stranger = engine.auto_accept_stranger();
        settings.clipboard_sync = engine.clipboard_sync();
        settings.launch_at_login = meshdrop_core::autostart::is_enabled();
        if let Some(dir) = engine.save_dir() {
            settings.save_dir = dir;
            settings.save_dir_custom = true;
        }
        let mut device_state = ListState::default();
        device_state.select(Some(0));
        let mut history_state = ListState::default();
        history_state.select(Some(0));
        Self {
            theme,
            me,
            settings,
            engine: Some(engine),
            engine_status: EngineStatus::Starting,
            devices: Vec::new(),
            history: Vec::new(),
            transfers: Vec::new(),
            clip: Vec::new(),
            tp_up: Vec::new(),
            tp_down: Vec::new(),
            tp_session: Vec::new(),
            pending_pairing: None,
            pending_offer: None,
            core_devices: Vec::new(),
            core_history: Vec::new(),
            core_pairings: Vec::new(),
            core_offers: Vec::new(),
            transfer_metrics: std::collections::HashMap::new(),
            page: Page::Discovery,
            focus: Focus::Devices,
            mode: Mode::Normal,
            device_state,
            history_state,
            input: String::new(),
            filter: String::new(),
            status: String::new(),
            start: Instant::now(),
            quit: false,
        }
    }

    pub fn apply_demo(&mut self, scene: DemoScene) {
        if let Some(p) = scene.page {
            self.page = p;
            self.focus = focus_for_page(p);
        }
        if let Some(r) = scene.radar {
            self.settings.radar = r;
        }
        if scene.show_pairing {
            self.pending_pairing = Some(mock::pending_pairing());
            self.mode = Mode::Pairing;
        }
        if scene.show_offer {
            self.pending_offer = Some(mock::pending_offer());
            self.mode = Mode::FileOffer;
        }
        if let Some(m) = scene.mode {
            if !matches!(m, Mode::Pairing | Mode::FileOffer) {
                self.mode = m;
            }
        }
        if let Some(s) = scene.input {
            match self.mode {
                Mode::Search => {
                    self.input = s.clone();
                    self.filter = s;
                }
                Mode::InputText | Mode::Command => {
                    self.input = s;
                }
                _ => {}
            }
        }
    }

    pub fn filtered_devices(&self) -> Vec<mock::Device> {
        if self.filter.is_empty() {
            return self.devices.clone();
        }
        let q = self.filter.to_lowercase();
        self.devices
            .iter()
            .filter(|d| {
                d.who.to_lowercase().contains(&q)
                    || d.name.to_lowercase().contains(&q)
                    || d.kind.short().contains(&q)
                    || d.kind.os().to_lowercase().contains(&q)
            })
            .cloned()
            .collect()
    }

    fn selected_device_id(&self) -> Option<String> {
        let list = self.filtered_devices();
        self.device_state
            .selected()
            .and_then(|i| list.get(i).map(|d| d.id.clone()))
    }

    fn selected_core_device(&self) -> Option<CoreDevice> {
        let id = self.selected_device_id()?;
        self.core_devices.iter().find(|d| d.id == id).cloned()
    }

    fn list_for_focus(&self) -> usize {
        match self.focus {
            Focus::Devices => self.filtered_devices().len(),
            Focus::History => self.history.len(),
            Focus::Transfers => self.transfers.len(),
        }
    }

    fn move_focus(&mut self, delta: i32) {
        let n = self.list_for_focus();
        if n == 0 {
            return;
        }
        let state = match self.focus {
            Focus::Devices => &mut self.device_state,
            Focus::History | Focus::Transfers => &mut self.history_state,
        };
        let cur = state.selected().unwrap_or(0) as i32;
        let new = (cur + delta).rem_euclid(n as i32) as usize;
        state.select(Some(new));
    }

    fn submit_input(&mut self) {
        match self.mode {
            Mode::InputText => {
                let text = std::mem::take(&mut self.input);
                if !text.is_empty() {
                    if let Some(engine) = &self.engine {
                        if let Some(peer) = self.selected_core_device() {
                            let who = peer.name.clone();
                            engine.send_text(peer, text.clone());
                            self.status = t!("status.sent_to", name = who, preview = preview(&text, 40)).to_string();
                        } else {
                            self.status = t!("common.no_device_selected").to_string();
                        }
                    } else {
                        // mock 路径：插一条假历史
                        let peer = self
                            .filtered_devices()
                            .get(self.device_state.selected().unwrap_or(0))
                            .map(|d| d.who.clone())
                            .unwrap_or_else(|| "—".into());
                        self.history.insert(
                            0,
                            mock::HistoryItem {
                                id: mock::next_id(),
                                dir: mock::Direction::Outgoing,
                                peer: peer.clone(),
                                time: now_hhmm(),
                                body: mock::HistoryBody::Text(text.clone()),
                                state: mock::HistoryState::Done,
                            },
                        );
                        self.status = t!("status.sent_to", name = peer, preview = text).to_string();
                    }
                }
                self.mode = Mode::Normal;
            }
            Mode::Command => {
                let cmd = std::mem::take(&mut self.input);
                self.run_command(&cmd);
                self.mode = Mode::Normal;
            }
            Mode::Search => {
                self.mode = Mode::Normal;
            }
            _ => {}
        }
        self.surface_pending_modal();
    }

    /// 把待处理的信任请求 / 文件 offer 顶到前台。
    /// 优先级：Help > Pairing > FileOffer > 其余。只要当前不在更高/同级模态里，
    /// 即便正在输入文本 / 命令 / 搜索，也立刻弹出——否则对端来连时本地完全没有提示，
    /// 用户既看不到也无从批准（曾导致「Mac 发过来 Linux 端毫无反应」）。
    fn surface_pending_modal(&mut self) {
        let interruptible = matches!(
            self.mode,
            Mode::Normal | Mode::InputText | Mode::Command | Mode::Search
        );
        if !interruptible {
            return;
        }
        if self.pending_pairing.is_some() {
            self.mode = Mode::Pairing;
        } else if self.pending_offer.is_some() {
            self.mode = Mode::FileOffer;
        }
    }

    fn run_command(&mut self, cmd: &str) {
        let parts: Vec<&str> = cmd.splitn(2, ' ').collect();
        match parts.as_slice() {
            ["q"] | ["quit"] | ["exit"] => self.quit = true,
            ["c"] | ["clear"] => {
                if let Some(engine) = &self.engine {
                    engine.clear_history();
                    self.status = t!("status.history_cleared").to_string();
                } else {
                    self.history.clear();
                    self.status = t!("status.history_cleared").to_string();
                }
            }
            ["trust"] => self.status = t!("status.trust_hint").to_string(),
            ["revoke", fp] => {
                // 用户可能粘贴带分隔符的展示型指纹（如 "ZX8K · L72M …"），
                // 归一成 trust store 里存的紧凑小写 hex 再撤销。
                let normalized: String = fp
                    .chars()
                    .filter(|c| c.is_ascii_alphanumeric())
                    .collect::<String>()
                    .to_lowercase();
                if let Some(engine) = &self.engine {
                    if normalized.is_empty() {
                        self.status = t!("status.revoke_usage").to_string();
                    } else if engine.revoke_trust(&normalized) {
                        self.status = t!("status.revoked", fp = fp).to_string();
                    } else {
                        self.status = t!("status.not_in_trust", fp = fp).to_string();
                    }
                } else {
                    self.status = t!("status.revoke_mock", fp = fp).to_string();
                }
            }
            ["f", path] => {
                let path_buf = std::path::PathBuf::from(expand_home(path));
                if !path_buf.exists() {
                    self.status = t!("status.file_not_found", path = path).to_string();
                    return;
                }
                if let Some(engine) = &self.engine {
                    if let Some(peer) = self.selected_core_device() {
                        let who = peer.name.clone();
                        let name = path_buf.file_name().and_then(|s| s.to_str()).unwrap_or(path).to_string();
                        engine.send_file(peer, path_buf);
                        self.status = t!("status.send_file", name = name, name2 = who).to_string();
                    } else {
                        self.status = t!("common.no_device_selected").to_string();
                    }
                } else {
                    self.status = t!("status.send_file_mock", path = path).to_string();
                }
            }
            ["set", kv] => match self.settings.apply(kv) {
                SetResult::Ok { key, value } => {
                    match key {
                        "displayName" => {
                            self.me.name = value.clone();
                            // core 当前不支持热改广播名（mDNS 注册时固定），提示需重启。
                            if self.engine.is_some() {
                                self.status = t!("status.set_display_name_restart", key = key, value = value).to_string();
                            } else {
                                self.status = t!("status.set_ok", key = key, value = value).to_string();
                            }
                        }
                        "autoAccept" => {
                            // 真正下发给 engine（与 GUI 开关同口径），不只是改内存 Settings。
                            if let Some(engine) = &self.engine {
                                engine.set_auto_accept(self.settings.auto_accept_trusted);
                            }
                            self.status = t!("status.set_ok", key = key, value = value).to_string();
                        }
                        "saveDir" => {
                            // 真正下发 engine.set_save_dir（已是真后端），并由 core 持久化。
                            if let Some(engine) = &self.engine {
                                engine.set_save_dir(Some(self.settings.save_dir.clone()));
                            }
                            self.status = t!("status.set_ok", key = key, value = value).to_string();
                        }
                        "visibleOnLan" => {
                            if let Some(engine) = &self.engine {
                                engine.set_visible_on_lan(self.settings.visible_on_lan);
                            }
                            self.status = t!("status.set_ok", key = key, value = value).to_string();
                        }
                        "trustedOnly" => {
                            if let Some(engine) = &self.engine {
                                engine.set_trusted_only(self.settings.trusted_only);
                            }
                            self.status = t!("status.set_ok", key = key, value = value).to_string();
                        }
                        "verifyBeforeReceive" => {
                            if let Some(engine) = &self.engine {
                                engine.set_verify_before_receive(self.settings.verify_before_receive);
                            }
                            self.status = t!("status.set_ok", key = key, value = value).to_string();
                        }
                        "autoAcceptStranger" => {
                            if let Some(engine) = &self.engine {
                                engine.set_auto_accept_stranger(self.settings.auto_accept_stranger);
                            }
                            self.status = t!("status.set_ok", key = key, value = value).to_string();
                        }
                        "clipboardSync" => {
                            if let Some(engine) = &self.engine {
                                engine.set_clipboard_sync(self.settings.clipboard_sync);
                            }
                            self.status = t!("status.set_ok", key = key, value = value).to_string();
                        }
                        "launchAtLogin" => {
                            // 写 / 删 ~/.config/autostart/meshdrop.desktop（状态即文件存在性）。
                            match meshdrop_core::autostart::set_enabled(self.settings.launch_at_login) {
                                Ok(()) => self.status = t!("status.set_ok", key = key, value = value).to_string(),
                                Err(e) => self.status = t!("status.set_bad_value", key = key, value = e.to_string()).to_string(),
                            }
                        }
                        _ => self.status = t!("status.set_ok", key = key, value = value).to_string(),
                    }
                }
                SetResult::UnknownKey(k) => self.status = t!("status.set_unknown_key", key = k).to_string(),
                SetResult::BadValue { key, value } => {
                    self.status = t!("status.set_bad_value", key = key, value = value).to_string();
                }
                SetResult::Syntax => {
                    self.status = t!("status.set_syntax").to_string();
                }
            },
            _ => self.status = t!("status.unknown_command", cmd = cmd).to_string(),
        }
    }

    fn refresh_transfers(&mut self) {
        // transfers 由进行中 / 最近 history 派生。speed / eta 来自 transfer_metrics，
        // 按 core_history (同长度同顺序) 取对应 UUID 查表。
        let me_label = self.me.name.clone();
        self.transfers = self
            .history
            .iter()
            .enumerate()
            .filter_map(|(i, h)| {
                let (name, size, ext, progress) = match &h.body {
                    mock::HistoryBody::File { name, size, ext, progress } => {
                        (name.clone(), size.clone(), ext.clone(), progress.unwrap_or(0))
                    }
                    mock::HistoryBody::Text(_) => return None,
                    mock::HistoryBody::Image { .. } => return None,
                };
                let (from, to) = match h.dir {
                    mock::Direction::Outgoing => (me_label.clone(), h.peer.clone()),
                    mock::Direction::Incoming => (h.peer.clone(), me_label.clone()),
                };
                let active = matches!(h.state, mock::HistoryState::Sending | mock::HistoryState::Receiving);
                let metrics = self.core_history.get(i).and_then(|c| self.transfer_metrics.get(&c.id));
                let speed = if active {
                    metrics.and_then(|m| if m.bytes_per_sec > 1.0 { Some(fmt_speed(m.bytes_per_sec)) } else { None })
                } else { None };
                let eta = if active {
                    metrics.and_then(|m| m.eta_seconds).map(fmt_eta)
                } else { None };
                let fail_reason = self.core_history.get(i).and_then(|c| {
                    use meshdrop_core::history::TransferStatus;
                    match &c.status {
                        TransferStatus::Failed(reason) => Some(reason.clone()),
                        TransferStatus::Canceled => Some(t!("common.canceled").to_string()),
                        _ => None,
                    }
                });
                Some(mock::Transfer {
                    name,
                    size,
                    ext,
                    from,
                    to,
                    progress,
                    state: h.state,
                    speed,
                    eta,
                    fail_reason,
                })
            })
            .collect();
    }
}

/// 每个页面的默认焦点列表。Trust / Clipboard 为只读视图，焦点沿用 Devices。
fn focus_for_page(p: Page) -> Focus {
    match p {
        Page::Discovery => Focus::Devices,
        Page::Transfers => Focus::Transfers,
        Page::History => Focus::History,
        Page::Trust | Page::Clipboard | Page::Settings => Focus::Devices,
    }
}

fn fmt_speed(bps: f64) -> String {
    if bps < 1024.0 { format!("{:.0} B/s", bps) }
    else if bps < 1024.0 * 1024.0 { format!("{:.1} KB/s", bps / 1024.0) }
    else { format!("{:.1} MB/s", bps / 1024.0 / 1024.0) }
}

fn fmt_eta(secs: f64) -> String {
    if !secs.is_finite() || secs < 0.0 { return "—".into() }
    if secs < 1.0 { return "<1s".into() }
    if secs >= 3600.0 { return ">1h".into() }
    let s = secs as u32;
    format!("{:02}:{:02}", s / 60, s % 60)
}

fn preview(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        return s.to_string();
    }
    let mut out: String = s.chars().take(max).collect();
    out.push('…');
    out
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

fn now_hhmm() -> String {
    let secs = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0);
    let total_min = (secs / 60) % (24 * 60);
    let h = total_min / 60;
    let m = total_min % 60;
    format!("{:02}:{:02}", h, m)
}

// ────────── 主循环（demo 路径） ──────────

pub async fn run_demo<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    mut key_rx: UnboundedReceiver<KeyEvent>,
    demo: Option<DemoScene>,
) -> Result<()> {
    let mut app = App::new_demo();
    if let Some(scene) = demo {
        app.apply_demo(scene);
    }
    let tick = Duration::from_millis(120);

    loop {
        terminal.draw(|f| ui(f, &mut app))?;

        tokio::select! {
            _ = tokio::time::sleep(tick) => {},
            Some(key) = key_rx.recv() => {
                let mode = app.mode;
                let action = translate(mode, key);
                apply(&mut app, action);
                if app.quit { break; }
            }
        }
    }
    Ok(())
}

// ────────── 主循环（engine 路径） ──────────

pub async fn run<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    mut key_rx: UnboundedReceiver<KeyEvent>,
    engine: Arc<ShareEngine>,
) -> Result<()> {
    let mut app = App::new_with_engine(engine.clone());
    let mut engine_rx = engine_bridge::spawn_watchers(&engine);
    // tick 100ms — 满足 prompt 要求的「重绘节流 ≥ 100ms / 帧」
    let tick = Duration::from_millis(100);

    loop {
        terminal.draw(|f| ui(f, &mut app))?;

        tokio::select! {
            _ = tokio::time::sleep(tick) => {},
            Some(key) = key_rx.recv() => {
                let mode = app.mode;
                let action = translate(mode, key);
                apply(&mut app, action);
                if app.quit { break; }
            }
            Some(update) = engine_rx.recv() => {
                apply_engine_update(&mut app, update);
            }
        }
    }
    Ok(())
}

fn apply_engine_update(app: &mut App, update: EngineUpdate) {
    match update {
        EngineUpdate::Devices { core, display } => {
            app.core_devices = core;
            app.devices = display;
            app.engine_status = EngineStatus::Live;
            // 让选择不超出范围
            if let Some(i) = app.device_state.selected() {
                if i >= app.devices.len() {
                    app.device_state.select(if app.devices.is_empty() { None } else { Some(0) });
                }
            } else if !app.devices.is_empty() {
                app.device_state.select(Some(0));
            }
        }
        EngineUpdate::History { core, display } => {
            app.core_history = core;
            app.history = display;
            app.refresh_transfers();
        }
        EngineUpdate::Pairings { core, display } => {
            app.core_pairings = core;
            app.pending_pairing = display.into_iter().next();
            app.surface_pending_modal();
        }
        EngineUpdate::Offers { core, display } => {
            app.core_offers = core;
            app.pending_offer = display.into_iter().next();
            app.surface_pending_modal();
        }
        EngineUpdate::TransferMetricsChanged(metrics) => {
            app.transfer_metrics = metrics;
            app.refresh_transfers();
        }
        EngineUpdate::Clipboard { display } => {
            app.clip = display;
        }
        EngineUpdate::Throughput { up, down, session } => {
            app.tp_up = up;
            app.tp_down = down;
            app.tp_session = session;
        }
    }
}

fn apply(app: &mut App, action: Action) {
    match action {
        Action::Quit => app.quit = true,
        Action::None => {}
        Action::MoveUp => app.move_focus(-1),
        Action::MoveDown => app.move_focus(1),
        Action::NextFocus => app.focus = app.focus.next(),
        Action::PrevFocus => {
            app.focus = app.focus.next().next();
        }
        Action::SwitchPage(p) => {
            app.page = p;
            app.focus = focus_for_page(p);
        }
        Action::NextPage => {
            app.page = app.page.next();
            app.focus = focus_for_page(app.page);
        }
        Action::PrevPage => {
            app.page = app.page.prev();
            app.focus = focus_for_page(app.page);
        }
        Action::EnterInputText => {
            if app.selected_device_id().is_some() {
                app.mode = Mode::InputText;
                app.input.clear();
            }
        }
        Action::EnterCommand => {
            app.mode = Mode::Command;
            app.input.clear();
        }
        Action::EnterSearch => {
            app.mode = Mode::Search;
            app.input.clear();
            app.filter.clear();
        }
        Action::OpenHelp => app.mode = Mode::Help,
        Action::DemoPairing => {
            if app.engine.is_none() {
                app.pending_pairing = Some(mock::pending_pairing());
                app.mode = Mode::Pairing;
            }
        }
        Action::DemoOffer => {
            if app.engine.is_none() {
                app.pending_offer = Some(mock::pending_offer());
                app.mode = Mode::FileOffer;
            }
        }
        Action::PushChar(c) => match app.mode {
            Mode::Search => {
                app.input.push(c);
                app.filter = app.input.clone();
            }
            Mode::InputText | Mode::Command => app.input.push(c),
            _ => {}
        },
        Action::PopChar => {
            app.input.pop();
            if app.mode == Mode::Search {
                app.filter = app.input.clone();
            }
        }
        Action::Submit => app.submit_input(),
        Action::Cancel => {
            match app.mode {
                Mode::Search => {
                    app.filter.clear();
                    app.input.clear();
                }
                Mode::InputText | Mode::Command => {
                    app.input.clear();
                }
                Mode::Pairing => {
                    if let (Some(engine), Some(p)) = (&app.engine, app.core_pairings.first()) {
                        engine.respond_pairing(p.id, PairingDecision::Reject);
                    }
                    app.pending_pairing = None;
                }
                Mode::FileOffer => {
                    if let (Some(engine), Some(o)) = (&app.engine, app.core_offers.first()) {
                        engine.respond_file_offer(o.id, false);
                    }
                    app.pending_offer = None;
                }
                _ => {}
            }
            app.mode = Mode::Normal;
            app.surface_pending_modal();
        }
        Action::Accept => {
            if let Some(engine) = &app.engine {
                if app.pending_pairing.is_some() {
                    if let Some(p) = app.core_pairings.first() {
                        engine.respond_pairing(p.id, PairingDecision::AllowOnce);
                        app.status = t!("status.allowed_once", name = p.peer.name).to_string();
                    }
                }
                if app.pending_offer.is_some() {
                    if let Some(o) = app.core_offers.first() {
                        engine.respond_file_offer(o.id, true);
                        app.status = t!("status.accepted", name = o.file_name).to_string();
                    }
                }
            } else {
                // mock 路径
                if let Some(p) = &app.pending_pairing {
                    app.status = t!("status.allowed_once", name = p.peer).to_string();
                }
                if let Some(o) = &app.pending_offer {
                    app.status = t!("status.accepted", name = o.file_name).to_string();
                }
            }
            app.pending_pairing = None;
            app.pending_offer = None;
            app.mode = Mode::Normal;
        }
        Action::Reject => {
            if let Some(engine) = &app.engine {
                if app.pending_pairing.is_some() {
                    if let Some(p) = app.core_pairings.first() {
                        engine.respond_pairing(p.id, PairingDecision::Reject);
                    }
                    app.status = t!("status.rejected_pairing").to_string();
                }
                if app.pending_offer.is_some() {
                    if let Some(o) = app.core_offers.first() {
                        engine.respond_file_offer(o.id, false);
                    }
                    app.status = t!("status.rejected_offer").to_string();
                }
            } else {
                if app.pending_pairing.is_some() {
                    app.status = t!("status.rejected_pairing").to_string();
                }
                if app.pending_offer.is_some() {
                    app.status = t!("status.rejected_offer").to_string();
                }
            }
            app.pending_pairing = None;
            app.pending_offer = None;
            app.mode = Mode::Normal;
        }
        Action::Trust => {
            if let Some(engine) = &app.engine {
                if app.pending_pairing.is_some() {
                    if let Some(p) = app.core_pairings.first() {
                        engine.respond_pairing(p.id, PairingDecision::Trust);
                        app.status = t!("status.trusted_saved", name = p.peer.name).to_string();
                    }
                }
                if app.pending_offer.is_some() {
                    if let Some(o) = app.core_offers.first() {
                        engine.respond_file_offer(o.id, true);
                        app.status = t!("status.accept_and_trust", name = o.file_name, name2 = o.peer.name).to_string();
                    }
                }
            } else {
                if let Some(p) = &app.pending_pairing {
                    app.status = t!("status.trusted_saved", name = p.peer).to_string();
                }
                if let Some(o) = &app.pending_offer {
                    app.status = t!("status.accept_and_trust", name = o.file_name, name2 = o.peer).to_string();
                }
            }
            app.pending_pairing = None;
            app.pending_offer = None;
            app.mode = Mode::Normal;
        }
        Action::DeleteSelected => {
            if app.focus == Focus::History {
                if let Some(i) = app.history_state.selected() {
                    if i < app.history.len() {
                        if let Some(engine) = &app.engine {
                            // display 列表与 core_history 由同一快照、同序构建（见 engine_bridge），
                            // 故同一下标对应同一条；按下标回查真实 UUID 删除。
                            if let Some(core) = app.core_history.get(i) {
                                engine.remove_history(core.id);
                                app.status = t!("status.history_deleted").to_string();
                            } else {
                                app.status = t!("status.history_not_found").to_string();
                            }
                        } else {
                            app.history.remove(i);
                            if i >= app.history.len() && i > 0 {
                                app.history_state.select(Some(i - 1));
                            }
                            app.status = t!("status.history_deleted").to_string();
                        }
                    }
                }
            }
        }
        Action::ClearHistory => {
            if let Some(engine) = &app.engine {
                engine.clear_history();
                app.status = t!("status.history_cleared").to_string();
            } else {
                app.history.clear();
                app.status = t!("status.history_cleared").to_string();
            }
        }
        Action::CancelTransfer => {
            if app.focus == Focus::Transfers {
                if let Some(i) = app.history_state.selected() {
                    if i < app.core_history.len() {
                        let core = &app.core_history[i];
                        let in_progress = matches!(
                            core.status,
                            meshdrop_core::history::TransferStatus::Transferring { .. }
                        );
                        if in_progress {
                            if let Some(engine) = &app.engine {
                                engine.cancel_transfer(core.id);
                                app.status = t!("status.cancel_started").to_string();
                            } else {
                                app.status = t!("status.cancel_no_engine").to_string();
                            }
                        } else {
                            app.status = t!("status.cancel_only_active").to_string();
                        }
                    }
                }
            } else {
                app.status = t!("status.cancel_switch").to_string();
            }
        }
        Action::RetryTransfer => {
            if app.focus == Focus::Transfers {
                if let Some(i) = app.history_state.selected() {
                    if i < app.core_history.len() {
                        let core = &app.core_history[i];
                        let failed_outgoing = matches!(
                            core.status,
                            meshdrop_core::history::TransferStatus::Failed(_)
                            | meshdrop_core::history::TransferStatus::Canceled
                        ) && matches!(
                            core.direction,
                            meshdrop_core::history::TransferDirection::Outgoing
                        );
                        if failed_outgoing {
                            if let Some(engine) = &app.engine {
                                engine.retry_transfer(core.id);
                                app.status = t!("status.retry_started").to_string();
                            } else {
                                app.status = t!("status.retry_no_engine").to_string();
                            }
                        } else {
                            app.status = t!("status.retry_only_failed").to_string();
                        }
                    }
                }
            } else {
                app.status = t!("status.retry_switch").to_string();
            }
        }
    }
}

// ─── 渲染 ────────────────────────────────────────────────────────

/// 给 snapshot 模块用：在外部 terminal 上画一帧。
pub fn render_once<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut App,
) -> Result<()> {
    terminal.draw(|f| ui(f, app))?;
    Ok(())
}

fn ui(f: &mut Frame, app: &mut App) {
    let area = f.area();
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),  // status bar
            Constraint::Length(1),  // tab bar
            Constraint::Length(1),  // engine status / 空态 banner
            Constraint::Min(10),    // 主区
            Constraint::Length(3),  // 底部 input
        ])
        .split(area);

    status_bar::render_top(f, chunks[0], &app.theme, &app.me, app.devices.len());
    render_tabs(f, chunks[1], app);
    render_engine_banner(f, chunks[2], app);
    render_main(f, chunks[3], app);
    render_bottom(f, chunks[4], app);

    // 模态层
    match app.mode {
        Mode::Help => help::render(f, area, &app.theme),
        Mode::Pairing => {
            if let Some(p) = &app.pending_pairing.clone() {
                let m = modals::centered(76, 20, area);
                pairing_modal::render(f, m, &app.theme, p);
            }
        }
        Mode::FileOffer => {
            if let Some(o) = &app.pending_offer.clone() {
                let m = modals::centered(72, 16, area);
                file_offer::render(f, m, &app.theme, o);
            }
        }
        _ => {
            if let Some(p) = &app.pending_pairing.clone() {
                let m = modals::centered(76, 20, area);
                pairing_modal::render(f, m, &app.theme, p);
            } else if let Some(o) = &app.pending_offer.clone() {
                let m = modals::centered(72, 16, area);
                file_offer::render(f, m, &app.theme, o);
            }
        }
    }
}

fn render_engine_banner(f: &mut Frame, area: Rect, app: &App) {
    let (text, color) = match &app.engine_status {
        EngineStatus::Starting => (
            t!("banner.scanning").to_string(),
            app.theme.lime(),
        ),
        EngineStatus::Live if app.devices.is_empty() => (
            t!("banner.empty").to_string(),
            app.theme.muted(),
        ),
        EngineStatus::Live => (
            t!("banner.live", count = app.devices.len()).to_string(),
            app.theme.lime_deep(),
        ),
        EngineStatus::Error(e) => (
            t!("banner.error", err = e).to_string(),
            app.theme.error(),
        ),
        EngineStatus::Mock => (
            t!("banner.demo").to_string(),
            app.theme.flame(),
        ),
    };
    let p = Paragraph::new(Line::from(Span::styled(
        text,
        Style::default().fg(color).add_modifier(Modifier::BOLD),
    )));
    f.render_widget(p, area);
}

fn render_tabs(f: &mut Frame, area: Rect, app: &App) {
    let mut spans = vec![Span::raw("  ")];
    for (page, key, label) in [
        (Page::Discovery, "F1", t!("tabs.discovery")),
        (Page::Transfers, "F2", t!("tabs.transfers")),
        (Page::History,   "F3", t!("tabs.history")),
        (Page::Trust,     "F4", t!("tabs.trust")),
        (Page::Clipboard, "F5", t!("tabs.clipboard")),
        (Page::Settings,  "F6", t!("tabs.settings")),
    ] {
        let active = page == app.page;
        let chip_text = format!("{} {}", key, label);
        spans.push(if active {
            chip::chip(&app.theme, &chip_text, chip::Tone::Lime)
        } else {
            chip::chip(&app.theme, &chip_text, chip::Tone::Outline)
        });
        spans.push(Span::raw("  "));
    }
    spans.push(Span::raw(""));
    let p = Paragraph::new(Line::from(spans));
    f.render_widget(p, area);
}

fn render_main(f: &mut Frame, area: Rect, app: &mut App) {
    match app.page {
        Page::Discovery => render_discovery(f, area, app),
        Page::Transfers => render_transfers(f, area, app),
        Page::History => render_history_page(f, area, app),
        Page::Trust => render_trust_page(f, area, app),
        Page::Clipboard => render_clipboard_page(f, area, app),
        Page::Settings => settings_page::render(f, area, &app.theme, &app.me, &app.settings),
    }
}

/// Trust 页：信任设备表（真 engine 模式从 trust_store 读取；mock 用占位提示）。
fn render_trust_page(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(app.theme.line()))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled("TRUST", Style::default().fg(app.theme.lime_deep()).add_modifier(Modifier::BOLD)),
            Span::styled(format!("  {}  {} ", app.theme.small_dot(), t!("trust.subtitle")), Style::default().fg(app.theme.muted())),
            Span::styled(format!("·  {} ", t!("trust.revoke_hint")), Style::default().fg(app.theme.muted())),
        ]));
    f.render_widget(&block, area);
    let inner = block.inner(area);

    let records = app.engine.as_ref().map(|e| e.trust_store.snapshot()).unwrap_or_default();
    let mut lines: Vec<Line> = Vec::new();
    lines.push(Line::from(""));
    if records.is_empty() {
        lines.push(Line::from(Span::styled(
            t!("trust.empty"),
            Style::default().fg(app.theme.muted()),
        )));
    } else {
        lines.push(Line::from(vec![
            Span::styled(t!("trust.table_header"),
                Style::default().fg(app.theme.muted()).add_modifier(Modifier::BOLD)),
        ]));
        for r in &records {
            let fp = chunk_fp4(&r.fingerprint);
            let seen = relative_ms(r.last_seen_ms);
            lines.push(Line::from(vec![
                Span::raw("  "),
                Span::styled(format!("{:<18}", trunc(&r.name, 18)), Style::default().fg(app.theme.ink()).add_modifier(Modifier::BOLD)),
                Span::raw(" "),
                Span::styled(format!("{:<28}", fp), Style::default().fg(app.theme.lime_deep())),
                Span::styled(seen, Style::default().fg(app.theme.muted())),
            ]));
        }
    }
    f.render_widget(Paragraph::new(lines), inner);
}

/// Clipboard 页：收件箱（对端推来的剪贴板条目）。
fn render_clipboard_page(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(app.theme.line()))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled("CLIPBOARD", Style::default().fg(app.theme.lime_deep()).add_modifier(Modifier::BOLD)),
            Span::styled(format!("  {}  {} ", app.theme.small_dot(), t!("clipboard.subtitle")), Style::default().fg(app.theme.muted())),
        ]));
    f.render_widget(&block, area);
    let inner = block.inner(area);

    let mut lines: Vec<Line> = Vec::new();
    lines.push(Line::from(""));
    if app.clip.is_empty() {
        lines.push(Line::from(Span::styled(
            t!("clipboard.empty"),
            Style::default().fg(app.theme.muted()),
        )));
    } else {
        for c in app.clip.iter().take(inner.height.saturating_sub(1) as usize) {
            let kind_label = format!("[{}]", c.kind.to_uppercase());
            let body = c.body.replace('\n', " ↵ ");
            let truncated: String = body.chars().take(60).collect();
            lines.push(Line::from(vec![
                Span::raw("  "),
                Span::styled(format!("{:<6}", kind_label), Style::default().fg(app.theme.lime_deep()).add_modifier(Modifier::BOLD)),
                Span::raw(" "),
                Span::styled(c.who.clone(), Style::default().fg(app.theme.flame()).add_modifier(Modifier::BOLD)),
                Span::raw("  "),
                Span::styled(truncated, Style::default().fg(app.theme.ink())),
                Span::styled(format!("  ·  {}", c.ago), Style::default().fg(app.theme.muted())),
            ]));
        }
    }
    f.render_widget(Paragraph::new(lines), inner);
}

fn chunk_fp4(hex: &str) -> String {
    let up = hex.to_uppercase();
    up.as_bytes().chunks(4).take(4)
        .map(|c| std::str::from_utf8(c).unwrap_or("").to_string())
        .collect::<Vec<_>>().join(" ")
}

fn relative_ms(unix_ms: i64) -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_millis() as i64).unwrap_or(0);
    let diff = (now - unix_ms).max(0) / 1000;
    if diff < 60 { t!("time.just_now").to_string() }
    else if diff < 3600 { t!("time.minutes_ago", n = diff / 60).to_string() }
    else if diff < 86400 { t!("time.hours_ago", n = diff / 3600).to_string() }
    else { t!("time.days_ago", n = diff / 86400).to_string() }
}

fn trunc(s: &str, max: usize) -> String {
    if s.chars().count() <= max { s.to_string() }
    else { s.chars().take(max.saturating_sub(1)).collect::<String>() + "…" }
}

fn render_discovery(f: &mut Frame, area: Rect, app: &mut App) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(45), Constraint::Percentage(55)])
        .split(area);

    let top = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(38), Constraint::Percentage(62)])
        .split(rows[0]);

    let filtered = app.filtered_devices();
    let filter_opt = if app.mode == Mode::Search || !app.filter.is_empty() {
        Some(app.filter.as_str())
    } else {
        None
    };
    device_list::render(
        f,
        top[0],
        &app.theme,
        &filtered,
        &mut app.device_state,
        filter_opt,
        app.focus == Focus::Devices,
    );
    history_widget::render(
        f,
        top[1],
        &app.theme,
        &app.history,
        &mut app.history_state,
        app.focus == Focus::History,
    );

    let bot = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(55), Constraint::Percentage(45)])
        .split(rows[1]);

    let radar_devices: Vec<mock::Device> = filtered.clone();
    let sel_idx = app.device_state.selected();
    radar::render(
        f,
        bot[0],
        &app.theme,
        &radar_devices,
        sel_idx,
        app.start,
        app.settings.radar,
    );

    render_info_panel(f, bot[1], app);
}

fn render_info_panel(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(app.theme.line()))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled(
                "SELF",
                Style::default().fg(app.theme.lime_deep()).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("  {}  {} ", app.theme.small_dot(), t!("info.self_label")),
                Style::default().fg(app.theme.muted()),
            ),
        ]));
    f.render_widget(&block, area);
    let inner = block.inner(area);

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(5),
            Constraint::Length(1),
            Constraint::Min(0),
        ])
        .split(inner);

    meshdrop_logo::hero(f, rows[0], &app.theme);

    let sub = Paragraph::new(Line::from(Span::styled(
        t!("info.self_sub"),
        Style::default().fg(app.theme.muted()),
    )))
    .alignment(ratatui::layout::Alignment::Center);
    f.render_widget(sub, rows[1]);

    ascii_divider::render(f, rows[2], &app.theme, &t!("info.self_divider"));

    let lines = vec![
        kv_line(&app.theme, "DEVICE", &app.me.name),
        kv_line(&app.theme, "OS    ", &app.me.os),
        kv_line(&app.theme, "IP    ", &app.me.ip),
        kv_line(&app.theme, "FP    ", &app.me.fingerprint),
        kv_line(&app.theme, "VISIB ", &app.me.visibility),
    ];
    f.render_widget(Paragraph::new(lines), rows[3]);

    ascii_divider::render(f, rows[4], &app.theme, &t!("info.clipboard_divider"));

    let clip_lines: Vec<Line> = app
        .clip
        .iter()
        .take(rows[5].height.saturating_sub(0) as usize)
        .map(|c| {
            let kind_label = format!("[{}]", c.kind.to_uppercase());
            let body = c.body.replace('\n', " ↵ ");
            let truncated: String = body.chars().take(38).collect();
            Line::from(vec![
                Span::raw("  "),
                Span::styled(
                    format!("{:<6}", kind_label),
                    Style::default().fg(app.theme.lime_deep()).add_modifier(Modifier::BOLD),
                ),
                Span::raw(" "),
                Span::styled(c.who.clone(), Style::default().fg(app.theme.flame()).add_modifier(Modifier::BOLD)),
                Span::raw(" "),
                Span::styled(truncated, Style::default().fg(app.theme.ink())),
                Span::styled(format!("  ·  {}", c.ago), Style::default().fg(app.theme.muted())),
            ])
        })
        .collect();
    f.render_widget(Paragraph::new(clip_lines), rows[5]);
}

fn kv_line<'a>(theme: &Theme, k: &'a str, v: &'a str) -> Line<'a> {
    Line::from(vec![
        Span::raw("  "),
        Span::styled(
            k,
            Style::default().fg(theme.muted()).add_modifier(Modifier::BOLD),
        ),
        Span::raw("  "),
        Span::styled(v, Style::default().fg(theme.ink())),
    ])
}

fn render_transfers(f: &mut Frame, area: Rect, app: &App) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(7), Constraint::Min(5)])
        .split(area);
    render_speed_chart(f, rows[0], app);
    transfer_row::render(f, rows[1], &app.theme, &app.transfers);
}

fn render_speed_chart(f: &mut Frame, area: Rect, app: &App) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(app.theme.line()))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled(
                "SPEED",
                Style::default().fg(app.theme.lime_deep()).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("  {}  {}  ", app.theme.small_dot(), t!("speed.subtitle")),
                Style::default().fg(app.theme.muted()),
            ),
            Span::styled("(↑ flame · ↓ sky · session)", Style::default().fg(app.theme.muted())),
            Span::raw(" "),
        ]));
    f.render_widget(&block, area);
    let inner = block.inner(area);

    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(33), Constraint::Percentage(33), Constraint::Percentage(34)])
        .split(inner);

    // engine 在场时用真实吞吐序列；demo / 截图（空序列）退回 mock 装饰柱。
    let up = if app.tp_up.is_empty() { mock::UPLOAD_BARS.to_vec() } else { app.tp_up.clone() };
    let down = if app.tp_down.is_empty() { mock::DOWNLOAD_BARS.to_vec() } else { app.tp_down.clone() };
    let session = if app.tp_session.is_empty() { mock::SESSION_BARS.to_vec() } else { app.tp_session.clone() };
    bar_chart(f, cols[0], &app.theme, "UP", &up, app.theme.flame());
    bar_chart(f, cols[1], &app.theme, "DOWN", &down, app.theme.sky());
    bar_chart(f, cols[2], &app.theme, "SESSION", &session, app.theme.lime_deep());
}

fn bar_chart<U: AsRef<[u8]>>(
    f: &mut Frame,
    area: Rect,
    theme: &Theme,
    title: &str,
    data: &U,
    color: ratatui::style::Color,
) {
    let data = data.as_ref();
    if area.height < 2 || area.width < 4 {
        return;
    }
    let max = *data.iter().max().unwrap_or(&1) as f32;
    let height = area.height.saturating_sub(1) as usize;
    let cap = (area.width.saturating_sub(2) as usize).min(data.len());

    let mut lines: Vec<Line> = Vec::with_capacity(height + 1);
    for row in 0..height {
        let threshold = (height - row) as f32 / height as f32 * max;
        let mut s = String::new();
        s.push(' ');
        for v in data.iter().take(cap) {
            if (*v as f32) >= threshold {
                s.push_str(theme.block(true));
            } else {
                s.push(' ');
            }
        }
        lines.push(Line::from(Span::styled(s, Style::default().fg(color))));
    }
    lines.push(Line::from(Span::styled(
        format!(" {} {}", title, t!("speed.samples", n = data.len())),
        Style::default().fg(theme.muted()).add_modifier(Modifier::BOLD),
    )));
    f.render_widget(Paragraph::new(lines), area);
}

fn render_history_page(f: &mut Frame, area: Rect, app: &mut App) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(1), Constraint::Min(5)])
        .split(area);
    ascii_divider::render(f, rows[0], &app.theme, &t!("history.today_divider"));
    history_widget::render(
        f,
        rows[1],
        &app.theme,
        &app.history,
        &mut app.history_state,
        true,
    );
}

fn render_bottom(f: &mut Frame, area: Rect, app: &App) {
    let target = app
        .filtered_devices()
        .get(app.device_state.selected().unwrap_or(0))
        .map(|d| d.who.to_string())
        .unwrap_or_else(|| "—".into());
    match app.mode {
        Mode::InputText => send::render(f, area, &app.theme, send::InputKind::Text, &app.input, &target),
        Mode::Command => send::render(f, area, &app.theme, send::InputKind::Command, &app.input, &target),
        Mode::Search => send::render(f, area, &app.theme, send::InputKind::Search, &app.input, &target),
        _ => send::render_status(
            f,
            area,
            &app.theme,
            &app.status,
            &t!("input.ready_hint"),
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// 正在输入文本时对端来配对：必须立刻顶出 Pairing 模态，而不是被静默吞掉。
    #[test]
    fn pairing_surfaces_over_input_text() {
        let mut app = App::new_demo();
        app.mode = Mode::InputText;
        app.input = "半句话".into();
        app.pending_pairing = Some(mock::pending_pairing());
        app.surface_pending_modal();
        assert_eq!(app.mode, Mode::Pairing);
    }

    /// Help 模态优先级最高，配对到达时不打断帮助页。
    #[test]
    fn pairing_does_not_interrupt_help() {
        let mut app = App::new_demo();
        app.mode = Mode::Help;
        app.pending_pairing = Some(mock::pending_pairing());
        app.surface_pending_modal();
        assert_eq!(app.mode, Mode::Help);
    }

    /// 关闭 Help 回到 Normal 后，仍挂着的配对应被重新顶出。
    #[test]
    fn pairing_resurfaces_after_help_closes() {
        let mut app = App::new_demo();
        app.mode = Mode::Help;
        app.pending_pairing = Some(mock::pending_pairing());
        apply(&mut app, Action::Cancel); // Esc 关 Help
        assert_eq!(app.mode, Mode::Pairing);
    }

    /// 无任何待处理项时，surface 不应改变当前模式。
    #[test]
    fn surface_is_noop_when_nothing_pending() {
        let mut app = App::new_demo();
        app.mode = Mode::InputText;
        app.surface_pending_modal();
        assert_eq!(app.mode, Mode::InputText);
    }
}
