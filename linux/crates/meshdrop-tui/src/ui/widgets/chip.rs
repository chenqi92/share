//! 胶囊标签 chip — 终端版用反白色块模拟。

#![allow(dead_code)]

use crate::ui::theme::Theme;
use ratatui::style::{Modifier, Style};
use ratatui::text::Span;

#[derive(Clone, Copy)]
pub enum Tone {
    Mute,
    Lime,
    Ink,
    Outline,
    Flame,
    Sky,
}

pub fn chip(theme: &Theme, text: impl Into<String>, tone: Tone) -> Span<'static> {
    let text = text.into();
    let s = match tone {
        Tone::Mute => Style::default().fg(theme.muted()),
        Tone::Lime => Style::default()
            .bg(theme.lime())
            .fg(theme.paper())
            .add_modifier(Modifier::BOLD),
        Tone::Ink => Style::default()
            .bg(theme.ink())
            .fg(theme.paper())
            .add_modifier(Modifier::BOLD),
        Tone::Outline => Style::default()
            .fg(theme.ink())
            .add_modifier(Modifier::DIM),
        Tone::Flame => Style::default()
            .bg(theme.flame())
            .fg(theme.paper())
            .add_modifier(Modifier::BOLD),
        Tone::Sky => Style::default()
            .bg(theme.sky())
            .fg(theme.paper())
            .add_modifier(Modifier::BOLD),
    };
    Span::styled(format!(" {} ", text), s)
}

/// uppercase mono tag (无背景，只有色 + 加粗 + 间距)
pub fn tag(theme: &Theme, text: impl AsRef<str>, tone: Tone) -> Span<'static> {
    let text = text.as_ref();
    let fg = match tone {
        Tone::Lime => theme.lime(),
        Tone::Flame => theme.flame(),
        Tone::Sky => theme.sky(),
        Tone::Ink => theme.ink(),
        Tone::Mute | Tone::Outline => theme.muted(),
    };
    // 全大写 + 字距用空格模拟（终端没法真正调字距）
    let mut wide = String::with_capacity(text.len() * 2);
    for (i, c) in text.chars().enumerate() {
        if i > 0 { wide.push(' '); }
        for u in c.to_uppercase() {
            wide.push(u);
        }
    }
    Span::styled(wide, Style::default().fg(fg).add_modifier(Modifier::BOLD))
}
