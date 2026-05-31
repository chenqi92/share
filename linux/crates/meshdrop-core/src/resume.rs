use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::io;
use std::path::PathBuf;

/// 接收侧中断传输进度。
///
/// Key 使用 `(peer_fingerprint, sha256)`，不依赖 transfer_id。这样发送端
/// 重新发起同一个文件、生成新 transfer_id 时，接收端仍能找到半成品继续写。
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ResumeRecord {
    pub peer_fingerprint: String,
    pub transfer_id: String,
    pub file_name: String,
    pub file_size: u64,
    pub sha256: String,
    pub saved_path: PathBuf,
    pub bytes_done: u64,
    pub updated_at_ms: u64,
}

impl ResumeRecord {
    pub fn make_key(peer_fingerprint: &str, sha256: &str) -> String {
        format!("{}:{}", peer_fingerprint, sha256)
    }

    pub fn key(&self) -> String {
        Self::make_key(&self.peer_fingerprint, &self.sha256)
    }
}

/// 明文 JSON 的本地断点续传索引。
///
/// 记录只保存接收端已经落盘的半成品文件路径与字节数；完成、校验失败或用户
/// 明确取消时由调用方清理。连接异常关闭时保留，等待下次 FILE_OFFER 命中。
#[derive(Debug, Clone)]
pub struct ResumeStore {
    path: PathBuf,
    records: HashMap<String, ResumeRecord>,
}

impl ResumeStore {
    pub fn new() -> Self {
        Self::at(default_store_path())
    }

    pub fn at(path: PathBuf) -> Self {
        let records = load(&path);
        Self { path, records }
    }

    pub fn find(&self, peer_fingerprint: &str, sha256: &str) -> Option<ResumeRecord> {
        self.records
            .get(&ResumeRecord::make_key(peer_fingerprint, sha256))
            .cloned()
    }

    pub fn upsert(&mut self, record: ResumeRecord) -> io::Result<()> {
        self.records.insert(record.key(), record);
        self.persist()
    }

    pub fn clear(&mut self, peer_fingerprint: &str, sha256: &str) -> io::Result<()> {
        self.records
            .remove(&ResumeRecord::make_key(peer_fingerprint, sha256));
        self.persist()
    }

    #[allow(dead_code)]
    pub fn snapshot(&self) -> Vec<ResumeRecord> {
        self.records.values().cloned().collect()
    }

    fn persist(&self) -> io::Result<()> {
        if let Some(dir) = self.path.parent() {
            std::fs::create_dir_all(dir)?;
        }
        let data = serde_json::to_vec_pretty(&self.records)
            .map_err(|e| io::Error::new(io::ErrorKind::InvalidData, e))?;
        let tmp = self.path.with_extension("json.tmp");
        std::fs::write(&tmp, data)?;
        std::fs::rename(tmp, &self.path)?;
        Ok(())
    }
}

fn load(path: &PathBuf) -> HashMap<String, ResumeRecord> {
    let Ok(data) = std::fs::read(path) else {
        return HashMap::new();
    };
    serde_json::from_slice(&data).unwrap_or_default()
}

fn default_store_path() -> PathBuf {
    let base = dirs::data_local_dir()
        .or_else(dirs::home_dir)
        .unwrap_or_else(std::env::temp_dir);
    base.join("MeshDrop").join("resume.json")
}

#[cfg(test)]
mod tests {
    use super::*;
    use uuid::Uuid;

    fn temp_store_path() -> PathBuf {
        std::env::temp_dir()
            .join(format!("meshdrop-resume-test-{}", Uuid::new_v4()))
            .join("resume.json")
    }

    fn sample_record(path: PathBuf) -> ResumeRecord {
        ResumeRecord {
            peer_fingerprint: "FP123".into(),
            transfer_id: Uuid::new_v4().to_string(),
            file_name: "photo.jpg".into(),
            file_size: 1_000,
            sha256: "ABC".into(),
            saved_path: path,
            bytes_done: 512,
            updated_at_ms: 1_700_000_000_000,
        }
    }

    #[test]
    fn key_is_peer_fingerprint_and_sha256() {
        assert_eq!(ResumeRecord::make_key("FP123", "ABC"), "FP123:ABC");
    }

    #[test]
    fn upsert_persists_and_reload_finds_record() {
        let store_path = temp_store_path();
        let saved_path = store_path.with_file_name("partial.bin");
        let record = sample_record(saved_path);

        let mut store = ResumeStore::at(store_path.clone());
        store.upsert(record.clone()).unwrap();

        let reloaded = ResumeStore::at(store_path.clone());
        assert_eq!(reloaded.find("FP123", "ABC"), Some(record));

        let _ = std::fs::remove_dir_all(store_path.parent().unwrap());
    }

    #[test]
    fn clear_removes_record() {
        let store_path = temp_store_path();
        let mut store = ResumeStore::at(store_path.clone());
        store
            .upsert(sample_record(store_path.with_file_name("partial.bin")))
            .unwrap();

        store.clear("FP123", "ABC").unwrap();

        assert!(store.find("FP123", "ABC").is_none());
        let _ = std::fs::remove_dir_all(store_path.parent().unwrap());
    }
}
