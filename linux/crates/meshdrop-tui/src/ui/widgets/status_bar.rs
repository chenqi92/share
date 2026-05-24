//! 顶部状态条 + 底部输入条。

use crate::mock::SelfCard;
use crate::ui::theme::Theme;
use crate::ui::widgets::{chip, meshdrop_logo};
use ratatui::layout::{Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::Paragraph;
use ratatui::Frame;

pub fn render_top(f: &mut Frame, area: Rect, theme: &Theme, me: &SelfCard, peer_count: usize) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Length(12),  // wordmark
            Constraint::Min(20),     // 设备信息
            Constraint::Length(40),  // 右侧 chips
        ])
        .split(area);

    // wordmark
    let wm = Paragraph::new(meshdrop_logo::wordmark(theme));
    f.render_widget(wm, chunks[0]);

    // 中间：DEV-01 · 192.168.1.42 · 指纹
    let mid = Line::from(vec![
        Span::styled(me.name.clone(), Style::default().fg(theme.ink()).add_modifier(Modifier::BOLD)),
        Span::styled(format!("  {} ", theme.small_dot()), Style::default().fg(theme.muted())),
        Span::styled(me.ip.clone(), Style::default().fg(theme.ink())),
        Span::styled(format!("  {} ", theme.small_dot()), Style::default().fg(theme.muted())),
        Span::styled("FP ", Style::default().fg(theme.muted())),
        Span::styled(me.fingerprint.clone(), Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD)),
    ]);
    f.render_widget(Paragraph::new(mid), chunks[1]);

    // 右侧 chips：LIVE 5 · E2E · LAN ONLY
    let right = Line::from(vec![
        chip::chip(theme, &format!("LIVE {}", peer_count), chip::Tone::Lime),
        Span::raw(" "),
        chip::chip(theme, "E2E", chip::Tone::Outline),
        Span::raw(" "),
        chip::chip(theme, "LAN ONLY", chip::Tone::Outline),
    ]);
    let p = Paragraph::new(right).alignment(ratatui::layout::Alignment::Right);
    f.render_widget(p, chunks[2]);
}
