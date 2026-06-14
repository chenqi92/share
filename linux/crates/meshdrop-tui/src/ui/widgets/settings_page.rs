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
                format!("  {}  {} ", theme.small_dot(), t!("settings.subtitle")),
                Style::default().fg(theme.muted()),
            ),
            Span::styled(
                t!("settings.set_hint"),
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
    section_security(f, cols[1], theme, me, settings);
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
    ascii_divider::render(f, rows[0], theme, &t!("settings.visibility_divider"));

    let name = if settings.display_name.is_empty() {
        me.name.clone()
    } else {
        settings.display_name.clone()
    };

    // 可见性随 visible_on_lan 真实反映：关时不再广告（不被发现）。
    let (vis_chip, vis_tone) = if settings.visible_on_lan {
        ("BROADCASTING", chip::Tone::Lime)
    } else {
        ("HIDDEN", chip::Tone::Outline)
    };
    let lines = vec![
        Line::from(""),
        kv(theme, "display name ", &name, true),
        kv(theme, "visible LAN  ", on_off(settings.visible_on_lan), true),
        kv(theme, "service      ", "_meshdrop._tcp", false),
        kv(theme, "port         ", "auto", false),
        Line::from(vec![
            Span::raw("  "),
            chip::chip(theme, "ONLINE", chip::Tone::Lime),
            Span::raw("  "),
            chip::chip(theme, vis_chip, vis_tone),
        ]),
    ];
    f.render_widget(Paragraph::new(lines), rows[3]);

    let hint = Paragraph::new(Line::from(Span::styled(
        t!("settings.hint_display_name"),
        Style::default().fg(theme.muted()),
    )));
    f.render_widget(hint, rows[4]);
}

fn section_security(f: &mut Frame, area: Rect, theme: &Theme, me: &SelfCard, settings: &Settings) {
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),
            Constraint::Length(1),
            Constraint::Length(8),
            Constraint::Min(0),
        ])
        .split(area);
    ascii_divider::render(f, rows[0], theme, &t!("settings.security_divider"));

    // v0.1 局域网传输为明文 TCP；身份用 Ed25519 + SHA-256 指纹做 TOFU。不宣称 E2E。
    // 安全开关随 settings 真实反映（:set 可改，engine 持久化）。
    let lines = vec![
        Line::from(""),
        kv(theme, "fingerprint   ", &me.fingerprint, true),
        kv(theme, "TOFU confirm  ", "on · locked", false),
        kv(theme, "trusted only  ", on_off(settings.trusted_only), true),
        kv(theme, "verify recv   ", on_off(settings.verify_before_receive), true),
        kv(theme, "auto stranger ", on_off(settings.auto_accept_stranger), true),
        kv(theme, "transport     ", "LAN plaintext (v0.1)", false),
        Line::from(vec![
            Span::raw("  "),
            chip::chip(theme, "TLS 1.3 mTLS · PLANNED", chip::Tone::Outline),
        ]),
    ];
    f.render_widget(Paragraph::new(lines), rows[2]);

    let hint = Paragraph::new(vec![
        Line::from(Span::styled(
            t!("settings.hint_revoke"),
            Style::default().fg(theme.muted()),
        )),
        Line::from(Span::styled(
            t!("settings.hint_trusted_only"),
            Style::default().fg(theme.muted()),
        )),
        Line::from(Span::styled(
            t!("settings.hint_verify"),
            Style::default().fg(theme.muted()),
        )),
    ]);
    f.render_widget(hint, rows[3]);
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
    ascii_divider::render(f, rows[0], theme, &t!("settings.behavior_divider"));

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
        kv(theme, "clipboard   ", on_off(settings.clipboard_sync), true),
        kv(theme, "launch login", on_off(settings.launch_at_login), true),
        kv(theme, "radar       ", settings.radar.label(), true),
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
            t!("settings.hint_save_dir"),
            Style::default().fg(theme.muted()),
        )),
        Line::from(Span::styled(
            t!("settings.hint_clipboard"),
            Style::default().fg(theme.muted()),
        )),
        Line::from(Span::styled(
            t!("settings.hint_launch_login"),
            Style::default().fg(theme.muted()),
        )),
    ])
    .alignment(Alignment::Left);
    f.render_widget(hint, rows[4]);
}

/// 布尔值的 on/off 展示文本。
fn on_off(b: bool) -> &'static str {
    if b { "on" } else { "off" }
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
