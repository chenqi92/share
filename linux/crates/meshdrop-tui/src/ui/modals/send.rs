//! 文本 / 文件输入框（底部 input bar）。

use crate::ui::theme::Theme;
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Paragraph};
use ratatui::Frame;

pub enum InputKind {
    Text,
    Command,
    Search,
}

pub fn render(
    f: &mut Frame,
    area: Rect,
    theme: &Theme,
    kind: InputKind,
    buffer: &str,
    target_name: &str,
) {
    let (prefix, title, prefix_color) = match kind {
        InputKind::Text => (
            "✎ ",
            t!("input.text_title", name = target_name).to_string(),
            theme.flame(),
        ),
        InputKind::Command => (
            ":",
            t!("input.command_title").to_string(),
            theme.lime(),
        ),
        InputKind::Search => (
            "/",
            t!("input.search_title").to_string(),
            theme.flame(),
        ),
    };

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(prefix_color))
        .title(Line::from(Span::styled(
            title,
            Style::default().fg(theme.muted()),
        )));

    let body = Line::from(vec![
        Span::styled(
            prefix,
            Style::default().fg(prefix_color).add_modifier(Modifier::BOLD),
        ),
        Span::raw(buffer.to_string()),
        Span::styled(
            "█",
            Style::default()
                .fg(prefix_color)
                .add_modifier(Modifier::SLOW_BLINK),
        ),
    ]);
    f.render_widget(Paragraph::new(body).block(block), area);
}

pub fn render_status(f: &mut Frame, area: Rect, theme: &Theme, status: &str, hint: &str) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme.line()))
        .title(Line::from(Span::styled(
            " READY ",
            Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD),
        )));
    let lines = vec![
        Line::from(vec![
            Span::styled(
                if status.is_empty() { hint } else { status },
                Style::default().fg(if status.is_empty() {
                    theme.muted()
                } else {
                    theme.ink()
                }),
            ),
        ]),
    ];
    f.render_widget(Paragraph::new(lines).block(block), area);
}
