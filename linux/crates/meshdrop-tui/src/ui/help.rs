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
                format!("  {}  按键参考 ", theme.small_dot()),
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
            "An intranet drop · radar discovery · drag-to-send · E2E encryption",
            Style::default().fg(theme.muted()),
        )),
    ];
    f.render_widget(
        Paragraph::new(header).alignment(Alignment::Center),
        rows[0],
    );

    ascii_divider::render(f, rows[1], theme, "KEYBINDINGS · 按键");

    let lines = vec![
        keyrow(theme, "j  k  ↑↓",     "在焦点区上下移动"),
        keyrow(theme, "Tab",          "切换焦点（设备 ↔ 历史）"),
        keyrow(theme, "Enter  i",     "进入文本输入模式（发给选中设备）"),
        keyrow(theme, ":",            "命令模式（:f <path> · :set k=v · :q · :trust · :revoke）"),
        keyrow(theme, "/",            "设备过滤"),
        keyrow(theme, "a  /  r  /  t","接受 / 拒绝 / 接受并信任 待审请求"),
        keyrow(theme, "d  c",         "删除选中历史 / 清空历史"),
        keyrow(theme, "F1  F2  F3",   "切换页：发现 · 传输 · 历史"),
        keyrow(theme, "p",            "弹配对 demo 模态"),
        keyrow(theme, "o",            "弹文件 offer demo 模态"),
        keyrow(theme, "?",            "打开 / 关闭本帮助"),
        keyrow(theme, "q  Esc",       "退出（或退出当前模式）"),
    ];
    f.render_widget(Paragraph::new(lines), rows[3]);

    let footer = Paragraph::new(Line::from(Span::styled(
        format!(
            "终端: {}  ·  字符: {}  ·  按任意键关闭",
            theme.label_color_tier(),
            theme.label_char_tier(),
        ),
        Style::default().fg(theme.muted()),
    )))
    .alignment(Alignment::Center);
    f.render_widget(footer, rows[4]);
}

fn keyrow<'a>(theme: &Theme, key: &'a str, desc: &'a str) -> Line<'a> {
    Line::from(vec![
        Span::raw("  "),
        Span::styled(
            format!("{:<14}", key),
            Style::default()
                .fg(theme.lime_deep())
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw("  "),
        Span::styled(desc, Style::default().fg(theme.ink())),
    ])
}
