//! COMMON §9 mock 数据的 Rust 化。所有 UI 由它驱动，不接 backend。

#![allow(dead_code)]

use std::sync::atomic::{AtomicU64, Ordering};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DeviceKind {
    Mac,
    Android,
    IPad,
    IOS,
    Win,
    Linux,
}

impl DeviceKind {
    pub fn glyph(self) -> &'static str {
        match self {
            DeviceKind::Mac => "▢",
            DeviceKind::Android => "▮",
            DeviceKind::IPad => "▭",
            DeviceKind::IOS => "▯",
            DeviceKind::Win => "⊞",
            DeviceKind::Linux => "◇",
        }
    }
    pub fn short(self) -> &'static str {
        match self {
            DeviceKind::Mac => "mac",
            DeviceKind::Android => "pix",
            DeviceKind::IPad => "ipad",
            DeviceKind::IOS => "ios",
            DeviceKind::Win => "win",
            DeviceKind::Linux => "linux",
        }
    }
    pub fn os(self) -> &'static str {
        match self {
            DeviceKind::Mac => "macOS",
            DeviceKind::Android => "Pixel",
            DeviceKind::IPad => "iPadOS",
            DeviceKind::IOS => "iOS",
            DeviceKind::Win => "Win 11",
            DeviceKind::Linux => "Linux",
        }
    }
}

#[derive(Clone, Debug)]
pub struct Device {
    pub id: &'static str,
    pub name: &'static str,
    pub who: &'static str,
    pub kind: DeviceKind,
    pub initials: &'static str,
    /// 0.0..=1.0 雷达距离
    pub dist: f32,
    /// 极坐标角度，0=东，CCW
    pub angle: f32,
    pub rtt_ms: u32,
}

pub fn devices() -> Vec<Device> {
    vec![
        Device { id: "lily",   name: "Lily's MacBook",   who: "李莉",   kind: DeviceKind::Mac,     initials: "LL", dist: 0.55, angle: 35.0,  rtt_ms: 18 },
        Device { id: "kun",    name: "Kun · Pixel 8",    who: "坤",     kind: DeviceKind::Android, initials: "K",  dist: 0.78, angle: 110.0, rtt_ms: 32 },
        Device { id: "jiawei", name: "Jiawei · iPad",    who: "嘉伟",   kind: DeviceKind::IPad,    initials: "JW", dist: 0.40, angle: 200.0, rtt_ms: 14 },
        Device { id: "mengxi", name: "Meng Xi · iPhone", who: "孟茜",   kind: DeviceKind::IOS,     initials: "MX", dist: 0.62, angle: 265.0, rtt_ms: 26 },
        Device { id: "dev01",  name: "DEV-01 · Win 11",  who: "工位机", kind: DeviceKind::Win,     initials: "D1", dist: 0.88, angle: 320.0, rtt_ms: 41 },
    ]
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Direction {
    Outgoing,
    Incoming,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HistoryState {
    Done,
    Sending,
    Receiving,
    Queued,
    Failed,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum HistoryBody {
    Text(String),
    File {
        name: String,
        size: String,
        ext: String,
        progress: Option<u8>,
    },
    Image {
        count: u32,
    },
}

#[derive(Clone, Debug)]
pub struct HistoryItem {
    pub id: u64,
    pub dir: Direction,
    pub peer: String,
    pub time: String,
    pub body: HistoryBody,
    pub state: HistoryState,
}

static NEXT_ID: AtomicU64 = AtomicU64::new(100);
pub fn next_id() -> u64 {
    NEXT_ID.fetch_add(1, Ordering::Relaxed)
}

pub fn history() -> Vec<HistoryItem> {
    vec![
        HistoryItem {
            id: 6, dir: Direction::Incoming, peer: "孟茜".into(), time: "14:18".into(),
            body: HistoryBody::Image { count: 2 }, state: HistoryState::Done,
        },
        HistoryItem {
            id: 5, dir: Direction::Outgoing, peer: "孟茜".into(), time: "14:10".into(),
            body: HistoryBody::File { name: "设计稿_v3_final.fig".into(), size: "14.2 MB".into(), ext: "fig".into(), progress: None },
            state: HistoryState::Done,
        },
        HistoryItem {
            id: 4, dir: Direction::Outgoing, peer: "李莉".into(), time: "14:09".into(),
            body: HistoryBody::Text("改完了，整理一下发你 👇".into()),
            state: HistoryState::Done,
        },
        HistoryItem {
            id: 3, dir: Direction::Outgoing, peer: "嘉伟".into(), time: "14:08".into(),
            body: HistoryBody::File { name: "iOS-mocks-final.zip".into(), size: "48.6 MB".into(), ext: "zip".into(), progress: Some(67) },
            state: HistoryState::Sending,
        },
        HistoryItem {
            id: 2, dir: Direction::Incoming, peer: "坤".into(), time: "13:58".into(),
            body: HistoryBody::File { name: "IMG_4821~38.heic".into(), size: "128 MB".into(), ext: "heic".into(), progress: Some(12) },
            state: HistoryState::Receiving,
        },
        HistoryItem {
            id: 1, dir: Direction::Outgoing, peer: "李莉".into(), time: "13:42".into(),
            body: HistoryBody::File { name: "demo-video.mp4".into(), size: "512 MB".into(), ext: "mp4".into(), progress: None },
            state: HistoryState::Queued,
        },
    ]
}

#[derive(Clone, Debug)]
pub struct PendingPairing {
    pub peer: &'static str,
    pub device_name: &'static str,
    pub fingerprint: &'static str,
    pub code: &'static str,
    pub received_at: &'static str,
}

pub fn pending_pairing() -> PendingPairing {
    PendingPairing {
        peer: "李莉",
        device_name: "Lily's MacBook",
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF",
        code: "QX8K7L2M",
        received_at: "8s ago",
    }
}

#[derive(Clone, Debug)]
pub struct PendingOffer {
    pub peer: &'static str,
    pub device_name: &'static str,
    pub file_name: &'static str,
    pub file_size: &'static str,
    pub note: &'static str,
    pub received_at: &'static str,
}

pub fn pending_offer() -> PendingOffer {
    PendingOffer {
        peer: "嘉伟",
        device_name: "Jiawei · iPad",
        file_name: "规划文档_v0.3.pages",
        file_size: "3.4 MB",
        note: "改完了帮我看下第二章，特别是 §2.3 那段",
        received_at: "just now",
    }
}

#[derive(Clone, Debug)]
pub struct ClipItem {
    pub who: &'static str,
    pub kind: &'static str,
    pub body: &'static str,
    pub ago: &'static str,
}

pub fn clipboard() -> Vec<ClipItem> {
    vec![
        ClipItem { who: "嘉伟", kind: "link", body: "https://internal.acme.io/specs/auth-v3", ago: "8s" },
        ClipItem { who: "孟茜", kind: "text", body: "1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配", ago: "12m" },
        ClipItem { who: "李莉", kind: "code", body: "docker run --rm -v $PWD:/app meshdrop/build:latest", ago: "34m" },
        ClipItem { who: "坤",   kind: "text", body: "会议室 B 已订到 16:00–17:30", ago: "1h" },
        ClipItem { who: "我",   kind: "link", body: "figma://file/Q8xK2/MeshDrop?node-id=42:108", ago: "2h" },
    ]
}

#[derive(Clone, Debug)]
pub struct Transfer {
    pub name: &'static str,
    pub size: &'static str,
    pub ext: &'static str,
    pub from: &'static str,
    pub to: &'static str,
    pub progress: u8,
    pub state: HistoryState,
    pub speed: Option<&'static str>,
    pub eta: Option<&'static str>,
}

pub fn transfers() -> Vec<Transfer> {
    vec![
        Transfer { name: "设计稿_v3_final.fig", size: "14.2 MB", ext: "fig", from: "我", to: "孟茜", progress: 100, state: HistoryState::Done, speed: None, eta: Some("00:08") },
        Transfer { name: "iOS-mocks-final.zip",  size: "48.6 MB", ext: "zip", from: "我", to: "孟茜", progress: 67,  state: HistoryState::Sending,   speed: Some("8.4 MB/s"), eta: Some("00:02") },
        Transfer { name: "spec_PRD_2026Q1.pdf",  size: "2.1 MB",  ext: "pdf", from: "我", to: "嘉伟", progress: 34,  state: HistoryState::Sending,   speed: Some("3.1 MB/s"), eta: Some("00:01") },
        Transfer { name: "IMG_4821~IMG_4838.heic", size: "128 MB · 18 张", ext: "heic", from: "坤", to: "我", progress: 12, state: HistoryState::Receiving, speed: Some("11.7 MB/s"), eta: Some("00:09") },
        Transfer { name: "release-notes.md",     size: "4.8 KB",  ext: "md",  from: "我", to: "DEV-01", progress: 100, state: HistoryState::Done, speed: None, eta: Some("00:01") },
        Transfer { name: "demo-video.mp4",       size: "512 MB",  ext: "mp4", from: "我", to: "李莉", progress: 0,   state: HistoryState::Queued, speed: None, eta: None },
    ]
}

pub const UPLOAD_BARS:   [u8; 14] = [3,5,8,7,9,6,11,12,14,11,10,11,12,11];
pub const DOWNLOAD_BARS: [u8; 14] = [8,9,7,6,5,7,10,12,11,12,11,12,11,12];
pub const SESSION_BARS:  [u8; 15] = [2,3,5,4,6,8,7,9,10,12,11,12,11,12,14];

#[derive(Clone, Debug)]
pub struct SelfCard {
    pub name: String,
    pub fingerprint: &'static str,
    pub ip: String,
    pub os: &'static str,
    pub visibility: &'static str,
}

pub fn self_card() -> SelfCard {
    let host = std::env::var("HOSTNAME")
        .ok()
        .or_else(|| std::fs::read_to_string("/etc/hostname").ok().map(|s| s.trim().to_string()))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "DEV-01".to_string());
    SelfCard {
        name: host,
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2",
        ip: "192.168.1.42".into(),
        os: "Linux",
        visibility: "可见",
    }
}
