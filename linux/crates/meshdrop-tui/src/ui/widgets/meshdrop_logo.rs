//! MeshDrop ASCII logo + wordmark。logo 是两个重叠圆环 + 中心 lime dot 的字符画。
//! wordmark 用小写 mono + 末尾 lime 实心圆点（点不能省）。

use crate::ui::theme::Theme;
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::Paragraph;
use ratatui::Frame;

/// 紧凑 wordmark：一行 `meshdrop.`（小写 + lime dot）
pub fn wordmark<'a>(theme: &Theme) -> Line<'a> {
    Line::from(vec![
        Span::styled(
            "meshdrop",
            Style::default().fg(theme.ink()).add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            theme.lime_pip().to_string(),
            Style::default().fg(theme.lime()).add_modifier(Modifier::BOLD),
        ),
    ])
}

/// 3 行 ASCII art logo（双圆环 + 中心 dot）；ascii fallback 用 `(o)(o)`
pub fn mark_lines<'a>(theme: &Theme) -> Vec<Line<'a>> {
    let ink = Style::default().fg(theme.ink());
    let lime = Style::default().fg(theme.lime()).add_modifier(Modifier::BOLD);
    let dot = theme.lime_pip();

    if matches!(theme.chars, crate::ui::theme::CharTier::Ascii) {
        return vec![
            Line::from(vec![Span::styled(" .--..--. ".to_string(), ink)]),
            Line::from(vec![
                Span::styled("(   ".to_string(), ink),
                Span::styled(dot.to_string(), lime),
                Span::styled("   )".to_string(), ink),
            ]),
            Line::from(vec![Span::styled(" `--'`--' ".to_string(), ink)]),
        ];
    }
    vec![
        Line::from(vec![Span::styled(" ╭───╮╭───╮ ".to_string(), ink)]),
        Line::from(vec![
            Span::styled("(    ".to_string(), ink),
            Span::styled(dot.to_string(), lime),
            Span::styled("    )".to_string(), ink),
        ]),
        Line::from(vec![Span::styled(" ╰───╯╰───╯ ".to_string(), ink)]),
    ]
}

/// 大号 hero wordmark — Discovery 空状态用。
pub fn hero(f: &mut Frame, area: Rect, theme: &Theme) {
    if area.height < 5 {
        let p = Paragraph::new(wordmark(theme));
        f.render_widget(p, area);
        return;
    }
    let mut lines = mark_lines(theme);
    lines.push(Line::from(""));
    lines.push(wordmark(theme));
    lines.push(Line::from(Span::styled(
        "An intranet drop · radar discovery · drag-to-send · plaintext TCP (v0.1)",
        Style::default().fg(theme.muted()),
    )));
    let p = Paragraph::new(lines).alignment(ratatui::layout::Alignment::Center);
    f.render_widget(p, area);
}
