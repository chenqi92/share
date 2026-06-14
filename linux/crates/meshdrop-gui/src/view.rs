//! 把 meshdrop_core 类型映射到 UI 渲染需要的"展示型"结构。
//! mock.rs 的 MockDevice 用 `&'static str` 字段，无法承载动态数据；
//! 此模块定义 String 版本的 ViewDevice / ViewHistory / ViewTrust，
//! 并提供从 `core::Device` / `HistoryItem` / `TrustRecord` 的转换。

use crate::mock;
use meshdrop_core::history::{format_bytes, HistoryItem, HistoryKind, TransferDirection, TransferStatus};
use meshdrop_core::trust::TrustRecord;
use meshdrop_core::Device;
use meshdrop_core::DeviceOS;
use meshdrop_core::TransferMetrics;

/// Radar / 列表行需要的全部展示字段（String 版）。
#[allow(dead_code)]
#[derive(Clone, Debug)]
pub struct ViewDevice {
    pub id: String,
    pub name: String,
    pub who: String,        // 简化的显示名（用于 radar 标签）
    pub kind: mock::DeviceKind,
    pub dist: f64,
    pub angle: f64,
    pub color: String,
    pub initials: String,
    pub os: String,
    pub model: String,
    pub rtt_ms: u32,
    pub ip: String,
    pub fp_short: String,
    /// 设备当前是否在线（在线点用 lime_deep，离线用灰）。
    pub online: bool,
}

impl ViewDevice {
    pub fn from_mock(m: &mock::MockDevice) -> Self {
        Self {
            id: m.id.to_string(), name: m.name.to_string(), who: m.who.to_string(),
            kind: m.kind, dist: m.dist, angle: m.angle,
            color: m.color.to_string(), initials: m.initials.to_string(),
            os: m.os.to_string(), model: m.model.to_string(),
            rtt_ms: m.rtt_ms, ip: m.ip.to_string(), fp_short: m.fp_short.to_string(),
            online: m.online,
        }
    }

    /// 从真实 LAN 设备生成展示数据。`index` 用来分散 angle/dist 与 color。
    pub fn from_device(d: &Device, index: usize) -> Self {
        let kind = match d.os {
            DeviceOS::Macos => mock::DeviceKind::Mac,
            DeviceOS::Windows => mock::DeviceKind::Win,
            DeviceOS::Linux => mock::DeviceKind::Linux,
            DeviceOS::Ios => mock::DeviceKind::Ios,
            DeviceOS::Android => mock::DeviceKind::Android,
        };
        let initials = initials_of(&d.name);
        let color = palette_color(index);
        let host = d.host.clone().unwrap_or_default();
        let angle = ((index as f64) * 67.0 + 20.0) % 360.0;
        let dist = 0.40 + ((index % 5) as f64) * 0.12;
        let fp_short = short_fingerprint(&d.fingerprint);
        Self {
            id: d.id.clone(),
            name: d.name.clone(),
            who: d.name.clone(),
            kind, angle, dist,
            color: color.to_string(),
            initials,
            os: kind.os_label().to_string(),
            model: d.model.clone().unwrap_or_default(),
            rtt_ms: 0,
            ip: host,
            fp_short,
            // 出现在 mDNS 发现列表里的真实设备即视为当前在线。
            online: true,
        }
    }
}

#[derive(Clone, Debug)]
pub enum ViewHistoryKind {
    Text(String),
    File { name: String, size: String, ext: String, progress: Option<u32> },
}

#[allow(dead_code)]
#[derive(Clone, Debug)]
pub struct ViewHistoryRow {
    pub id: String,
    pub dir: mock::Dir,
    pub peer: String,
    pub time: String,
    pub kind: ViewHistoryKind,
    pub status: mock::HistoryStatus,
}

impl ViewHistoryRow {
    pub fn from_item(h: &HistoryItem) -> Self {
        let dir = match h.direction {
            TransferDirection::Incoming => mock::Dir::In,
            TransferDirection::Outgoing => mock::Dir::Out,
        };
        let (kind_view, status) = match &h.kind {
            HistoryKind::Text(t) => (
                ViewHistoryKind::Text(t.clone()),
                history_status(&h.status),
            ),
            HistoryKind::File { name, size, .. } => {
                let ext = name.rsplit_once('.').map(|(_, e)| e).unwrap_or("file").to_string();
                let progress = match &h.status {
                    TransferStatus::Transferring { done, total } if *total > 0 => {
                        Some(((*done as f64 / *total as f64) * 100.0) as u32)
                    }
                    _ => None,
                };
                (
                    ViewHistoryKind::File {
                        name: name.clone(), size: format_bytes(*size),
                        ext, progress,
                    },
                    history_status(&h.status),
                )
            }
        };
        Self {
            id: h.id.to_string(),
            dir,
            peer: h.peer.name.clone(),
            time: format_time(h.created_at.unix_ms),
            kind: kind_view,
            status,
        }
    }
}

fn history_status(s: &TransferStatus) -> mock::HistoryStatus {
    match s {
        TransferStatus::Completed => mock::HistoryStatus::Done,
        TransferStatus::Failed(_) | TransferStatus::Canceled => mock::HistoryStatus::Failed,
        TransferStatus::Pending | TransferStatus::WaitingApproval => mock::HistoryStatus::Queued,
        TransferStatus::Transferring { .. } => mock::HistoryStatus::Transferring,
    }
}

#[derive(Clone, Debug)]
pub struct ViewTrustEntry {
    pub who: String,
    pub device_name: String,
    /// 展示用：前 4 组、4 字符分隔大写（take(16)）。
    pub fingerprint: String,
    /// 撤销用：完整 32 位小写 hex（trust store 的 key），不可截断。
    pub fingerprint_full: String,
    pub paired_at: String,
    pub last_seen: String,
}

impl ViewTrustEntry {
    pub fn from_record(r: &TrustRecord) -> Self {
        Self {
            who: r.name.clone(),
            device_name: r.name.clone(),
            fingerprint: short_fingerprint(&r.fingerprint),
            fingerprint_full: r.fingerprint.clone(),
            // TrustRecord 目前只持有 last_seen_ms（配对时刻 == 最近在线，二者同源），
            // 真正的 paired_at 字段待 core 扩展；此处显示真实日期而非占位 D-{epoch}。
            paired_at: format_date(r.last_seen_ms / 1000),
            last_seen: format_relative(r.last_seen_ms / 1000),
        }
    }
}

#[derive(Clone, Debug)]
pub struct ViewTransferRow {
    pub id: uuid::Uuid,
    pub name: String,
    pub size: String,
    pub ext: String,
    pub from: String,
    pub to: String,
    pub progress: u32,
    pub state: mock::TransferState,
    pub speed: Option<String>,
    pub eta: Option<String>,
    /// 已完成接收项的本地落盘路径 —— TransferRow 据此渲染 Open / Reveal 按钮。
    pub saved_path: Option<std::path::PathBuf>,
    /// 失败原因（校验失败 / 连接中断 / 对方拒收 …），仅 state == Failed 时有值。
    pub fail_reason: Option<String>,
}

impl ViewTransferRow {
    pub fn from_history_with_metrics(
        h: &HistoryItem,
        self_name: &str,
        metrics: Option<&TransferMetrics>,
    ) -> Option<Self> {
        let (name, size_str, ext, saved_path) = match &h.kind {
            HistoryKind::File { name, size, path } => {
                let ext = name.rsplit_once('.').map(|(_, e)| e).unwrap_or("file").to_string();
                let saved = match h.direction {
                    TransferDirection::Incoming => path.clone(),
                    TransferDirection::Outgoing => None,
                };
                (name.clone(), format_bytes(*size), ext, saved)
            }
            HistoryKind::Text(t) => (
                t!("transfers.text_note", preview = truncate(t, 24)).to_string(),
                format!("{} B", t.len()),
                "txt".to_string(),
                None,
            ),
        };
        let (from, to) = match h.direction {
            TransferDirection::Outgoing => (self_name.to_string(), h.peer.name.clone()),
            TransferDirection::Incoming => (h.peer.name.clone(), self_name.to_string()),
        };
        let progress = ((h.status.fraction()) * 100.0) as u32;
        let state = match &h.status {
            TransferStatus::Completed => mock::TransferState::Done,
            TransferStatus::Failed(_) | TransferStatus::Canceled => mock::TransferState::Failed,
            TransferStatus::Pending | TransferStatus::WaitingApproval => mock::TransferState::Queued,
            TransferStatus::Transferring { .. } => match h.direction {
                TransferDirection::Outgoing => mock::TransferState::Sending,
                TransferDirection::Incoming => mock::TransferState::Receiving,
            },
        };
        let active = matches!(state, mock::TransferState::Sending | mock::TransferState::Receiving);
        let speed = if active {
            metrics.and_then(|m| if m.bytes_per_sec > 1.0 { Some(format_speed(m.bytes_per_sec)) } else { None })
        } else {
            None
        };
        let eta = if active {
            metrics.and_then(|m| m.eta_seconds).map(format_eta)
        } else {
            None
        };
        let fail_reason = match &h.status {
            TransferStatus::Failed(reason) => Some(reason.clone()),
            TransferStatus::Canceled => Some(t!("transfers.canceled").to_string()),
            _ => None,
        };
        Some(Self {
            id: h.id, name, size: size_str, ext, from, to, progress, state,
            speed, eta,
            saved_path: if matches!(state, mock::TransferState::Done) { saved_path } else { None },
            fail_reason,
        })
    }
}

fn format_speed(bps: f64) -> String {
    if bps < 1024.0 { format!("{:.0} B/s", bps) }
    else if bps < 1024.0 * 1024.0 { format!("{:.1} KB/s", bps / 1024.0) }
    else { format!("{:.1} MB/s", bps / 1024.0 / 1024.0) }
}

fn format_eta(secs: f64) -> String {
    if !secs.is_finite() || secs < 0.0 { return "—".into() }
    if secs < 1.0 { return "<1s".into() }
    if secs >= 3600.0 { return ">1h".into() }
    let s = secs as u32;
    format!("{:02}:{:02}", s / 60, s % 60)
}

// ─── 工具 ──────────────────────────────────────────────────────────

pub fn short_fingerprint(fp: &str) -> String {
    let upper = fp.to_uppercase();
    let chars: Vec<char> = upper.chars().take(16).collect();
    chars.chunks(4)
        .map(|c| c.iter().collect::<String>())
        .collect::<Vec<_>>()
        .join(" · ")
}

pub fn initials_of(name: &str) -> String {
    let trimmed = name.trim();
    if trimmed.is_empty() { return "·".to_string(); }
    let first = trimmed.chars().next().unwrap();
    if first.is_ascii_alphabetic() {
        // 取前两个字母大写
        trimmed.chars().filter(|c| c.is_ascii_alphabetic()).take(2)
            .collect::<String>().to_uppercase()
    } else {
        first.to_string()
    }
}

const PALETTE: &[&str] = &[
    "#FFB4A1", "#B7E5C8", "#C7B8FF", "#FFD970", "#9AD0FF",
    "#F8B5D6", "#DDF94B", "#FFA66B", "#9DEEC9", "#E0B0FF",
];

pub fn palette_color(idx: usize) -> &'static str {
    PALETTE[idx % PALETTE.len()]
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max { s.to_string() }
    else { s.chars().take(max).collect::<String>() + "…" }
}

fn format_time(unix_ms: i64) -> String {
    let secs = (unix_ms / 1000) % 86400;
    let h = ((secs / 3600) + 8) % 24;        // 默认 UTC+8（CLAUDE.md 指定 Asia/Shanghai）
    let m = (secs / 60) % 60;
    format!("{:02}:{:02}", h, m)
}

fn format_date(unix_secs: i64) -> String {
    // 不引入 chrono：用 Howard Hinnant 的 civil-from-days 算法把 epoch 天数转 YYYY-MM-DD。
    let days = unix_secs.div_euclid(86400);
    let (y, m, d) = civil_from_days(days);
    format!("{:04}-{:02}-{:02}", y, m, d)
}

/// days = 自 1970-01-01 起的天数（可负）。返回 (year, month, day)。
/// 取自 Howard Hinnant 的 `civil_from_days`（公有领域算法）。
fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097; // [0, 146096]
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365; // [0, 399]
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100); // [0, 365]
    let mp = (5 * doy + 2) / 153; // [0, 11]
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32; // [1, 31]
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32; // [1, 12]
    (if m <= 2 { y + 1 } else { y }, m, d)
}

fn format_relative(unix_secs: i64) -> String {
    let now = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64).unwrap_or(0);
    let diff = (now - unix_secs).max(0);
    if diff < 60 { t!("time.just_now").to_string() }
    else if diff < 3600 { t!("time.minutes_ago", n = diff / 60).to_string() }
    else if diff < 86400 { t!("time.hours_ago", n = diff / 3600).to_string() }
    else { t!("time.days_ago", n = diff / 86400).to_string() }
}
