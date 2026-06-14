//! 文件接收 modal：发送方 + 文件名 + 大小 + 可选文字便签 + a/r/t 三键。

use crate::mock::PendingOffer;
use crate::ui::theme::Theme;
use crate::ui::widgets::{ascii_divider, chip};
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Paragraph, Wrap};
use ratatui::Frame;

pub fn render(f: &mut Frame, area: Rect, theme: &Theme, offer: &PendingOffer) {
    f.render_widget(Clear, area);

    let outer = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(theme.sky()).add_modifier(Modifier::BOLD))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled(
                "FILE OFFER",
                Style::default().fg(theme.sky()).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("  {}  {}  ", theme.small_dot(), t!("offer.subtitle")),
                Style::default().fg(theme.muted()),
            ),
            Span::styled(
                format!("[{}]", offer.received_at),
                Style::default().fg(theme.muted()),
            ),
            Span::raw(" "),
        ]));
    f.render_widget(&outer, area);
    let inner = outer.inner(area);

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),  // peer
            Constraint::Length(1),
            Constraint::Length(1),  // divider FILE
            Constraint::Length(1),
            Constraint::Length(1),  // file 行
            Constraint::Length(1),
            Constraint::Length(1),  // divider NOTE
            Constraint::Length(1),
            Constraint::Length(3),  // note
            Constraint::Length(1),
            Constraint::Length(1),  // 按键 hint
            Constraint::Min(0),
        ])
        .split(inner);

    let peer_line = Paragraph::new(Line::from(vec![
        Span::raw("  "),
        Span::styled(
            offer.peer.clone(),
            Style::default().fg(theme.ink()).add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            format!("  ·  {}  ", offer.device_name),
            Style::default().fg(theme.muted()),
        ),
        chip::chip(theme, "INCOMING", chip::Tone::Sky),
    ]));
    f.render_widget(peer_line, rows[0]);

    ascii_divider::render(f, rows[2], theme, &t!("offer.file_divider"));

    let file_line = Paragraph::new(Line::from(vec![
        Span::raw("  "),
        Span::styled("[PAGES]", Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD)),
        Span::raw("  "),
        Span::styled(offer.file_name.clone(), Style::default().fg(theme.ink()).add_modifier(Modifier::BOLD)),
        Span::styled(format!("    {}", offer.file_size), Style::default().fg(theme.muted())),
    ]));
    f.render_widget(file_line, rows[4]);

    ascii_divider::render(f, rows[6], theme, &t!("offer.note_divider"));

    let note = Paragraph::new(Line::from(vec![
        Span::raw("  "),
        Span::styled(
            format!("\"{}\"", offer.note),
            Style::default().fg(theme.ink()),
        ),
    ]))
    .wrap(Wrap { trim: false });
    f.render_widget(note, rows[8]);

    let hint = Paragraph::new(Line::from(vec![
        Span::raw("  "),
        chip::chip(theme, "[a]", chip::Tone::Lime),
        Span::styled(t!("offer.accept"), Style::default().fg(theme.ink())),
        chip::chip(theme, "[r]", chip::Tone::Flame),
        Span::styled(t!("offer.reject"), Style::default().fg(theme.ink())),
        chip::chip(theme, "[t]", chip::Tone::Ink),
        Span::styled(t!("offer.trust"), Style::default().fg(theme.ink())),
    ]))
    .alignment(Alignment::Center);
    f.render_widget(hint, rows[10]);
}
