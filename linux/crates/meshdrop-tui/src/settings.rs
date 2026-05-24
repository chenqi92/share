//! 内存版 settings。`:set k=v` 落到这里；下一轮接 backend 时再做持久化。

use crate::ui::widgets::radar::Variant;
use std::path::PathBuf;

#[derive(Clone, Debug)]
pub struct Settings {
    pub display_name: String,
    pub save_dir: PathBuf,
    pub auto_accept_trusted: bool,
    pub radar: Variant,
}

impl Default for Settings {
    fn default() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
        let save = PathBuf::from(home).join("Downloads/meshdrop");
        Self {
            display_name: String::new(), // 启动时由 App::new 用 hostname 填
            save_dir: save,
            auto_accept_trusted: false,
            radar: Variant::Sweep,
        }
    }
}

#[derive(Clone, Debug)]
pub enum SetResult {
    Ok { key: &'static str, value: String },
    UnknownKey(String),
    BadValue { key: &'static str, value: String },
    Syntax,
}

impl Settings {
    /// `displayName=Alice` / `saveDir=~/dl` / `autoAccept=on|off|trusted` / `radar=sweep|pulse|grid|orbit`
    pub fn apply(&mut self, kv: &str) -> SetResult {
        let Some((k, v)) = kv.split_once('=') else {
            return SetResult::Syntax;
        };
        let k = k.trim();
        let v = v.trim().trim_matches('"');
        match k {
            "displayName" | "name" => {
                if v.is_empty() {
                    return SetResult::BadValue { key: "displayName", value: v.into() };
                }
                self.display_name = v.to_string();
                SetResult::Ok { key: "displayName", value: v.into() }
            }
            "saveDir" | "save_dir" | "savedir" => {
                if v.is_empty() {
                    return SetResult::BadValue { key: "saveDir", value: v.into() };
                }
                self.save_dir = expand_home(v);
                SetResult::Ok { key: "saveDir", value: self.save_dir.display().to_string() }
            }
            "autoAccept" | "auto_accept" | "autoaccept" => {
                let lower = v.to_ascii_lowercase();
                match lower.as_str() {
                    "on" | "true" | "yes" | "1" | "trusted" => {
                        self.auto_accept_trusted = true;
                        SetResult::Ok { key: "autoAccept", value: "trusted".into() }
                    }
                    "off" | "false" | "no" | "0" => {
                        self.auto_accept_trusted = false;
                        SetResult::Ok { key: "autoAccept", value: "off".into() }
                    }
                    _ => SetResult::BadValue { key: "autoAccept", value: v.into() },
                }
            }
            "radar" => match Variant::parse(v) {
                Some(var) => {
                    self.radar = var;
                    SetResult::Ok { key: "radar", value: var.label().to_ascii_lowercase() }
                }
                None => SetResult::BadValue { key: "radar", value: v.into() },
            },
            other => SetResult::UnknownKey(other.to_string()),
        }
    }
}

fn expand_home(s: &str) -> PathBuf {
    if let Some(rest) = s.strip_prefix("~/") {
        if let Ok(home) = std::env::var("HOME") {
            return PathBuf::from(home).join(rest);
        }
    }
    if s == "~" {
        if let Ok(home) = std::env::var("HOME") {
            return PathBuf::from(home);
        }
    }
    PathBuf::from(s)
}
