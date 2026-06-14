//! 历史 / 传输流。每行：箭头 时间 → 对方 内容 状态。
//! 在进行中加进度条。

use crate::mock::{Direction, HistoryBody, HistoryItem, HistoryState};
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
    items: &[HistoryItem],
    state: &mut ListState,
    focused: bool,
) {
    let border = if focused { theme.lime() } else { theme.line() };
    let title = Line::from(vec![
        Span::raw(" "),
        Span::styled(
            "HISTORY",
            Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            format!("  {}  {} ", theme.small_dot(), t!("history.subtitle")),
            Style::default().fg(theme.muted()),
        ),
        Span::styled(format!("({})", items.len()), Style::default().fg(theme.muted())),
        Span::raw(" "),
    ]);

    let mut list_items: Vec<ListItem> = Vec::with_capacity(items.len() * 2);
    for h in items {
        list_items.push(ListItem::new(history_line(theme, h)));
        if let HistoryBody::File { progress: Some(p), .. } = &h.body {
            list_items.push(ListItem::new(progress_line(theme, *p, h.state)));
        }
    }

    let list = List::new(list_items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(border))
                .title(title),
        )
        .highlight_style(
            Style::default()
                .add_modifier(Modifier::BOLD)
                .add_modifier(Modifier::REVERSED),
        )
        .highlight_symbol(if focused { "▶ " } else { "  " });

    f.render_stateful_widget(list, area, state);
}

fn history_line<'a>(theme: &Theme, h: &HistoryItem) -> Line<'a> {
    let arrow_color = match h.dir {
        Direction::Outgoing => theme.flame(),
        Direction::Incoming => theme.sky(),
    };
    let arrow = Span::styled(
        format!(
            "{} ",
            match h.dir {
                Direction::Outgoing => theme.arrow_out(),
                Direction::Incoming => theme.arrow_in(),
            }
        ),
        Style::default().fg(arrow_color).add_modifier(Modifier::BOLD),
    );
    let time = Span::styled(
        format!("{}  ", h.time),
        Style::default().fg(theme.muted()),
    );
    let target = Span::styled(
        format!(
            "{} {}  ",
            if h.dir == Direction::Outgoing { "→" } else { "←" },
            h.peer
        ),
        Style::default().fg(theme.ink()),
    );

    let body = match &h.body {
        HistoryBody::Text(s) => {
            let s = truncate(s, 36);
            Span::styled(format!("\"{}\"", s), Style::default().fg(theme.ink()))
        }
        HistoryBody::File { name, size, ext, .. } => Span::styled(
            format!("[{}] {}  {}", ext.to_uppercase(), name, size),
            Style::default().fg(theme.ink()),
        ),
        HistoryBody::Image { count } => Span::styled(
            t!("history.images_count", count = count).to_string(),
            Style::default().fg(theme.ink()),
        ),
    };

    let status = match h.state {
        HistoryState::Done => Span::styled(
            format!("  {}", t!("history.state_done", glyph = theme.check())),
            Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD),
        ),
        HistoryState::Sending => Span::styled(
            format!("  {}", t!("history.state_sending", glyph = theme.arrow_up())),
            Style::default().fg(theme.flame()).add_modifier(Modifier::BOLD),
        ),
        HistoryState::Receiving => Span::styled(
            format!("  {}", t!("history.state_receiving", glyph = theme.arrow_down())),
            Style::default().fg(theme.sky()).add_modifier(Modifier::BOLD),
        ),
        HistoryState::Queued => Span::styled(
            format!("  {}", t!("history.state_queued")),
            Style::default().fg(theme.muted()),
        ),
        HistoryState::Failed => Span::styled(
            format!("  {}", t!("history.state_failed", glyph = theme.cross())),
            Style::default().fg(theme.error()).add_modifier(Modifier::BOLD),
        ),
    };

    Line::from(vec![arrow, time, target, body, status])
}

fn progress_line<'a>(theme: &Theme, progress: u8, state: HistoryState) -> Line<'a> {
    let total = 28usize;
    let filled = ((progress as usize) * total / 100).min(total);
    let color = match state {
        HistoryState::Sending => theme.flame(),
        HistoryState::Receiving => theme.sky(),
        HistoryState::Done => theme.lime_deep(),
        _ => theme.muted(),
    };
    let mut bar = String::with_capacity(total * 4);
    for i in 0..total {
        bar.push_str(theme.block(i < filled));
    }
    Line::from(vec![
        Span::raw("    "),
        Span::styled(bar, Style::default().fg(color)),
        Span::raw("  "),
        Span::styled(
            format!("{}%", progress),
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ),
    ])
}

fn truncate(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        return s.to_string();
    }
    let mut out: String = s.chars().take(max).collect();
    out.push('…');
    out
}
