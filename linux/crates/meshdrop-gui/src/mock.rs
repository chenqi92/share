//! 全部 mock 数据。COMMON §9 Rust 化。
//! 本轮 UI-FIRST：所有页面渲染都从这里取数据，不接 backend。

#![allow(dead_code)]

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DeviceKind { Mac, Win, Linux, Ipad, Ios, Android }

impl DeviceKind {
    pub fn os_label(self) -> &'static str {
        match self {
            DeviceKind::Mac     => "macOS",
            DeviceKind::Win     => "Win 11",
            DeviceKind::Linux   => "Linux",
            DeviceKind::Ipad    => "iPadOS",
            DeviceKind::Ios     => "iOS",
            DeviceKind::Android => "Android",
        }
    }
}

#[derive(Clone, Debug)]
pub struct MockDevice {
    pub id: &'static str,
    pub name: &'static str,
    pub who: &'static str,
    pub kind: DeviceKind,
    pub dist: f64,    // 0.0 ~ 1.0 (radar 极径)
    pub angle: f64,   // 角度（°）
    pub color: &'static str,   // hex
    pub initials: &'static str,
    pub os: &'static str,
    pub model: &'static str,
    pub rtt_ms: u32,
    pub ip: &'static str,
    pub fp_short: &'static str,
    pub online: bool,
}

pub fn devices() -> Vec<MockDevice> {
    vec![
        MockDevice { id: "lily",   name: "Lily's MacBook",   who: "李莉",   kind: DeviceKind::Mac,
                     dist: 0.55, angle: 35.0,  color: "#FFB4A1", initials: "LL",
                     os: "macOS", model: "MacBook Pro 14", rtt_ms: 18,
                     ip: "192.168.1.21", fp_short: "ZX8K · L72M", online: true },
        MockDevice { id: "kun",    name: "Kun · Pixel 8",    who: "坤",     kind: DeviceKind::Android,
                     dist: 0.78, angle: 110.0, color: "#B7E5C8", initials: "K",
                     os: "Pixel",  model: "Pixel 8 Pro", rtt_ms: 32,
                     ip: "192.168.1.34", fp_short: "P3R7 · 9NQK", online: true },
        MockDevice { id: "jiawei", name: "Jiawei · iPad",    who: "嘉伟",   kind: DeviceKind::Ipad,
                     dist: 0.40, angle: 200.0, color: "#C7B8FF", initials: "JW",
                     os: "iPadOS", model: "iPad Pro 13", rtt_ms: 14,
                     ip: "192.168.1.47", fp_short: "T8XW · M3KL", online: true },
        MockDevice { id: "mengxi", name: "Meng Xi · iPhone", who: "孟茜",   kind: DeviceKind::Ios,
                     dist: 0.62, angle: 265.0, color: "#FFD970", initials: "MX",
                     os: "iOS",    model: "iPhone 16", rtt_ms: 26,
                     ip: "192.168.1.51", fp_short: "QA8N · KZ9R", online: true },
        MockDevice { id: "dev01",  name: "DEV-01 · Win 11",  who: "工位机", kind: DeviceKind::Win,
                     dist: 0.88, angle: 320.0, color: "#9AD0FF", initials: "D1",
                     os: "Win 11", model: "ThinkPad X1", rtt_ms: 41,
                     ip: "192.168.1.88", fp_short: "X3WF · L19Q", online: false },
    ]
}

// ─── 历史 ───
#[derive(Clone, Debug)]
pub enum HistoryKind {
    Image { count: u32 },
    File  { name: &'static str, size: &'static str, ext: &'static str, progress: Option<u32> },
    Text  { content: &'static str },
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Dir { In, Out }

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HistoryStatus { Done, Transferring, Queued, Failed }

#[derive(Clone, Debug)]
pub struct HistoryRow {
    pub id: &'static str,
    pub dir: Dir,
    pub peer: &'static str,
    pub time: &'static str,
    pub kind: HistoryKind,
    pub status: HistoryStatus,
}

pub fn history() -> Vec<HistoryRow> {
    vec![
        HistoryRow { id: "h6", dir: Dir::In,  peer: "孟茜", time: "14:18",
                     kind: HistoryKind::Image { count: 2 }, status: HistoryStatus::Done },
        HistoryRow { id: "h5", dir: Dir::Out, peer: "孟茜", time: "14:10",
                     kind: HistoryKind::File { name: "设计稿_v3_final.fig", size: "14.2 MB", ext: "fig", progress: None },
                     status: HistoryStatus::Done },
        HistoryRow { id: "h4", dir: Dir::Out, peer: "李莉", time: "14:09",
                     kind: HistoryKind::Text { content: "改完了，整理一下发你 👇" }, status: HistoryStatus::Done },
        HistoryRow { id: "h3", dir: Dir::Out, peer: "嘉伟", time: "14:08",
                     kind: HistoryKind::File { name: "iOS-mocks-final.zip", size: "48.6 MB", ext: "zip", progress: Some(67) },
                     status: HistoryStatus::Transferring },
        HistoryRow { id: "h2", dir: Dir::In,  peer: "坤",   time: "13:58",
                     kind: HistoryKind::File { name: "IMG_4821~38.heic", size: "128 MB", ext: "heic", progress: Some(12) },
                     status: HistoryStatus::Transferring },
        HistoryRow { id: "h1", dir: Dir::Out, peer: "李莉", time: "13:42",
                     kind: HistoryKind::File { name: "demo-video.mp4", size: "512 MB", ext: "mp4", progress: None },
                     status: HistoryStatus::Queued },
    ]
}

// ─── 配对 / file offer ───
#[derive(Clone, Debug)]
pub struct PendingPairing {
    pub id: &'static str,
    pub peer: &'static str,
    pub device_name: &'static str,
    pub fingerprint: &'static str,
    pub received_at: &'static str,
}
pub fn pending_pairing() -> PendingPairing {
    PendingPairing {
        id: "pp-1", peer: "李莉", device_name: "Lily's MacBook",
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF",
        received_at: "8s ago",
    }
}

#[derive(Clone, Debug)]
pub struct PendingFileOffer {
    pub id: &'static str,
    pub peer: &'static str,
    pub device_name: &'static str,
    pub file_name: &'static str,
    pub file_size: &'static str,
    pub note: Option<&'static str>,
    pub received_at: &'static str,
}
pub fn pending_offer() -> PendingFileOffer {
    PendingFileOffer {
        id: "po-1", peer: "嘉伟", device_name: "Jiawei · iPad",
        file_name: "规划文档_v0.3.pages",
        file_size: "3.4 MB",
        note: Some("改完了帮我看下第二章，特别是 §2.3 那段"),
        received_at: "just now",
    }
}

// ─── 剪贴板 ───
#[derive(Clone, Debug)]
pub enum ClipKind { Text, Link, Code { lang: &'static str } }

#[derive(Clone, Debug)]
pub struct ClipItem {
    pub id: &'static str,
    pub who: &'static str,
    pub kind: ClipKind,
    pub body: &'static str,
    pub ago: &'static str,
}
pub fn clipboard() -> Vec<ClipItem> {
    vec![
        ClipItem { id: "cb1", who: "嘉伟", kind: ClipKind::Link,
                   body: "https://internal.acme.io/specs/auth-v3", ago: "8s" },
        ClipItem { id: "cb2", who: "孟茜", kind: ClipKind::Text,
                   body: "1. 新流程要支持端到端\n2. 雷达扫描频率调到 2s\n3. iPad 端做横屏适配", ago: "12m" },
        ClipItem { id: "cb3", who: "李莉", kind: ClipKind::Code { lang: "sh" },
                   body: "docker run --rm -v $PWD:/app meshdrop/build:latest", ago: "34m" },
        ClipItem { id: "cb4", who: "坤",   kind: ClipKind::Text,
                   body: "会议室 B 已订到 16:00–17:30", ago: "1h" },
        ClipItem { id: "cb5", who: "我",   kind: ClipKind::Link,
                   body: "figma://file/Q8xK2/MeshDrop?node-id=42:108", ago: "2h" },
    ]
}

// ─── 传输 ───
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransferState { Done, Sending, Receiving, Queued, Failed }

impl TransferState {
    pub fn label_cn(self) -> &'static str {
        match self {
            TransferState::Done      => "已完成",
            TransferState::Sending   => "发送中",
            TransferState::Receiving => "接收中",
            TransferState::Queued    => "排队中",
            TransferState::Failed    => "失败",
        }
    }
    pub fn label_en(self) -> &'static str {
        match self {
            TransferState::Done      => "DONE",
            TransferState::Sending   => "SENDING",
            TransferState::Receiving => "RECEIVING",
            TransferState::Queued    => "QUEUED",
            TransferState::Failed    => "FAILED",
        }
    }
    pub fn css_class(self) -> &'static str {
        match self {
            TransferState::Done      => "done",
            TransferState::Sending   => "sending",
            TransferState::Receiving => "receiving",
            TransferState::Queued    => "queued",
            TransferState::Failed    => "failed",
        }
    }
    pub fn glyph(self) -> &'static str {
        match self {
            TransferState::Done      => "✓",
            TransferState::Sending   => "↑",
            TransferState::Receiving => "↓",
            TransferState::Queued    => "·",
            TransferState::Failed    => "×",
        }
    }
}

#[derive(Clone, Debug)]
pub struct TransferRow {
    pub name: &'static str,
    pub size: &'static str,
    pub ext: &'static str,
    pub from: &'static str,
    pub to: &'static str,
    pub progress: u32,
    pub state: TransferState,
    pub speed: Option<&'static str>,
    pub eta: Option<&'static str>,
}

pub fn transfers() -> Vec<TransferRow> {
    vec![
        TransferRow { name: "设计稿_v3_final.fig", size: "14.2 MB", ext: "fig",
                      from: "我", to: "孟茜", progress: 100, state: TransferState::Done,
                      speed: None, eta: Some("00:08") },
        TransferRow { name: "iOS-mocks-final.zip", size: "48.6 MB", ext: "zip",
                      from: "我", to: "孟茜", progress: 67, state: TransferState::Sending,
                      speed: Some("8.4 MB/s"), eta: Some("00:02") },
        TransferRow { name: "spec_PRD_2026Q1.pdf", size: "2.1 MB", ext: "pdf",
                      from: "我", to: "嘉伟", progress: 34, state: TransferState::Sending,
                      speed: Some("3.1 MB/s"), eta: Some("00:01") },
        TransferRow { name: "IMG_4821~IMG_4838.heic", size: "128 MB · 18 张", ext: "heic",
                      from: "坤", to: "我", progress: 12, state: TransferState::Receiving,
                      speed: Some("11.7 MB/s"), eta: Some("00:09") },
        TransferRow { name: "release-notes.md", size: "4.8 KB", ext: "md",
                      from: "我", to: "DEV-01", progress: 100, state: TransferState::Done,
                      speed: None, eta: Some("00:01") },
        TransferRow { name: "demo-video.mp4", size: "512 MB", ext: "mp4",
                      from: "我", to: "李莉", progress: 0, state: TransferState::Queued,
                      speed: None, eta: None },
    ]
}

// 速度图历史采样
pub const UPLOAD_BARS:   &[u32] = &[3,5,8,7,9,6,11,12,14,11,10,11,12,11];
pub const DOWNLOAD_BARS: &[u32] = &[8,9,7,6,5,7,10,12,11,12,11,12,11,12];
pub const SESSION_BARS:  &[u32] = &[2,3,5,4,6,8,7,9,10,12,11,12,11,12,14];

// ─── 本机 ───
pub struct MeInfo {
    pub name: &'static str,
    pub fingerprint: &'static str,  // 4-4-4-4 显示
    pub fingerprint_full: &'static str, // 8 组
    pub ip: &'static str,
    pub os: &'static str,
    pub visibility: &'static str,
}

pub fn me() -> MeInfo {
    MeInfo {
        name: "我的工作站 · welape-arch",
        fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2",
        fingerprint_full: "ZX8K · L72M · 9FQ3 · 7HD2 · M1P6 · QA8N · KZ9R · X3WF",
        ip: "192.168.1.42",
        os: "Arch Linux · 6.9",
        visibility: "可见",
    }
}

// ─── 信任记录 ───
#[derive(Clone, Debug)]
pub struct TrustEntry {
    pub who: &'static str,
    pub device_name: &'static str,
    pub fingerprint: &'static str,
    pub paired_at: &'static str,
    pub last_seen: &'static str,
}
pub fn trust() -> Vec<TrustEntry> {
    vec![
        TrustEntry { who: "李莉", device_name: "Lily's MacBook",
                     fingerprint: "ZX8K · L72M · 9FQ3 · 7HD2",
                     paired_at: "2026-04-12", last_seen: "刚刚 · just now" },
        TrustEntry { who: "孟茜", device_name: "Meng Xi · iPhone",
                     fingerprint: "QA8N · KZ9R · X3WF · L19Q",
                     paired_at: "2026-04-15", last_seen: "5 分钟前" },
        TrustEntry { who: "嘉伟", device_name: "Jiawei · iPad",
                     fingerprint: "T8XW · M3KL · 7HD2 · 9FQ3",
                     paired_at: "2026-04-20", last_seen: "今天 · 14:08" },
        TrustEntry { who: "工位机", device_name: "DEV-01 · Win 11",
                     fingerprint: "X3WF · L19Q · M1P6 · QA8N",
                     paired_at: "2026-05-02", last_seen: "昨天 · 18:42" },
    ]
}

// ─── 聊天消息（与某设备对话）───
#[derive(Clone, Debug)]
pub enum ChatBody {
    Text(&'static str),
    File { name: &'static str, size: &'static str, ext: &'static str },
    Image { caption: &'static str },
}

#[derive(Clone, Debug)]
pub struct ChatMsg {
    pub side: Dir,
    pub time: &'static str,
    pub body: ChatBody,
    pub delivered: bool,
}

pub fn chat_with_mengxi() -> Vec<ChatMsg> {
    vec![
        ChatMsg { side: Dir::In,  time: "14:02", body: ChatBody::Text("第二章看完了，整体节奏挺好"), delivered: true },
        ChatMsg { side: Dir::In,  time: "14:02", body: ChatBody::Text("有几处地方想跟你对一下，等下发给你"), delivered: true },
        ChatMsg { side: Dir::Out, time: "14:05", body: ChatBody::Text("好的，直接发文档过来就行"), delivered: true },
        ChatMsg { side: Dir::In,  time: "14:10",
                  body: ChatBody::File { name: "设计稿_v3_final.fig", size: "14.2 MB", ext: "fig" },
                  delivered: true },
        ChatMsg { side: Dir::Out, time: "14:12", body: ChatBody::Text("收到，我先看一遍，10 分钟后回你"), delivered: true },
        ChatMsg { side: Dir::In,  time: "14:18",
                  body: ChatBody::Image { caption: "顺便参考一下这两张" },
                  delivered: true },
    ]
}

// 当前选中对话目标
pub const CHAT_PEER_INDEX: usize = 3;   // mengxi

// 状态条文本
pub struct ShellStatus {
    pub mdns: &'static str,
    pub e2e: &'static str,
    pub clip: &'static str,
    pub trace: &'static str,
}
pub fn shell_status() -> ShellStatus {
    ShellStatus {
        mdns: "_meshdrop._tcp · 5 peers",
        e2e: "LAN · 明文 · v0.1",
        clip: "剪贴板同步 · 5 条",
        trace: "LAN · 192.168.1.0/24 · MTU 1500",
    }
}
