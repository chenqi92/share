//! 色彩 / 字符自适配。truecolor / 256 / 16 三档；braille 与 ASCII 字符 fallback。

#![allow(dead_code)]

use ratatui::style::Color;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ColorTier {
    Truecolor,
    X256,
    Ansi16,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CharTier {
    /// Unicode + braille（⣿⠿）+ box-drawing 全套
    Full,
    /// 纯 ASCII（终端不支持 braille / 非 UTF-8 locale）
    Ascii,
}

#[derive(Clone, Copy, Debug)]
pub struct Theme {
    pub tier: ColorTier,
    pub chars: CharTier,
    pub dark: bool,
}

impl Theme {
    pub fn detect() -> Self {
        let tier = detect_color_tier();
        let chars = detect_char_tier();
        // 终端 99% 是暗底；MeshDrop 暗模式 outgoing 用 lime
        let dark = !matches!(std::env::var("MESHDROP_LIGHT").ok().as_deref(), None | Some(""));
        let dark = dark || true; // 始终按暗底渲染（终端默认即暗）
        Theme { tier, chars, dark }
    }

    // ── 三色语义 accent ────────────────────────────────────────────

    pub fn lime(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0xDD, 0xF9, 0x4B),
            ColorTier::X256 => Color::Indexed(190),
            ColorTier::Ansi16 => Color::LightGreen,
        }
    }
    pub fn lime_deep(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0xA8, 0xC8, 0x00),
            ColorTier::X256 => Color::Indexed(148),
            ColorTier::Ansi16 => Color::Green,
        }
    }
    pub fn flame(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0xFF, 0x5A, 0x2C),
            ColorTier::X256 => Color::Indexed(202),
            ColorTier::Ansi16 => Color::LightRed,
        }
    }
    pub fn flame_deep(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0xC7, 0x3E, 0x15),
            ColorTier::X256 => Color::Indexed(166),
            ColorTier::Ansi16 => Color::Red,
        }
    }
    pub fn sky(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0x4D, 0xB8, 0xFF),
            ColorTier::X256 => Color::Indexed(75),
            ColorTier::Ansi16 => Color::LightBlue,
        }
    }
    pub fn error(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0xC4, 0x32, 0x2B),
            ColorTier::X256 => Color::Indexed(160),
            ColorTier::Ansi16 => Color::Red,
        }
    }

    // ── ink / paper ────────────────────────────────────────────────

    pub fn ink(&self) -> Color {
        // 暗底下"ink"实际是浅纸色（按 §5 暗模式映射）
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0xE8, 0xE3, 0xD6),
            ColorTier::X256 => Color::Indexed(187),
            ColorTier::Ansi16 => Color::White,
        }
    }
    pub fn paper(&self) -> Color {
        // 暗底下"paper"是 dink 暖黑
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0x0E, 0x0C, 0x09),
            ColorTier::X256 => Color::Indexed(232),
            ColorTier::Ansi16 => Color::Black,
        }
    }
    pub fn muted(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0x88, 0x84, 0x7B),
            ColorTier::X256 => Color::Indexed(243),
            ColorTier::Ansi16 => Color::DarkGray,
        }
    }
    pub fn line(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0x3A, 0x36, 0x2E),
            ColorTier::X256 => Color::Indexed(237),
            ColorTier::Ansi16 => Color::DarkGray,
        }
    }
    pub fn card(&self) -> Color {
        match self.tier {
            ColorTier::Truecolor => Color::Rgb(0x18, 0x16, 0x12),
            ColorTier::X256 => Color::Indexed(233),
            ColorTier::Ansi16 => Color::Black,
        }
    }

    // ── 字符 fallback ──────────────────────────────────────────────

    pub fn dot(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "●",
            CharTier::Ascii => "o",
        }
    }
    pub fn small_dot(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "·",
            CharTier::Ascii => ".",
        }
    }
    pub fn arrow_up(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "↑",
            CharTier::Ascii => "^",
        }
    }
    pub fn arrow_down(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "↓",
            CharTier::Ascii => "v",
        }
    }
    pub fn arrow_in(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "↙",
            CharTier::Ascii => "<-",
        }
    }
    pub fn arrow_out(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "↗",
            CharTier::Ascii => "->",
        }
    }
    pub fn check(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "✓",
            CharTier::Ascii => "v",
        }
    }
    pub fn cross(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "×",
            CharTier::Ascii => "x",
        }
    }
    pub fn lime_pip(&self) -> &'static str {
        // logo 尾巴的 lime 圆点
        match self.chars {
            CharTier::Full => "●",
            CharTier::Ascii => "*",
        }
    }
    pub fn block(&self, filled: bool) -> &'static str {
        match (self.chars, filled) {
            (CharTier::Full, true) => "▰",
            (CharTier::Full, false) => "▱",
            (CharTier::Ascii, true) => "#",
            (CharTier::Ascii, false) => "-",
        }
    }
    pub fn radar_dot(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "⣿",
            CharTier::Ascii => "*",
        }
    }
    /// 雷达背景小点
    pub fn radar_speck(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "·",
            CharTier::Ascii => ".",
        }
    }
    /// ASCII divider 用的横线
    pub fn divider_dash(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "─",
            CharTier::Ascii => "-",
        }
    }

    pub fn label_color_tier(&self) -> &'static str {
        match self.tier {
            ColorTier::Truecolor => "TRUECOLOR",
            ColorTier::X256 => "256-COLOR",
            ColorTier::Ansi16 => "ANSI-16",
        }
    }
    pub fn label_char_tier(&self) -> &'static str {
        match self.chars {
            CharTier::Full => "UNICODE",
            CharTier::Ascii => "ASCII",
        }
    }
}

fn detect_color_tier() -> ColorTier {
    if let Ok(force) = std::env::var("MESHDROP_COLOR") {
        match force.to_ascii_lowercase().as_str() {
            "truecolor" | "24bit" | "rgb" => return ColorTier::Truecolor,
            "256" | "x256" => return ColorTier::X256,
            "16" | "ansi" | "ansi16" => return ColorTier::Ansi16,
            _ => {}
        }
    }
    if let Ok(v) = std::env::var("COLORTERM") {
        let v = v.to_ascii_lowercase();
        if v.contains("truecolor") || v.contains("24bit") {
            return ColorTier::Truecolor;
        }
    }
    if let Ok(term) = std::env::var("TERM") {
        let t = term.to_ascii_lowercase();
        if t.contains("256") {
            return ColorTier::X256;
        }
        if t == "linux" || t == "dumb" {
            return ColorTier::Ansi16;
        }
        if t.contains("kitty") || t.contains("alacritty") || t.contains("wezterm") || t.contains("xterm-ghostty") {
            return ColorTier::Truecolor;
        }
    }
    // 默认 256：99% 的现代终端至少能。最差也只是看起来颗粒一点。
    ColorTier::X256
}

fn detect_char_tier() -> CharTier {
    if let Ok(force) = std::env::var("MESHDROP_CHARS") {
        match force.to_ascii_lowercase().as_str() {
            "ascii" => return CharTier::Ascii,
            "full" | "unicode" => return CharTier::Full,
            _ => {}
        }
    }
    // 非 UTF-8 locale → ASCII；TERM=linux 等 framebuffer 也 → ASCII
    let utf8 = std::env::var("LANG").ok().map(|s| s.to_ascii_lowercase().contains("utf"))
        .or_else(|| std::env::var("LC_ALL").ok().map(|s| s.to_ascii_lowercase().contains("utf")))
        .or_else(|| std::env::var("LC_CTYPE").ok().map(|s| s.to_ascii_lowercase().contains("utf")))
        .unwrap_or(true);
    if !utf8 {
        return CharTier::Ascii;
    }
    if let Ok(term) = std::env::var("TERM") {
        if term == "linux" || term == "dumb" {
            return CharTier::Ascii;
        }
    }
    CharTier::Full
}
