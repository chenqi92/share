use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrustRecord {
    pub fingerprint: String,
    pub name: String,
    pub last_seen_ms: i64,
}

/// 信任的设备指纹库（明文 JSON），骨架阶段简化；v1.0 切到 libsecret。
#[derive(Clone)]
pub struct TrustStore {
    inner: Arc<Mutex<TrustInner>>,
}

struct TrustInner {
    records: HashMap<String, TrustRecord>,
    path: PathBuf,
}

impl TrustStore {
    pub fn new() -> Result<Self> {
        // 统一到 <XDG_DATA_HOME>/MeshDrop（与 identity 同目录），并迁移旧的小写
        // meshdrop/trust.json，避免状态目录分裂导致清理 / 迁移遗漏。
        let dir = crate::paths::state_dir().context("no XDG data dir")?;
        fs::create_dir_all(&dir).context("create trust dir")?;
        let path = dir.join("trust.json");

        if !path.exists() {
            if let Some(legacy) = crate::paths::legacy_state_dir() {
                let legacy_path = legacy.join("trust.json");
                if legacy_path.exists() {
                    // rename 失败（跨设备等）则退化为复制，尽量不丢信任记录。
                    if fs::rename(&legacy_path, &path).is_err() {
                        let _ = fs::copy(&legacy_path, &path);
                    }
                }
            }
        }

        let records = if path.exists() {
            fs::read_to_string(&path).ok()
                .and_then(|s| serde_json::from_str::<HashMap<String, TrustRecord>>(&s).ok())
                .unwrap_or_default()
        } else {
            HashMap::new()
        };

        Ok(Self {
            inner: Arc::new(Mutex::new(TrustInner { records, path })),
        })
    }

    pub fn is_trusted(&self, fp: &str) -> bool {
        self.inner.lock().unwrap().records.contains_key(fp)
    }

    pub fn trust(&self, fp: &str, name: &str) {
        let mut guard = self.inner.lock().unwrap();
        let now = unix_ms();
        guard.records.insert(fp.to_string(), TrustRecord {
            fingerprint: fp.to_string(),
            name: name.to_string(),
            last_seen_ms: now,
        });
        let _ = persist(&guard);
    }

    pub fn touch(&self, fp: &str) {
        let mut guard = self.inner.lock().unwrap();
        if let Some(r) = guard.records.get_mut(fp) {
            r.last_seen_ms = unix_ms();
        }
        let _ = persist(&guard);
    }

    pub fn revoke(&self, fp: &str) {
        let mut guard = self.inner.lock().unwrap();
        guard.records.remove(fp);
        let _ = persist(&guard);
    }

    pub fn snapshot(&self) -> Vec<TrustRecord> {
        let guard = self.inner.lock().unwrap();
        let mut v: Vec<_> = guard.records.values().cloned().collect();
        v.sort_by_key(|r| -r.last_seen_ms);
        v
    }
}

fn persist(inner: &TrustInner) -> Result<()> {
    let s = serde_json::to_string(&inner.records)?;
    fs::write(&inner.path, s)?;
    Ok(())
}

fn unix_ms() -> i64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now().duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64).unwrap_or(0)
}
