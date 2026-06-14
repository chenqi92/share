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

/// 连续失败到此次数即进入锁定窗口。
const MAX_FAILURES: u32 = 5;
/// 锁定时长：达到上限后，该时长内一律拒绝（含正确码），抑制暴力穷举。
const LOCKOUT: Duration = Duration::from_secs(60);

struct Throttle {
    failures: u32,
    locked_until: Option<Instant>,
}

pub struct PairingGate {
    code: Mutex<String>,
    sessions: Mutex<HashMap<String, Instant>>,
    throttle: Mutex<Throttle>,
}

impl PairingGate {
    pub fn new() -> Self {
        Self {
            code: Mutex::new(gen_code()),
            sessions: Mutex::new(HashMap::new()),
            throttle: Mutex::new(Throttle { failures: 0, locked_until: None }),
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

    /// 浏览器尝试鉴权。code 大小写不敏感，去空白与连字符（展示态含 `ABC-D23`）。
    /// 失败计数 + 锁定抑制穷举；比较用恒定时间避免计时侧信道；成功后 rotate 旧码。
    pub fn try_pair(&self, code: &str) -> Option<String> {
        {
            // 锁定窗口内一律拒绝（含正确码），到期自动复位。
            let mut t = self.throttle.lock().unwrap();
            if let Some(until) = t.locked_until {
                if Instant::now() < until {
                    return None;
                }
                t.locked_until = None;
                t.failures = 0;
            }
        }

        let normalized = normalize_code(code);
        // 期望码存储态含连字符（ABC-D23），比较前同样归一，使紧凑/连字符输入都可配对。
        let expected = normalize_code(&self.code.lock().unwrap());
        if constant_time_eq(normalized.as_bytes(), expected.as_bytes()) {
            // 成功：清失败计数，rotate 旧码使其一次性，下发新 session token。
            {
                let mut t = self.throttle.lock().unwrap();
                t.failures = 0;
                t.locked_until = None;
            }
            self.rotate_code();
            let token = Uuid::new_v4().simple().to_string();
            self.sessions.lock().unwrap().insert(token.clone(), Instant::now());
            Some(token)
        } else {
            let mut t = self.throttle.lock().unwrap();
            t.failures = t.failures.saturating_add(1);
            if t.failures >= MAX_FAILURES {
                t.locked_until = Some(Instant::now() + LOCKOUT);
            }
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

/// 归一化用户输入：去空白与连字符、大写。展示码 `ABC-D23` 与紧凑 `ABCD23` 均可配对。
fn normalize_code(code: &str) -> String {
    code.chars()
        .filter(|c| !c.is_whitespace() && *c != '-')
        .flat_map(char::to_uppercase)
        .collect()
}

/// 恒定时间字节比较：长度不同直接返回 false，但仍把已有字节走完异或，
/// 避免因长度差异提早返回造成的计时侧信道。
fn constant_time_eq(a: &[u8], b: &[u8]) -> bool {
    if a.len() != b.len() {
        return false;
    }
    let mut diff: u8 = 0;
    for (x, y) in a.iter().zip(b.iter()) {
        diff |= x ^ y;
    }
    diff == 0
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn try_pair_accepts_hyphenated_and_compact() {
        let gate = PairingGate::new();
        let code = gate.current_code(); // 形如 ABC-D23
        let compact: String = code.chars().filter(|c| *c != '-').collect();
        // 紧凑（无连字符）输入应能配对成功
        assert!(gate.try_pair(&compact).is_some());
    }

    #[test]
    fn try_pair_rotates_code_after_success() {
        let gate = PairingGate::new();
        let code = gate.current_code();
        assert!(gate.try_pair(&code).is_some());
        // 旧码配对后被 rotate，再次使用应失败
        assert!(gate.try_pair(&code).is_none());
    }

    #[test]
    fn try_pair_locks_out_after_repeated_failures() {
        let gate = PairingGate::new();
        for _ in 0..MAX_FAILURES {
            assert!(gate.try_pair("ZZZ-ZZZ").is_none());
        }
        // 锁定窗口内即使正确码也拒绝
        let code = gate.current_code();
        assert!(gate.try_pair(&code).is_none());
    }
}
