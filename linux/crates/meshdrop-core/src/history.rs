use serde::{Deserialize, Serialize};
use std::path::PathBuf;
use uuid::Uuid;

use crate::device::{Device, DeviceOS};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
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

// ─── 持久化（history.json）────────────────────────────────────────────
//
// 镜像 trust.rs / resume.rs：Codable/JSON 落 <XDG_DATA_HOME>/MeshDrop/history.json，
// 引擎启动 load、历史变更 save（整表覆盖写）。为了序列化把对端 Device 拍成
// `{fp,name,os}` 快照——对端可能已离线，历史展示用快照即可，不必保留完整 Device。

/// 历史条目数上限。超出截断最旧，防文件无限增长。
pub const HISTORY_LIMIT: usize = 500;

/// 对端设备快照——历史落盘只需指纹 / 名字 / 系统三项即可还原展示。
#[derive(Debug, Clone, Serialize, Deserialize)]
struct PeerSnapshot {
    fp: String,
    name: String,
    os: String,
}

impl PeerSnapshot {
    fn from_device(d: &Device) -> Self {
        Self {
            fp: d.fingerprint.clone(),
            name: d.name.clone(),
            os: d.os.as_str().to_string(),
        }
    }

    /// 还原成展示用 Device。port / host 等运行期字段对历史无意义，置默认。
    fn to_device(&self) -> Device {
        Device {
            id: self.fp.clone(),
            name: self.name.clone(),
            os: DeviceOS::parse(&self.os).unwrap_or(DeviceOS::Linux),
            model: None,
            fingerprint: self.fp.clone(),
            port: 0,
            protocol_version: 1,
            host: None,
        }
    }
}

/// 落盘用的 kind 快照。文件态只存名字 / 大小（路径对端离线后无意义，仅在
/// retry 仍可用时引擎自会重新派生；这里保留 path 便于发送项重发）。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
enum KindRecord {
    Text { content: String },
    File { name: String, size: u64, path: Option<PathBuf> },
}

impl KindRecord {
    fn from_kind(k: &HistoryKind) -> Self {
        match k {
            HistoryKind::Text(s) => KindRecord::Text { content: s.clone() },
            HistoryKind::File { name, size, path } => KindRecord::File {
                name: name.clone(),
                size: *size,
                path: path.clone(),
            },
        }
    }

    fn to_kind(&self) -> HistoryKind {
        match self {
            KindRecord::Text { content } => HistoryKind::Text(content.clone()),
            KindRecord::File { name, size, path } => HistoryKind::File {
                name: name.clone(),
                size: *size,
                path: path.clone(),
            },
        }
    }
}

/// 落盘用的状态快照。进行中的临时态（Pending / WaitingApproval / Transferring）
/// 在重启后已无对应连接，统一持久化为 Failed("中断")，避免把临时态写死成完成。
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "type")]
enum StatusRecord {
    Pending,
    WaitingApproval,
    Transferring { done: u64, total: u64 },
    Completed,
    Failed { reason: String },
    Canceled,
}

impl StatusRecord {
    fn from_status(s: &TransferStatus) -> Self {
        match s {
            TransferStatus::Pending => StatusRecord::Pending,
            TransferStatus::WaitingApproval => StatusRecord::WaitingApproval,
            TransferStatus::Transferring { done, total } => {
                StatusRecord::Transferring { done: *done, total: *total }
            }
            TransferStatus::Completed => StatusRecord::Completed,
            TransferStatus::Failed(reason) => StatusRecord::Failed { reason: reason.clone() },
            TransferStatus::Canceled => StatusRecord::Canceled,
        }
    }

    /// 还原成运行期状态。非终态（重启后无连接可续）统一落成 Failed，
    /// 不把临时态当成完成。
    fn to_status(&self) -> TransferStatus {
        match self {
            StatusRecord::Pending
            | StatusRecord::WaitingApproval
            | StatusRecord::Transferring { .. } => {
                TransferStatus::Failed("中断 · 重启前未完成".into())
            }
            StatusRecord::Completed => TransferStatus::Completed,
            StatusRecord::Failed { reason } => TransferStatus::Failed(reason.clone()),
            StatusRecord::Canceled => TransferStatus::Canceled,
        }
    }
}

/// history.json 里的单条记录。
#[derive(Debug, Clone, Serialize, Deserialize)]
struct HistoryRecord {
    id: Uuid,
    peer: PeerSnapshot,
    direction: TransferDirection,
    kind: KindRecord,
    status: StatusRecord,
    created_at_ms: i64,
}

impl HistoryRecord {
    fn from_item(item: &HistoryItem) -> Self {
        Self {
            id: item.id,
            peer: PeerSnapshot::from_device(&item.peer),
            direction: item.direction,
            kind: KindRecord::from_kind(&item.kind),
            status: StatusRecord::from_status(&item.status),
            created_at_ms: item.created_at.unix_ms,
        }
    }

    fn to_item(&self) -> HistoryItem {
        HistoryItem {
            id: self.id,
            peer: self.peer.to_device(),
            direction: self.direction,
            kind: self.kind.to_kind(),
            status: self.status.to_status(),
            created_at: chrono_compat::SimpleTime { unix_ms: self.created_at_ms },
        }
    }
}

/// 明文 JSON 的发送 / 接收历史。镜像 ResumeStore：启动 load、变更 save（整表覆盖）。
#[derive(Debug, Clone)]
pub struct HistoryStore {
    path: PathBuf,
}

impl HistoryStore {
    /// 默认路径：<XDG_DATA_HOME>/MeshDrop/history.json（与 trust / identity 同目录）。
    pub fn new() -> Self {
        Self::at(default_store_path())
    }

    pub fn at(path: PathBuf) -> Self {
        Self { path }
    }

    /// 启动时 load 进内存历史列表。文件缺失 / 损坏返回空表（不致命）。
    /// 列表最新在前，与引擎内存 history（insert(0, ..)）一致。
    pub fn load(&self) -> Vec<HistoryItem> {
        let Ok(data) = std::fs::read(&self.path) else {
            return Vec::new();
        };
        let records: Vec<HistoryRecord> = serde_json::from_slice(&data).unwrap_or_default();
        records.iter().map(HistoryRecord::to_item).collect()
    }

    /// 整表覆盖写。落盘前截断到 HISTORY_LIMIT（保留最新者，最旧被丢弃）。
    /// 用临时文件 + rename 原子替换，避免写一半崩溃留下半截 JSON。
    pub fn save(&self, items: &[HistoryItem]) -> std::io::Result<()> {
        if let Some(dir) = self.path.parent() {
            std::fs::create_dir_all(dir)?;
        }
        let take = items.len().min(HISTORY_LIMIT);
        let records: Vec<HistoryRecord> =
            items[..take].iter().map(HistoryRecord::from_item).collect();
        let data = serde_json::to_vec_pretty(&records)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        let tmp = self.path.with_extension("json.tmp");
        std::fs::write(&tmp, data)?;
        std::fs::rename(tmp, &self.path)?;
        Ok(())
    }
}

impl Default for HistoryStore {
    fn default() -> Self {
        Self::new()
    }
}

fn default_store_path() -> PathBuf {
    let base = dirs::data_local_dir()
        .or_else(dirs::home_dir)
        .unwrap_or_else(std::env::temp_dir);
    base.join("MeshDrop").join("history.json")
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    fn temp_store_path() -> PathBuf {
        std::env::temp_dir()
            .join(format!("meshdrop-history-test-{}", Uuid::new_v4()))
            .join("history.json")
    }

    fn sample_peer() -> Device {
        Device {
            id: "abc".into(),
            name: "Alice".into(),
            os: DeviceOS::Macos,
            model: Some("MacBook".into()),
            fingerprint: "ff00".into(),
            port: 1234,
            protocol_version: 1,
            host: Some("10.0.0.2".into()),
        }
    }

    #[test]
    fn save_then_load_roundtrips_text_and_file() {
        let path = temp_store_path();
        let store = HistoryStore::at(path.clone());

        let text = HistoryItem::new(
            sample_peer(),
            TransferDirection::Incoming,
            HistoryKind::Text("hi".into()),
            TransferStatus::Completed,
        );
        let file = HistoryItem::new(
            sample_peer(),
            TransferDirection::Outgoing,
            HistoryKind::File { name: "a.bin".into(), size: 42, path: None },
            TransferStatus::Completed,
        );
        let items = vec![text.clone(), file.clone()];
        store.save(&items).unwrap();

        let loaded = store.load();
        assert_eq!(loaded.len(), 2);
        assert_eq!(loaded[0].id, text.id);
        assert_eq!(loaded[0].peer.fingerprint, "ff00");
        assert_eq!(loaded[0].peer.name, "Alice");
        assert_eq!(loaded[0].peer.os, DeviceOS::Macos);
        assert!(matches!(loaded[0].kind, HistoryKind::Text(_)));
        assert!(matches!(loaded[1].kind, HistoryKind::File { size: 42, .. }));

        let _ = std::fs::remove_dir_all(path.parent().unwrap());
    }

    #[test]
    fn in_progress_status_persists_as_failed() {
        let path = temp_store_path();
        let store = HistoryStore::at(path.clone());
        let item = HistoryItem::new(
            sample_peer(),
            TransferDirection::Incoming,
            HistoryKind::File { name: "x".into(), size: 10, path: None },
            TransferStatus::Transferring { done: 3, total: 10 },
        );
        store.save(&[item]).unwrap();
        let loaded = store.load();
        assert_eq!(loaded.len(), 1);
        assert!(matches!(loaded[0].status, TransferStatus::Failed(_)));
        let _ = std::fs::remove_dir_all(path.parent().unwrap());
    }

    #[test]
    fn save_truncates_to_limit_keeping_newest() {
        let path = temp_store_path();
        let store = HistoryStore::at(path.clone());
        // 构造 HISTORY_LIMIT + 5 条，最新在前（index 0）。
        let mut items = Vec::new();
        for i in 0..(HISTORY_LIMIT + 5) {
            items.push(HistoryItem::new(
                sample_peer(),
                TransferDirection::Incoming,
                HistoryKind::Text(format!("msg-{i}")),
                TransferStatus::Completed,
            ));
        }
        let newest_id = items[0].id;
        store.save(&items).unwrap();
        let loaded = store.load();
        assert_eq!(loaded.len(), HISTORY_LIMIT);
        assert_eq!(loaded[0].id, newest_id);
        let _ = std::fs::remove_dir_all(path.parent().unwrap());
    }

    #[test]
    fn load_missing_file_is_empty() {
        let store = HistoryStore::at(temp_store_path());
        assert!(store.load().is_empty());
    }
}
