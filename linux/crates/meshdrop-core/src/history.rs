use std::path::PathBuf;
use uuid::Uuid;

use crate::device::Device;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransferDirection {
    Outgoing,
    Incoming,
}

#[derive(Debug, Clone)]
pub enum HistoryKind {
    Text(String),
    File {
        name: String,
        size: u64,
        path: Option<PathBuf>,
    },
}

#[derive(Debug, Clone)]
pub enum TransferStatus {
    Pending,
    WaitingApproval,
    Transferring { done: u64, total: u64 },
    Completed,
    Failed(String),
    Canceled,
}

impl TransferStatus {
    pub fn fraction(&self) -> f64 {
        match self {
            TransferStatus::Transferring { done, total } if *total > 0 => {
                (*done as f64 / *total as f64).min(1.0)
            }
            TransferStatus::Completed => 1.0,
            _ => 0.0,
        }
    }

    pub fn is_terminal(&self) -> bool {
        matches!(self, Self::Completed | Self::Failed(_) | Self::Canceled)
    }
}

#[derive(Debug, Clone)]
pub struct HistoryItem {
    pub id: Uuid,
    pub peer: Device,
    pub direction: TransferDirection,
    pub kind: HistoryKind,
    pub status: TransferStatus,
    pub created_at: chrono_compat::SimpleTime,
}

impl HistoryItem {
    pub fn new(
        peer: Device,
        direction: TransferDirection,
        kind: HistoryKind,
        status: TransferStatus,
    ) -> Self {
        Self {
            id: Uuid::new_v4(),
            peer,
            direction,
            kind,
            status,
            created_at: chrono_compat::now(),
        }
    }
}

/// 简易时间戳（不引入 chrono 依赖，避免增加 crate 大小）。
pub mod chrono_compat {
    use std::time::{SystemTime, UNIX_EPOCH};

    #[derive(Debug, Clone, Copy)]
    pub struct SimpleTime {
        pub unix_ms: i64,
    }

    impl SimpleTime {
        /// 格式化为 HH:MM:SS（本地时区，简化为 UTC offset 0；TUI/GUI 可自己加偏移）
        pub fn hh_mm_ss(&self) -> String {
            let secs = (self.unix_ms / 1000) % 86400;
            let h = (secs / 3600) % 24;
            let m = (secs / 60) % 60;
            let s = secs % 60;
            format!("{:02}:{:02}:{:02}", h, m, s)
        }
    }

    pub fn now() -> SimpleTime {
        let unix_ms = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_millis() as i64)
            .unwrap_or(0);
        SimpleTime { unix_ms }
    }
}

pub fn format_bytes(n: u64) -> String {
    if n < 1024 { return format!("{} B", n); }
    let kb = n as f64 / 1024.0;
    if kb < 1024.0 { return format!("{:.1} KB", kb); }
    let mb = kb / 1024.0;
    if mb < 1024.0 { return format!("{:.1} MB", mb); }
    let gb = mb / 1024.0;
    format!("{:.2} GB", gb)
}
