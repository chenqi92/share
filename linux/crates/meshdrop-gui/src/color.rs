//! 设计宪法 §5 色板的单一来源。GUI 各处（CSS 字面量、cairo 自绘、chip 色点）
//! 都应从这里取值，避免同一语义色在多处以 hex / 浮点 RGB 重复定义而漂移。
//!
//! 语义色与 DESIGN_SPEC 对齐：
//!   ink #0A0A0A · paper #F5F2EC · lime #DDF94B（在线 / 已连接）
//!   flame #FF5A2C（发送中）· sky #4DB8FF（接收中）· failed #C4322B
//! lime_deep #A8C800 是 lime 的深色变体（status dot / 文本上更可读），非新增语义色。

#![allow(dead_code)]

pub const INK: &str = "#0A0A0A";
pub const PAPER: &str = "#F5F2EC";
pub const LIME: &str = "#DDF94B";
pub const LIME_DEEP: &str = "#A8C800";
pub const FLAME: &str = "#FF5A2C";
pub const SKY: &str = "#4DB8FF";
pub const FAILED: &str = "#C4322B";
/// 离线状态点用的中性灰（≈ ink45 的不透明等效），供 status dot 在离线时着色。
pub const MUTED: &str = "#8C887E";

/// 把 `#RRGGBB` 解析成 cairo 用的 0..1 浮点 RGB。非法输入回退黑色。
pub const fn rgb_of(hex: &str) -> (f64, f64, f64) {
    // const fn 里只做最朴素的解析；调用点都是编译期已知常量。
    let b = hex.as_bytes();
    if b.len() != 7 || b[0] != b'#' {
        return (0.0, 0.0, 0.0);
    }
    let r = hex_pair(b[1], b[2]);
    let g = hex_pair(b[3], b[4]);
    let bl = hex_pair(b[5], b[6]);
    (r as f64 / 255.0, g as f64 / 255.0, bl as f64 / 255.0)
}

const fn hex_pair(hi: u8, lo: u8) -> u8 {
    hex_digit(hi) * 16 + hex_digit(lo)
}

const fn hex_digit(c: u8) -> u8 {
    match c {
        b'0'..=b'9' => c - b'0',
        b'a'..=b'f' => c - b'a' + 10,
        b'A'..=b'F' => c - b'A' + 10,
        _ => 0,
    }
}

// 常用 cairo RGB 常量（编译期由上面的色板算出，雷达 / speed_chart 直接取）。
pub const INK_RGB: (f64, f64, f64) = rgb_of(INK);
pub const LIME_RGB: (f64, f64, f64) = rgb_of(LIME);
pub const FLAME_RGB: (f64, f64, f64) = rgb_of(FLAME);
pub const SKY_RGB: (f64, f64, f64) = rgb_of(SKY);
pub const PAPER_RGB: (f64, f64, f64) = rgb_of(PAPER);
