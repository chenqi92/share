//! 设备列表 · NEARBY 区。
//! 一行：▶ KindGlyph 姓名 OS · RTT  · ●

use crate::mock::Device;
use crate::ui::theme::Theme;
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, List, ListItem, ListState};
use ratatui::Frame;

pub fn render(
    f: &mut Frame,
    area: Rect,
    theme: &Theme,
    devices: &[Device],
    state: &mut ListState,
    filter: Option<&str>,
    focused: bool,
) {
    let title_color = if focused { theme.lime() } else { theme.line() };
    let title = Line::from(vec![
        Span::raw(" "),
        Span::styled("NEARBY", Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD)),
        Span::styled(format!("  {}  {} ", theme.small_dot(), t!("device_list.subtitle")), Style::default().fg(theme.muted())),
        Span::styled(format!("({})", devices.len()), Style::default().fg(theme.muted())),
        Span::raw(" "),
    ]);

    let items: Vec<ListItem> = devices.iter().map(|d| device_item(theme, d)).collect();

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(title_color))
        .title(title);

    let mut list = List::new(items)
        .block(block)
        .highlight_style(
            Style::default()
                .fg(theme.ink())
                .add_modifier(Modifier::BOLD)
                .add_modifier(Modifier::REVERSED),
        )
        .highlight_symbol(if focused { "▶ " } else { "  " });

    if let Some(q) = filter {
        if !q.is_empty() {
            list = list.block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_type(BorderType::Rounded)
                    .border_style(Style::default().fg(theme.flame()))
                    .title(Line::from(vec![
                        Span::styled(" / ", Style::default().fg(theme.flame()).add_modifier(Modifier::BOLD)),
                        Span::raw(q.to_string()),
                        Span::styled(" _ ", Style::default().fg(theme.flame())),
                    ])),
            );
        }
    }

    f.render_stateful_widget(list, area, state);
}

fn device_item<'a>(theme: &Theme, d: &Device) -> ListItem<'a> {
    let glyph = Span::styled(
        format!("{} ", d.kind.glyph()),
        Style::default().fg(theme.muted()),
    );
    let who = Span::styled(
        format!("{} ", d.who),
        Style::default().fg(theme.ink()).add_modifier(Modifier::BOLD),
    );
    let name = Span::styled(
        format!("· {} ", d.name),
        Style::default().fg(theme.muted()),
    );
    let rtt = Span::styled(
        format!(" {} ms", d.rtt_ms),
        Style::default().fg(theme.muted()),
    );
    let online = Span::styled(
        format!(" {}", theme.dot()),
        Style::default().fg(theme.lime()),
    );

    // OS short label
    let kind = Span::styled(
        format!(" [{}]", d.kind.short()),
        Style::default().fg(theme.lime_deep()),
    );

    ListItem::new(Line::from(vec![glyph, who, name, kind, rtt, online]))
}
