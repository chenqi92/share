//! `?` 键帮助 overlay。

use crate::ui::modals;
use crate::ui::theme::Theme;
use crate::ui::widgets::{ascii_divider, meshdrop_logo};
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Paragraph};
use ratatui::Frame;

pub fn render(f: &mut Frame, full: Rect, theme: &Theme) {
    let area = modals::centered(72, 22, full);
    f.render_widget(Clear, area);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme.lime()))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled(
                "HELP",
                Style::default().fg(theme.lime()).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("  {}  {} ", theme.small_dot(), t!("help.subtitle")),
                Style::default().fg(theme.muted()),
            ),
        ]));
    f.render_widget(&block, area);
    let inner = block.inner(area);

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(2),
            Constraint::Length(1),  // divider
            Constraint::Length(1),
            Constraint::Min(0),
            Constraint::Length(1),
        ])
        .split(inner);

    let header = vec![
        meshdrop_logo::wordmark(theme),
        Line::from(Span::styled(
            t!("help.tagline"),
            Style::default().fg(theme.muted()),
        )),
    ];
    f.render_widget(
        Paragraph::new(header).alignment(Alignment::Center),
        rows[0],
    );

    ascii_divider::render(f, rows[1], theme, &t!("help.keybindings_divider"));

    let lines = vec![
        keyrow(theme, "j  k  ↑↓",     &t!("help.k_move")),
        keyrow(theme, "h  l",         &t!("help.k_focus")),
        keyrow(theme, "Enter  i",     &t!("help.k_input")),
        keyrow(theme, ":",            &t!("help.k_command")),
        keyrow(theme, "/",            &t!("help.k_filter")),
        keyrow(theme, "a  /  r  /  t",&t!("help.k_decision")),
        keyrow(theme, "d  c",         &t!("help.k_history")),
        keyrow(theme, "x",            &t!("help.k_cancel")),
        keyrow(theme, "R",            &t!("help.k_retry")),
        keyrow(theme, "1..6 Tab [ ]", &t!("help.k_pages")),
        keyrow(theme, "p",            &t!("help.k_demo_pairing")),
        keyrow(theme, "o",            &t!("help.k_demo_offer")),
        keyrow(theme, "?",            &t!("help.k_help")),
        keyrow(theme, "q  Esc",       &t!("help.k_quit")),
    ];
    f.render_widget(Paragraph::new(lines), rows[3]);

    let footer = Paragraph::new(Line::from(Span::styled(
        t!("help.footer",
            color = theme.label_color_tier(),
            chars = theme.label_char_tier(),
        ).to_string(),
        Style::default().fg(theme.muted()),
    )))
    .alignment(Alignment::Center);
    f.render_widget(footer, rows[4]);
}

fn keyrow(theme: &Theme, key: &str, desc: &str) -> Line<'static> {
    // desc 来自 t!() 临时值，转成 owned String 让返回的 Line 不再借用临时量。
    Line::from(vec![
        Span::raw("  "),
        Span::styled(
            format!("{:<14}", key),
            Style::default()
                .fg(theme.lime_deep())
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw("  "),
        Span::styled(desc.to_string(), Style::default().fg(theme.ink())),
    ])
}
