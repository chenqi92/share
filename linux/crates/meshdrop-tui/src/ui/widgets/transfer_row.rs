//! 传输管理器一行：[EXT] 名字  大小  状态  进度条  速度  ETA。

use crate::mock::{HistoryState, Transfer};
use crate::ui::theme::Theme;
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, List, ListItem};
use ratatui::Frame;

pub fn render(f: &mut Frame, area: Rect, theme: &Theme, list: &[Transfer]) {
    let mut items: Vec<ListItem> = Vec::with_capacity(list.len() * 2);
    for t in list {
        items.push(ListItem::new(top_line(theme, t)));
        items.push(ListItem::new(bottom_line(theme, t)));
        items.push(ListItem::new(Line::from("")));
    }
    let title = Line::from(vec![
        Span::raw(" "),
        Span::styled(
            "TRANSFERS",
            Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            format!("  {}  传输 ", theme.small_dot()),
            Style::default().fg(theme.muted()),
        ),
        Span::styled(format!("({})", list.len()), Style::default().fg(theme.muted())),
        Span::raw(" "),
    ]);

    f.render_widget(
        List::new(items).block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(theme.line()))
                .title(title),
        ),
        area,
    );
}

fn top_line<'a>(theme: &Theme, t: &Transfer) -> Line<'a> {
    let ext_color = match t.state {
        HistoryState::Sending => theme.flame(),
        HistoryState::Receiving => theme.sky(),
        HistoryState::Done => theme.lime_deep(),
        HistoryState::Failed => theme.error(),
        HistoryState::Queued => theme.muted(),
    };
    Line::from(vec![
        Span::styled(
            format!(" [{}]  ", t.ext.to_uppercase()),
            Style::default().fg(ext_color).add_modifier(Modifier::BOLD),
        ),
        Span::styled(t.name, Style::default().fg(theme.ink()).add_modifier(Modifier::BOLD)),
        Span::styled(
            format!("   {}", t.size),
            Style::default().fg(theme.muted()),
        ),
        Span::styled(
            format!("   {} → {}", t.from, t.to),
            Style::default().fg(theme.muted()),
        ),
    ])
}

fn bottom_line<'a>(theme: &Theme, t: &Transfer) -> Line<'a> {
    let total = 32usize;
    let filled = ((t.progress as usize) * total / 100).min(total);
    let color = match t.state {
        HistoryState::Sending => theme.flame(),
        HistoryState::Receiving => theme.sky(),
        HistoryState::Done => theme.lime_deep(),
        HistoryState::Failed => theme.error(),
        HistoryState::Queued => theme.muted(),
    };
    let mut bar = String::with_capacity(total * 4);
    for i in 0..total {
        bar.push_str(theme.block(i < filled));
    }
    let state_label = match t.state {
        HistoryState::Sending => format!("{} 发送", theme.arrow_up()),
        HistoryState::Receiving => format!("{} 接收", theme.arrow_down()),
        HistoryState::Done => format!("{} 完成", theme.check()),
        HistoryState::Failed => format!("{} 失败", theme.cross()),
        HistoryState::Queued => "· 队列".to_string(),
    };
    let mut spans = vec![
        Span::raw("       "),
        Span::styled(state_label, Style::default().fg(color).add_modifier(Modifier::BOLD)),
        Span::raw("  "),
        Span::styled(bar, Style::default().fg(color)),
        Span::raw("  "),
        Span::styled(
            format!("{:>3}%", t.progress),
            Style::default().fg(color).add_modifier(Modifier::BOLD),
        ),
    ];
    if let Some(speed) = t.speed {
        spans.push(Span::styled(format!("   {}", speed), Style::default().fg(theme.muted())));
    }
    if let Some(eta) = t.eta {
        spans.push(Span::styled(format!("   ETA {}", eta), Style::default().fg(theme.muted())));
    }
    Line::from(spans)
}
