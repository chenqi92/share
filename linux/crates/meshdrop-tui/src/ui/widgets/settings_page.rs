//! Settings 子页 — 展示当前 Settings + 三组分区。
//! 按 §8 的视觉规则：分三组（可见性 / 安全 · 加密 / 行为 · 接收）。
//! 实际改值走 `:set k=v` 命令。

use crate::mock::SelfCard;
use crate::settings::Settings;
use crate::ui::theme::Theme;
use crate::ui::widgets::{ascii_divider, chip};
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Paragraph};
use ratatui::Frame;

pub fn render(f: &mut Frame, area: Rect, theme: &Theme, me: &SelfCard, settings: &Settings) {
    let outer = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme.line()))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled(
                "SETTINGS",
                Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("  {}  设置 ", theme.small_dot()),
                Style::default().fg(theme.muted()),
            ),
            Span::styled(
                "·  改值用 :set k=v ",
                Style::default().fg(theme.muted()),
            ),
            Span::raw(""),
        ]));
    f.render_widget(&outer, area);
    let inner = outer.inner(area);

    let cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(34),
            Constraint::Percentage(33),
            Constraint::Percentage(33),
        ])
        .split(inner);

    section_visibility(f, cols[0], theme, me, settings);
    section_security(f, cols[1], theme, me);
    section_behavior(f, cols[2], theme, settings);
}

fn section_visibility(
    f: &mut Frame,
    area: Rect,
    theme: &Theme,
    me: &SelfCard,
    settings: &Settings,
) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(7),
            Constraint::Min(0),
        ])
        .split(area);
    ascii_divider::render(f, rows[0], theme, "VISIBILITY · 可见性");

    let name = if settings.display_name.is_empty() {
        me.name.clone()
    } else {
        settings.display_name.clone()
    };

    let lines = vec![
        Line::from(""),
        kv(theme, "display name ", &name, true),
        kv(theme, "visibility   ", me.visibility, false),
        kv(theme, "service      ", "_meshdrop._tcp", false),
        kv(theme, "port         ", "auto", false),
        Line::from(vec![
            Span::raw("  "),
            chip::chip(theme, "ONLINE", chip::Tone::Lime),
            Span::raw("  "),
            chip::chip(theme, "BROADCASTING", chip::Tone::Outline),
        ]),
    ];
    f.render_widget(Paragraph::new(lines), rows[3]);

    let hint = Paragraph::new(Line::from(Span::styled(
        "  改：:set displayName=Alice",
        Style::default().fg(theme.muted()),
    )));
    f.render_widget(hint, rows[4]);
}

fn section_security(f: &mut Frame, area: Rect, theme: &Theme, me: &SelfCard) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(7),
            Constraint::Min(0),
        ])
        .split(area);
    ascii_divider::render(f, rows[0], theme, "SECURITY · 加密");

    let lines = vec![
        Line::from(""),
        kv(theme, "encryption  ", "X25519 + ChaCha20-Poly1305", true),
        kv(theme, "fingerprint ", me.fingerprint, true),
        kv(theme, "trust mode  ", "TOFU + manual revoke", false),
        kv(theme, "ip          ", &me.ip, false),
        Line::from(vec![
            Span::raw("  "),
            chip::chip(theme, "E2E", chip::Tone::Lime),
            Span::raw("  "),
            chip::chip(theme, "LAN ONLY", chip::Tone::Outline),
        ]),
    ];
    f.render_widget(Paragraph::new(lines), rows[3]);

    let hint = Paragraph::new(Line::from(Span::styled(
        "  改：:revoke <fingerprint>",
        Style::default().fg(theme.muted()),
    )));
    f.render_widget(hint, rows[4]);
}

fn section_behavior(f: &mut Frame, area: Rect, theme: &Theme, settings: &Settings) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(7),
            Constraint::Min(0),
        ])
        .split(area);
    ascii_divider::render(f, rows[0], theme, "BEHAVIOR · 行为");

    let auto_label = if settings.auto_accept_trusted {
        "trusted only"
    } else {
        "off"
    };
    let auto_tone = if settings.auto_accept_trusted {
        chip::Tone::Lime
    } else {
        chip::Tone::Outline
    };

    let save_dir = settings.save_dir.display().to_string();
    let lines = vec![
        Line::from(""),
        kv(theme, "save dir    ", &save_dir, true),
        kv(theme, "auto accept ", auto_label, true),
        kv(theme, "radar       ", settings.radar.label(), true),
        Line::from(""),
        Line::from(vec![
            Span::raw("  "),
            chip::chip(theme, "AUTO ACCEPT", auto_tone),
            Span::raw("  "),
            chip::chip(theme, settings.radar.label(), chip::Tone::Lime),
        ]),
    ];
    f.render_widget(Paragraph::new(lines), rows[3]);

    let hint = Paragraph::new(vec![
        Line::from(Span::styled(
            "  改：:set saveDir=~/dl",
            Style::default().fg(theme.muted()),
        )),
        Line::from(Span::styled(
            "       :set autoAccept=on",
            Style::default().fg(theme.muted()),
        )),
        Line::from(Span::styled(
            "       :set radar=pulse",
            Style::default().fg(theme.muted()),
        )),
    ])
    .alignment(Alignment::Left);
    f.render_widget(hint, rows[4]);
}

fn kv<'a>(theme: &Theme, k: &'a str, v: &'a str, primary: bool) -> Line<'a> {
    let v_style = if primary {
        Style::default().fg(theme.ink()).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(theme.muted())
    };
    Line::from(vec![
        Span::raw("  "),
        Span::styled(
            k,
            Style::default().fg(theme.muted()).add_modifier(Modifier::BOLD),
        ),
        Span::styled(v.to_string(), v_style),
    ])
}
