//! UI 显示层数据结构（被 widget 渲染）。
//!
//! - 旧 mock 数据：`mock::devices()` 等仍是静态 fixture，供 `--demo` 截图 / snapshot 子命令使用。
//! - 真实运行时：`engine_bridge` 把 `meshdrop_core` 的类型转成下面这些结构后注入 App。
//!
//! 字段都用 `String`（既能放 'static 字面量，也能放动态数据）。

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
    pub id: String,
    pub name: String,
    pub who: String,
    pub kind: DeviceKind,
    pub initials: String,
    /// 0.0..=1.0 雷达距离
    pub dist: f32,
    /// 极坐标角度，0=东，CCW
    pub angle: f32,
    pub rtt_ms: u32,
}

pub fn devices() -> Vec<Device> {
    vec![
        Device { id: "lily".into(),   name: "Lily's MacBook".into(),   who: "李莉".into(),   kind: DeviceKind::Mac,     initials: "LL".into(), dist: 0.55, angle: 35.0,  rtt_ms: 18 },
        Device { id: "kun".into(),    name: "Kun · Pixel 8".into(),    who: "坤".into(),     kind: DeviceKind::Android, initials: "K".into(),  dist: 0.78, angle: 110.0, rtt_ms: 32 },
        Device { id: "jiawei".into(), name: "Jiawei · iPad".into(),    who: "嘉伟".into(),   kind: DeviceKind::IPad,    initials: "JW".into(), dist: 0.40, angle: 200.0, rtt_ms: 14 },
        Device { id: "mengxi".into(), name: "Meng Xi · iPhone".into(), who: "孟茜".into(),   kind: DeviceKind::IOS,     initials: "MX".into(), dist: 0.62, angle: 265.0, rtt_ms: 26 },
        Device { id: "dev01".into(),  name: "DEV-01 · Win 11".into(),  who: "工位机".into(), kind: DeviceKind::Win,     initials: "D1".into(), dist: 0.88, angle: 320.0, rtt_ms: 41 },
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
    pub id: String,
    pub peer: String,
    pub device_name: String,
    pub fingerprint: String,
    pub code: String,
    pub received_at: String,
}

pub fn pending_pairing() -> PendingPairing {
    PendingPairing {
        id: "demo".into(),
        peer: "李莉".into(),
        device_name: "Lily's MacBook".into(),
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF".into(),
        code: "QX8K7L2M".into(),
        received_at: "8s ago".into(),
    }
}

#[derive(Clone, Debug)]
pub struct PendingOffer {
    pub id: String,
    pub peer: String,
    pub device_name: String,
    pub file_name: String,
    pub file_size: String,
    pub note: String,
    pub received_at: String,
}

pub fn pending_offer() -> PendingOffer {
    PendingOffer {
        id: "demo".into(),
        peer: "嘉伟".into(),
        device_name: "Jiawei · iPad".into(),
        file_name: "规划文档_v0.3.pages".into(),
        file_size: "3.4 MB".into(),
        note: "改完了帮我看下第二章，特别是 §2.3 那段".into(),
        received_at: "just now".into(),
    }
}

#[derive(Clone, Debug)]
pub struct ClipItem {
    pub who: String,
    pub kind: String,
    pub body: String,
    pub ago: String,
}

pub fn clipboard() -> Vec<ClipItem> {
    vec![
        ClipItem { who: "嘉伟".into(), kind: "link".into(), body: "https://internal.acme.io/specs/auth-v3".into(), ago: "8s".into() },
        ClipItem { who: "孟茜".into(), kind: "text".into(), body: "1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配".into(), ago: "12m".into() },
        ClipItem { who: "李莉".into(), kind: "code".into(), body: "docker run --rm -v $PWD:/app meshdrop/build:latest".into(), ago: "34m".into() },
        ClipItem { who: "坤".into(),   kind: "text".into(), body: "会议室 B 已订到 16:00–17:30".into(), ago: "1h".into() },
        ClipItem { who: "我".into(),   kind: "link".into(), body: "figma://file/Q8xK2/MeshDrop?node-id=42:108".into(), ago: "2h".into() },
    ]
}

#[derive(Clone, Debug)]
pub struct Transfer {
    pub name: String,
    pub size: String,
    pub ext: String,
    pub from: String,
    pub to: String,
    pub progress: u8,
    pub state: HistoryState,
    pub speed: Option<String>,
    pub eta: Option<String>,
}

pub fn transfers() -> Vec<Transfer> {
    vec![
        Transfer { name: "设计稿_v3_final.fig".into(), size: "14.2 MB".into(), ext: "fig".into(), from: "我".into(), to: "孟茜".into(), progress: 100, state: HistoryState::Done, speed: None, eta: Some("00:08".into()) },
        Transfer { name: "iOS-mocks-final.zip".into(),  size: "48.6 MB".into(), ext: "zip".into(), from: "我".into(), to: "孟茜".into(), progress: 67,  state: HistoryState::Sending,   speed: Some("8.4 MB/s".into()), eta: Some("00:02".into()) },
        Transfer { name: "spec_PRD_2026Q1.pdf".into(),  size: "2.1 MB".into(),  ext: "pdf".into(), from: "我".into(), to: "嘉伟".into(), progress: 34,  state: HistoryState::Sending,   speed: Some("3.1 MB/s".into()), eta: Some("00:01".into()) },
        Transfer { name: "IMG_4821~IMG_4838.heic".into(), size: "128 MB · 18 张".into(), ext: "heic".into(), from: "坤".into(), to: "我".into(), progress: 12, state: HistoryState::Receiving, speed: Some("11.7 MB/s".into()), eta: Some("00:09".into()) },
        Transfer { name: "release-notes.md".into(),     size: "4.8 KB".into(),  ext: "md".into(),  from: "我".into(), to: "DEV-01".into(), progress: 100, state: HistoryState::Done, speed: None, eta: Some("00:01".into()) },
        Transfer { name: "demo-video.mp4".into(),       size: "512 MB".into(),  ext: "mp4".into(), from: "我".into(), to: "李莉".into(), progress: 0,   state: HistoryState::Queued, speed: None, eta: None },
    ]
}

pub const UPLOAD_BARS:   [u8; 14] = [3,5,8,7,9,6,11,12,14,11,10,11,12,11];
pub const DOWNLOAD_BARS: [u8; 14] = [8,9,7,6,5,7,10,12,11,12,11,12,11,12];
pub const SESSION_BARS:  [u8; 15] = [2,3,5,4,6,8,7,9,10,12,11,12,11,12,14];

#[derive(Clone, Debug)]
pub struct SelfCard {
    pub name: String,
    pub fingerprint: String,
    pub ip: String,
    pub os: String,
    pub visibility: String,
}

pub fn self_card() -> SelfCard {
    let host = std::env::var("HOSTNAME")
        .ok()
        .or_else(|| std::fs::read_to_string("/etc/hostname").ok().map(|s| s.trim().to_string()))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "DEV-01".to_string());
    SelfCard {
        name: host,
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2".into(),
        ip: "192.168.1.42".into(),
        os: "Linux".into(),
        visibility: "可见".into(),
    }
}
