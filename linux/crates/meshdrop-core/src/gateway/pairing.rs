//! 浏览器接入网关的鉴权状态：
//!   - 6 字符邀请码（启动时生成，在 GUI Settings 里显示）
//!   - 浏览器输入正确码后下发 session token，24h 过期。

use rand::RngExt;
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};
use uuid::Uuid;

const SESSION_TTL: Duration = Duration::from_secs(60 * 60 * 24);
const CODE_CHARSET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // 去掉易混淆字符

pub struct PairingGate {
    code: Mutex<String>,
    sessions: Mutex<HashMap<String, Instant>>,
}

impl PairingGate {
    pub fn new() -> Self {
        Self {
            code: Mutex::new(gen_code()),
            sessions: Mutex::new(HashMap::new()),
        }
    }

    pub fn current_code(&self) -> String {
        self.code.lock().unwrap().clone()
    }

    pub fn rotate_code(&self) -> String {
        let mut g = self.code.lock().unwrap();
        *g = gen_code();
        g.clone()
    }

    /// 浏览器尝试鉴权。code 大小写不敏感，去空白。
    pub fn try_pair(&self, code: &str) -> Option<String> {
        let normalized: String = code.chars().filter(|c| !c.is_whitespace())
            .flat_map(char::to_uppercase).collect();
        let expected = self.code.lock().unwrap().clone();
        if normalized == expected {
            let token = Uuid::new_v4().simple().to_string();
            self.sessions.lock().unwrap().insert(token.clone(), Instant::now());
            Some(token)
        } else {
            None
        }
    }

    /// 校验 session 是否仍然有效。过期自动清。
    pub fn is_valid_session(&self, token: &str) -> bool {
        let mut sessions = self.sessions.lock().unwrap();
        sessions.retain(|_, ts| ts.elapsed() < SESSION_TTL);
        sessions.contains_key(token)
    }

    pub fn revoke(&self, token: &str) {
        self.sessions.lock().unwrap().remove(token);
    }
}

impl Default for PairingGate {
    fn default() -> Self { Self::new() }
}

fn gen_code() -> String {
    let mut rng = rand::rng();
    // 格式 ABC-D23（带连字符，易读）
    let part = |n: usize, rng: &mut rand::rngs::ThreadRng| -> String {
        (0..n).map(|_| CODE_CHARSET[rng.random_range(0..CODE_CHARSET.len())] as char).collect()
    };
    format!("{}-{}", part(3, &mut rng), part(3, &mut rng))
}
