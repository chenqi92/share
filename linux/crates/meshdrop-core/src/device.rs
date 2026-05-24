use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum DeviceOS {
    Ios,
    Android,
    Macos,
    Windows,
    Linux,
}

impl DeviceOS {
    pub fn as_str(&self) -> &'static str {
        match self {
            DeviceOS::Ios => "ios",
            DeviceOS::Android => "android",
            DeviceOS::Macos => "macos",
            DeviceOS::Windows => "windows",
            DeviceOS::Linux => "linux",
        }
    }

    pub fn parse(s: &str) -> Option<Self> {
        match s {
            "ios" => Some(DeviceOS::Ios),
            "android" => Some(DeviceOS::Android),
            "macos" => Some(DeviceOS::Macos),
            "windows" => Some(DeviceOS::Windows),
            "linux" => Some(DeviceOS::Linux),
            _ => None,
        }
    }

    pub const CURRENT: DeviceOS = DeviceOS::Linux;
}

impl fmt::Display for DeviceOS {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.as_str())
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub struct Device {
    pub id: String,            // 32 hex
    pub name: String,          // 已 base64url 解码
    pub os: DeviceOS,
    pub model: Option<String>,
    pub fingerprint: String,   // 32 hex
    pub port: u16,
    pub protocol_version: u8,
    pub host: Option<String>,  // mDNS 解析得到的 IP / hostname
}

impl Device {
    /// 4 字符分组，空格分隔，大写。
    pub fn human_fingerprint(&self) -> String {
        let upper = self.fingerprint.to_uppercase();
        let chars: Vec<char> = upper.chars().collect();
        chars
            .chunks(4)
            .map(|c| c.iter().collect::<String>())
            .collect::<Vec<_>>()
            .join(" ")
    }
}
