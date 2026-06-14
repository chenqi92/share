//! 内存版 settings。`:set k=v` 落到这里；下一轮接 backend 时再做持久化。

use crate::ui::widgets::radar::Variant;
use std::path::PathBuf;

#[derive(Clone, Debug)]
pub struct Settings {
    pub display_name: String,
    pub save_dir: PathBuf,
    /// save_dir 是否为用户覆盖（true）还是默认派生（false）。用于决定是否下发 engine。
    pub save_dir_custom: bool,
    pub auto_accept_trusted: bool,
    // 附加式开关（默认安全值，与 engine 同口径）。
    pub visible_on_lan: bool,
    pub trusted_only: bool,
    pub verify_before_receive: bool,
    pub auto_accept_stranger: bool,
    pub clipboard_sync: bool,
    pub launch_at_login: bool,
    pub radar: Variant,
}

impl Default for Settings {
    fn default() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
        let save = PathBuf::from(home).join("Downloads/meshdrop");
        Self {
            display_name: String::new(), // 启动时由 App::new 用 hostname 填
            save_dir: save,
            save_dir_custom: false,
            auto_accept_trusted: false,
            visible_on_lan: true,
            trusted_only: false,
            verify_before_receive: true,
            auto_accept_stranger: false,
            clipboard_sync: false,
            launch_at_login: false,
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
                self.save_dir_custom = true;
                SetResult::Ok { key: "saveDir", value: self.save_dir.display().to_string() }
            }
            "visibleOnLan" | "visible_on_lan" | "visible" => match parse_bool(v) {
                Some(b) => {
                    self.visible_on_lan = b;
                    SetResult::Ok { key: "visibleOnLan", value: on_off(b) }
                }
                None => SetResult::BadValue { key: "visibleOnLan", value: v.into() },
            },
            "trustedOnly" | "trusted_only" => match parse_bool(v) {
                Some(b) => {
                    self.trusted_only = b;
                    SetResult::Ok { key: "trustedOnly", value: on_off(b) }
                }
                None => SetResult::BadValue { key: "trustedOnly", value: v.into() },
            },
            "verifyBeforeReceive" | "verify_before_receive" | "verify" => match parse_bool(v) {
                Some(b) => {
                    self.verify_before_receive = b;
                    SetResult::Ok { key: "verifyBeforeReceive", value: on_off(b) }
                }
                None => SetResult::BadValue { key: "verifyBeforeReceive", value: v.into() },
            },
            "autoAcceptStranger" | "auto_accept_stranger" => match parse_bool(v) {
                Some(b) => {
                    self.auto_accept_stranger = b;
                    SetResult::Ok { key: "autoAcceptStranger", value: on_off(b) }
                }
                None => SetResult::BadValue { key: "autoAcceptStranger", value: v.into() },
            },
            "clipboardSync" | "clipboard_sync" | "clipboard" => match parse_bool(v) {
                Some(b) => {
                    self.clipboard_sync = b;
                    SetResult::Ok { key: "clipboardSync", value: on_off(b) }
                }
                None => SetResult::BadValue { key: "clipboardSync", value: v.into() },
            },
            "launchAtLogin" | "launch_at_login" | "autostart" => match parse_bool(v) {
                Some(b) => {
                    self.launch_at_login = b;
                    SetResult::Ok { key: "launchAtLogin", value: on_off(b) }
                }
                None => SetResult::BadValue { key: "launchAtLogin", value: v.into() },
            },
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

/// 解析布尔值：on/true/yes/1 → true；off/false/no/0 → false；其余 None。
fn parse_bool(v: &str) -> Option<bool> {
    match v.to_ascii_lowercase().as_str() {
        "on" | "true" | "yes" | "1" => Some(true),
        "off" | "false" | "no" | "0" => Some(false),
        _ => None,
    }
}

fn on_off(b: bool) -> String {
    if b { "on".into() } else { "off".into() }
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
