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
    pub pending_pairing: Option<mock::PendingPairing>,
    pub pending_offer: Option<mock::PendingOffer>,

    // Engine 原始列表：执行命令时拿对应 CoreDevice / Pending* / history UUID
    pub core_devices: Vec<CoreDevice>,
    pub core_history: Vec<meshdrop_core::history::HistoryItem>,
    pub core_pairings: Vec<CorePendingPairing>,
    pub core_offers: Vec<CorePendingOffer>,

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
            pending_pairing: None,
            pending_offer: None,
            core_devices: Vec::new(),
            core_history: Vec::new(),
            core_pairings: Vec::new(),
            core_offers: Vec::new(),
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
            pending_pairing: None,
            pending_offer: None,
            core_devices: Vec::new(),
            core_history: Vec::new(),
            core_pairings: Vec::new(),
            core_offers: Vec::new(),
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
            self.focus = match p {
                Page::Discovery => Focus::Devices,
                Page::Transfers => Focus::Transfers,
                Page::History => Focus::History,
                Page::Settings => Focus::Devices,
            };
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
                            self.status = format!("已发送到 {} · {}", who, preview(&text, 40));
                        } else {
                            self.status = "没有选中设备".into();
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
                        self.status = format!("已发送到 {} · {}", peer, text);
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
    }

    fn run_command(&mut self, cmd: &str) {
        let parts: Vec<&str> = cmd.splitn(2, ' ').collect();
        match parts.as_slice() {
            ["q"] | ["quit"] | ["exit"] => self.quit = true,
            ["c"] | ["clear"] => {
                if let Some(engine) = &self.engine {
                    engine.clear_history();
                    self.status = "已清空历史".into();
                } else {
                    self.history.clear();
                    self.status = "已清空历史".into();
                }
            }
            ["trust"] => self.status = "用 :pair 流程信任设备（收到配对请求后按 t）".into(),
            ["revoke", fp] => self.status = format!("撤销信任：{}（暂未接 TrustStore 写入）", fp),
            ["f", path] => {
                let path_buf = std::path::PathBuf::from(expand_home(path));
                if !path_buf.exists() {
                    self.status = format!("文件不存在：{}", path);
                    return;
                }
                if let Some(engine) = &self.engine {
                    if let Some(peer) = self.selected_core_device() {
                        let who = peer.name.clone();
                        let name = path_buf.file_name().and_then(|s| s.to_str()).unwrap_or(path).to_string();
                        engine.send_file(peer, path_buf);
                        self.status = format!("发送文件 {} → {}", name, who);
                    } else {
                        self.status = "没有选中设备".into();
                    }
                } else {
                    self.status = format!("（mock）发送文件 {}", path);
                }
            }
            ["set", kv] => match self.settings.apply(kv) {
                SetResult::Ok { key, value } => {
                    if key == "displayName" {
                        self.me.name = value.clone();
                    }
                    self.status = format!("set {} = {}", key, value);
                }
                SetResult::UnknownKey(k) => self.status = format!("未知设置项：{}", k),
                SetResult::BadValue { key, value } => {
                    self.status = format!("非法值：{}={}", key, value);
                }
                SetResult::Syntax => {
                    self.status = "语法：:set key=value（如 :set radar=pulse）".into();
                }
            },
            _ => self.status = format!("未知命令：{}", cmd),
        }
    }

    fn refresh_transfers(&mut self) {
        // transfers 由进行中 / 最近 history 派生
        let me_label = self.me.name.clone();
        self.transfers = self
            .history
            .iter()
            .filter_map(|h| {
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
                Some(mock::Transfer {
                    name,
                    size,
                    ext,
                    from,
                    to,
                    progress,
                    state: h.state,
                    speed: None,
                    eta: None,
                })
            })
            .collect();
    }
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
            if app.pending_pairing.is_some() && app.mode == Mode::Normal {
                app.mode = Mode::Pairing;
            }
        }
        EngineUpdate::Offers { core, display } => {
            app.core_offers = core;
            app.pending_offer = display.into_iter().next();
            if app.pending_offer.is_some() && app.mode == Mode::Normal {
                app.mode = Mode::FileOffer;
            }
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
            app.focus = match p {
                Page::Discovery => Focus::Devices,
                Page::Transfers => Focus::Transfers,
                Page::History => Focus::History,
                Page::Settings => Focus::Devices,
            };
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
        }
        Action::Accept => {
            if let Some(engine) = &app.engine {
                if app.pending_pairing.is_some() {
                    if let Some(p) = app.core_pairings.first() {
                        engine.respond_pairing(p.id, PairingDecision::AllowOnce);
                        app.status = format!("已允许一次配对：{}", p.peer.name);
                    }
                }
                if app.pending_offer.is_some() {
                    if let Some(o) = app.core_offers.first() {
                        engine.respond_file_offer(o.id, true);
                        app.status = format!("已接受 {}", o.file_name);
                    }
                }
            } else {
                // mock 路径
                if let Some(p) = &app.pending_pairing {
                    app.status = format!("已允许一次配对：{}", p.peer);
                }
                if let Some(o) = &app.pending_offer {
                    app.status = format!("已接受 {}", o.file_name);
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
                    app.status = "已拒绝配对".into();
                }
                if app.pending_offer.is_some() {
                    if let Some(o) = app.core_offers.first() {
                        engine.respond_file_offer(o.id, false);
                    }
                    app.status = "已拒绝文件接收".into();
                }
            } else {
                if app.pending_pairing.is_some() {
                    app.status = "已拒绝配对".into();
                }
                if app.pending_offer.is_some() {
                    app.status = "已拒绝文件接收".into();
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
                        app.status = format!("已信任并保存：{}", p.peer.name);
                    }
                }
                if app.pending_offer.is_some() {
                    if let Some(o) = app.core_offers.first() {
                        engine.respond_file_offer(o.id, true);
                        app.status = format!("接受 {} 并信任 {}", o.file_name, o.peer.name);
                    }
                }
            } else {
                if let Some(p) = &app.pending_pairing {
                    app.status = format!("已信任并保存：{}", p.peer);
                }
                if let Some(o) = &app.pending_offer {
                    app.status = format!("接受 {} 并信任 {}", o.file_name, o.peer);
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
                        let id = app.history[i].id;
                        if let Some(engine) = &app.engine {
                            // mock id 是 u64，从 core UUID 截出来；删除时只能按显示位置近似
                            // — 实际删除走 engine.remove_history(uuid)，需要 UUID 回查。
                            // 为简化：在 engine 模式不支持单条删除（用 :c 清空全部）
                            let _ = (engine, id);
                            app.status = "engine 模式下请用 :c 清空（单条删除暂未接）".into();
                        } else {
                            app.history.remove(i);
                            if i >= app.history.len() && i > 0 {
                                app.history_state.select(Some(i - 1));
                            }
                            app.status = "删除一条历史".into();
                        }
                    }
                }
            }
        }
        Action::ClearHistory => {
            if let Some(engine) = &app.engine {
                engine.clear_history();
                app.status = "已清空历史".into();
            } else {
                app.history.clear();
                app.status = "已清空历史".into();
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
                                app.status = "已发起取消".into();
                            } else {
                                app.status = "engine 未连接，无法取消".into();
                            }
                        } else {
                            app.status = "只能取消进行中的传输".into();
                        }
                    }
                }
            } else {
                app.status = "切到 Transfers (F2) 后按 x 取消".into();
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
                                app.status = "已重新发起".into();
                            } else {
                                app.status = "engine 未连接，无法重发".into();
                            }
                        } else {
                            app.status = "只能重发失败的发送项".into();
                        }
                    }
                }
            } else {
                app.status = "切到 Transfers (F2) 后按 R 重发".into();
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
            "  扫描中 · scanning LAN · mDNS _meshdrop._tcp".to_string(),
            app.theme.lime(),
        ),
        EngineStatus::Live if app.devices.is_empty() => (
            "  附近没有 MeshDrop 设备 · 让朋友也打开试试".to_string(),
            app.theme.muted(),
        ),
        EngineStatus::Live => (
            format!("  LIVE · 已发现 {} 台设备", app.devices.len()),
            app.theme.lime_deep(),
        ),
        EngineStatus::Error(e) => (
            format!("  网络出错 — {}", e),
            app.theme.error(),
        ),
        EngineStatus::Mock => (
            "  DEMO 模式 · mock 数据 · 不接 backend".to_string(),
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
        (Page::Discovery, "F1", "DISCOVERY · 发现"),
        (Page::Transfers, "F2", "TRANSFERS · 传输"),
        (Page::History,   "F3", "HISTORY · 历史"),
        (Page::Settings,  "F4", "SETTINGS · 设置"),
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
        Page::Settings => settings_page::render(f, area, &app.theme, &app.me, &app.settings),
    }
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
                format!("  {}  本机 ", app.theme.small_dot()),
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
        "雷达式发现 · 端对端加密 · 拖即发送 · 剪贴板同步 · 文字便签",
        Style::default().fg(app.theme.muted()),
    )))
    .alignment(ratatui::layout::Alignment::Center);
    f.render_widget(sub, rows[1]);

    ascii_divider::render(f, rows[2], &app.theme, "SELF · 本机");

    let lines = vec![
        kv_line(&app.theme, "DEVICE", &app.me.name),
        kv_line(&app.theme, "OS    ", &app.me.os),
        kv_line(&app.theme, "IP    ", &app.me.ip),
        kv_line(&app.theme, "FP    ", &app.me.fingerprint),
        kv_line(&app.theme, "VISIB ", &app.me.visibility),
    ];
    f.render_widget(Paragraph::new(lines), rows[3]);

    ascii_divider::render(f, rows[4], &app.theme, "CLIPBOARD · 剪贴板");

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
                format!("  {}  速度  ", app.theme.small_dot()),
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

    bar_chart(f, cols[0], &app.theme, "UP", &mock::UPLOAD_BARS, app.theme.flame());
    bar_chart(f, cols[1], &app.theme, "DOWN", &mock::DOWNLOAD_BARS, app.theme.sky());
    bar_chart(f, cols[2], &app.theme, "SESSION", &mock::SESSION_BARS, app.theme.lime_deep());
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
        format!(" {} ({}样)", title, data.len()),
        Style::default().fg(theme.muted()).add_modifier(Modifier::BOLD),
    )));
    f.render_widget(Paragraph::new(lines), area);
}

fn render_history_page(f: &mut Frame, area: Rect, app: &mut App) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(1), Constraint::Min(5)])
        .split(area);
    ascii_divider::render(f, rows[0], &app.theme, "TODAY · 今天");
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
            "↑↓ 选择  ·  Enter 发文本  ·  : 命令  ·  / 搜索  ·  ? 帮助  ·  q 退出",
        ),
    }
}
