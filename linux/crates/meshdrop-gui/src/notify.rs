//! 桌面通知封装。本轮 UI-only：mock 时只 log 一行。
//! 真接 backend 时替换为 notify-rust 调用。

#![allow(dead_code)]

pub fn toast(_summary: &str, _body: &str) {
    log::info!("[mock notify] {_summary} — {_body}");
}
