//! `meshdrop_core::ShareEngine` ↔ TUI 显示层之间的桥。
//!
//! 职责：
//! 1. 拉起 Identity + Engine（CLI / TUI 共用同一引导路径）。
//! 2. 把 core 的领域对象（Device / HistoryItem / Pending*）转成 widget 直接消费的 `mock::*` 结构。
//!    雷达 dist / angle 由设备 id 哈希推出，位置稳定。
//! 3. 启动 watcher 任务：4 个 `watch::Receiver` 的变更合并到一个
//!    `mpsc::UnboundedSender<EngineUpdate>`，TUI 主循环 select 消费。
//!    Update 同时带 core 原始列表（发命令用）和 mock 显示列表（widget 用）。

use anyhow::{Context, Result};
use meshdrop_core::{
    Device as CoreDevice, DeviceOS, HistoryItem as CoreHistoryItem, HistoryKind,
    Identity, PendingFileOffer as CorePendingOffer, PendingPairing as CorePendingPairing,
    ShareEngine, TransferDirection, TransferStatus,
};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};
use std::sync::Arc;
use tokio::sync::mpsc;

use crate::mock;

// ───────── 启动 ─────────

pub async fn start(display_name: Option<String>) -> Result<ShareEngine> {
    let identity = Identity::load_or_create().context("加载身份失败")?;
    let identity = Arc::new(identity);
    let name = display_name.unwrap_or_else(default_display_name);
    let model = detect_model();
    let engine = ShareEngine::start(identity, name, model)
        .await
        .context("启动 ShareEngine 失败")?;
    Ok(engine)
}

pub fn default_display_name() -> String {
    if let Ok(name) = std::env::var("MESHDROP_NAME") {
        if !name.trim().is_empty() {
            return name.trim().to_string();
        }
    }
    std::env::var("HOSTNAME")
        .ok()
        .or_else(|| std::fs::read_to_string("/etc/hostname").ok().map(|s| s.trim().to_string()))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "linux".into())
}

fn detect_model() -> Option<String> {
    std::fs::read_to_string("/sys/class/dmi/id/product_name")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
}

// ───────── EngineUpdate ─────────

#[derive(Debug)]
pub enum EngineUpdate {
    Devices { core: Vec<CoreDevice>, display: Vec<mock::Device> },
    History { display: Vec<mock::HistoryItem> },
    Pairings { core: Vec<CorePendingPairing>, display: Vec<mock::PendingPairing> },
    Offers { core: Vec<CorePendingOffer>, display: Vec<mock::PendingOffer> },
}

pub fn spawn_watchers(engine: &ShareEngine) -> mpsc::UnboundedReceiver<EngineUpdate> {
    let (tx, rx) = mpsc::unbounded_channel::<EngineUpdate>();

    {
        let mut rcv = engine.devices_rx();
        let tx = tx.clone();
        tokio::spawn(async move {
            let snap = rcv.borrow().clone();
            let display = adapt_devices(&snap);
            if tx.send(EngineUpdate::Devices { core: snap, display }).is_err() { return; }
            while rcv.changed().await.is_ok() {
                let snap = rcv.borrow().clone();
                let display = adapt_devices(&snap);
                if tx.send(EngineUpdate::Devices { core: snap, display }).is_err() { break; }
            }
        });
    }
    {
        let mut rcv = engine.history_rx();
        let tx = tx.clone();
        tokio::spawn(async move {
            let display = adapt_history(&rcv.borrow());
            if tx.send(EngineUpdate::History { display }).is_err() { return; }
            while rcv.changed().await.is_ok() {
                let display = adapt_history(&rcv.borrow());
                if tx.send(EngineUpdate::History { display }).is_err() { break; }
            }
        });
    }
    {
        let mut rcv = engine.pending_pairings_rx();
        let tx = tx.clone();
        tokio::spawn(async move {
            let snap = rcv.borrow().clone();
            let display = adapt_pairings(&snap);
            if tx.send(EngineUpdate::Pairings { core: snap, display }).is_err() { return; }
            while rcv.changed().await.is_ok() {
                let snap = rcv.borrow().clone();
                let display = adapt_pairings(&snap);
                if tx.send(EngineUpdate::Pairings { core: snap, display }).is_err() { break; }
            }
        });
    }
    {
        let mut rcv = engine.pending_offers_rx();
        let tx = tx.clone();
        tokio::spawn(async move {
            let snap = rcv.borrow().clone();
            let display = adapt_offers(&snap);
            if tx.send(EngineUpdate::Offers { core: snap, display }).is_err() { return; }
            while rcv.changed().await.is_ok() {
                let snap = rcv.borrow().clone();
                let display = adapt_offers(&snap);
                if tx.send(EngineUpdate::Offers { core: snap, display }).is_err() { break; }
            }
        });
    }

    rx
}

// ───────── 适配：core → mock 显示 ─────────

pub fn adapt_devices(list: &[CoreDevice]) -> Vec<mock::Device> {
    list.iter().map(adapt_device).collect()
}

fn adapt_device(d: &CoreDevice) -> mock::Device {
    let kind = match d.os {
        DeviceOS::Macos => mock::DeviceKind::Mac,
        DeviceOS::Ios => mock::DeviceKind::IOS,
        DeviceOS::Android => mock::DeviceKind::Android,
        DeviceOS::Windows => mock::DeviceKind::Win,
        DeviceOS::Linux => mock::DeviceKind::Linux,
    };
    let mut h = DefaultHasher::new();
    d.id.hash(&mut h);
    let h = h.finish();
    let angle = (h % 360) as f32;
    let dist = 0.35 + ((h >> 8) % 100) as f32 / 200.0; // 0.35..=0.85

    let who = display_who(&d.name);
    let model_label = d.model.clone().unwrap_or_else(|| kind.os().to_string());
    let name = format!("{} · {}", who, model_label);
    let initials = derive_initials(&who);

    mock::Device {
        id: d.id.clone(),
        name,
        who,
        kind,
        initials,
        dist,
        angle,
        rtt_ms: 0,
    }
}

fn display_who(raw: &str) -> String {
    let trimmed = raw.trim();
    if trimmed.is_empty() { "(unnamed)".into() } else { trimmed.to_string() }
}

fn derive_initials(name: &str) -> String {
    name.split_whitespace()
        .filter_map(|w| w.chars().next())
        .take(2)
        .collect::<String>()
        .to_uppercase()
}

pub fn adapt_history(list: &[CoreHistoryItem]) -> Vec<mock::HistoryItem> {
    list.iter().map(adapt_history_item).collect()
}

fn adapt_history_item(h: &CoreHistoryItem) -> mock::HistoryItem {
    let dir = match h.direction {
        TransferDirection::Outgoing => mock::Direction::Outgoing,
        TransferDirection::Incoming => mock::Direction::Incoming,
    };
    let state = match &h.status {
        TransferStatus::Completed => mock::HistoryState::Done,
        TransferStatus::Pending | TransferStatus::WaitingApproval => mock::HistoryState::Queued,
        TransferStatus::Transferring { .. } => match dir {
            mock::Direction::Outgoing => mock::HistoryState::Sending,
            mock::Direction::Incoming => mock::HistoryState::Receiving,
        },
        TransferStatus::Failed(_) | TransferStatus::Canceled => mock::HistoryState::Failed,
    };
    let body = match &h.kind {
        HistoryKind::Text(s) => mock::HistoryBody::Text(s.clone()),
        HistoryKind::File { name, size, .. } => {
            let ext = name
                .rsplit_once('.')
                .map(|(_, e)| e.to_string())
                .unwrap_or_else(|| "bin".into());
            let progress = match &h.status {
                TransferStatus::Transferring { done, total } if *total > 0 => {
                    Some(((*done as u128 * 100 / *total as u128) as u8).min(100))
                }
                TransferStatus::Completed => Some(100),
                _ => None,
            };
            mock::HistoryBody::File {
                name: name.clone(),
                size: meshdrop_core::history::format_bytes(*size),
                ext,
                progress,
            }
        }
    };
    let peer = display_who(&h.peer.name);
    let id = u64_from_uuid(h.id);
    mock::HistoryItem {
        id,
        dir,
        peer,
        time: hhmm_from_ms(h.created_at.unix_ms),
        body,
        state,
    }
}

pub fn adapt_pairings(list: &[CorePendingPairing]) -> Vec<mock::PendingPairing> {
    list.iter().map(adapt_pairing).collect()
}

fn adapt_pairing(p: &CorePendingPairing) -> mock::PendingPairing {
    let peer = display_who(&p.peer.name);
    let fp = chunk_for_modal(&p.peer.human_fingerprint());
    let code = derive_pair_code(&p.peer.fingerprint);
    let device_name = p.peer.model.clone().unwrap_or_else(|| p.peer.os.to_string());
    mock::PendingPairing {
        id: p.id.to_string(),
        peer,
        device_name,
        fingerprint: fp,
        code,
        received_at: "just now".into(),
    }
}

pub fn adapt_offers(list: &[CorePendingOffer]) -> Vec<mock::PendingOffer> {
    list.iter().map(adapt_offer).collect()
}

fn adapt_offer(o: &CorePendingOffer) -> mock::PendingOffer {
    let peer = display_who(&o.peer.name);
    let device_name = o.peer.model.clone().unwrap_or_else(|| o.peer.os.to_string());
    mock::PendingOffer {
        id: o.id.to_string(),
        peer,
        device_name,
        file_name: o.file_name.clone(),
        file_size: o.formatted_size(),
        note: format!("SHA-256: {}", &o.sha256[..o.sha256.len().min(16)]),
        received_at: "just now".into(),
    }
}

// ───────── 自卡 ─────────

pub fn self_card(engine: &ShareEngine) -> mock::SelfCard {
    let fp = chunk_fingerprint(&engine.identity.fingerprint);
    mock::SelfCard {
        name: engine.display_name.clone(),
        fingerprint: fp,
        ip: detect_lan_ip().unwrap_or_else(|| "0.0.0.0".into()),
        os: "Linux".into(),
        visibility: "可见".into(),
    }
}

fn chunk_fingerprint(hex: &str) -> String {
    let up = hex.to_uppercase();
    up.as_bytes()
        .chunks(4)
        .take(4)
        .map(|c| std::str::from_utf8(c).unwrap_or("").to_string())
        .collect::<Vec<_>>()
        .join(" · ")
}

fn chunk_for_modal(human: &str) -> String {
    human.split_whitespace().collect::<Vec<_>>().join(" · ")
}

fn derive_pair_code(fp_hex: &str) -> String {
    fp_hex
        .chars()
        .filter(|c| c.is_alphanumeric())
        .take(8)
        .collect::<String>()
        .to_uppercase()
}

fn u64_from_uuid(id: uuid::Uuid) -> u64 {
    let bytes = id.as_bytes();
    let mut a = [0u8; 8];
    a.copy_from_slice(&bytes[..8]);
    u64::from_be_bytes(a)
}

fn hhmm_from_ms(unix_ms: i64) -> String {
    let secs = (unix_ms / 1000).rem_euclid(86400);
    let h = (secs / 3600) % 24;
    let m = (secs / 60) % 60;
    format!("{:02}:{:02}", h, m)
}

fn detect_lan_ip() -> Option<String> {
    use std::net::UdpSocket;
    let s = UdpSocket::bind("0.0.0.0:0").ok()?;
    s.connect("198.18.0.1:80").ok()?;
    let local = s.local_addr().ok()?;
    Some(local.ip().to_string())
}

// ───────── peer 解析（CLI 用） ─────────

pub fn resolve_peer(list: &[CoreDevice], input: &str) -> Option<CoreDevice> {
    let lower = input.to_lowercase();
    if let Some(d) = list.iter().find(|d| d.id.eq_ignore_ascii_case(input)) {
        return Some(d.clone());
    }
    if let Some(d) = list.iter().find(|d| d.name == input) {
        return Some(d.clone());
    }
    if let Some(d) = list.iter().find(|d| d.name.to_lowercase().contains(&lower)) {
        return Some(d.clone());
    }
    if let Some(d) = list.iter().find(|d| d.fingerprint.starts_with(&lower)) {
        return Some(d.clone());
    }
    None
}
