//! 配对 modal：6 字符代码用大字号块字符 + 8 组指纹 + 三键操作。

use crate::mock::PendingPairing;
use crate::ui::theme::{CharTier, Theme};
use crate::ui::widgets::{ascii_divider, chip};
use ratatui::layout::{Alignment, Constraint, Direction, Layout, Rect};
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{Block, BorderType, Borders, Clear, Paragraph};
use ratatui::Frame;

pub fn render(f: &mut Frame, area: Rect, theme: &Theme, pairing: &PendingPairing) {
    f.render_widget(Clear, area);

    let outer = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Double)
        .border_style(Style::default().fg(theme.lime()).add_modifier(Modifier::BOLD))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled(
                "PAIRING",
                Style::default().fg(theme.lime()).add_modifier(Modifier::BOLD),
            ),
            Span::styled(
                format!("  {}  配对请求  ", theme.small_dot()),
                Style::default().fg(theme.muted()),
            ),
            Span::styled(
                format!("[{}]", pairing.received_at),
                Style::default().fg(theme.muted()),
            ),
            Span::raw(" "),
        ]));

    f.render_widget(&outer, area);
    let inner = outer.inner(area);

    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(1),         // peer / 副标题
            Constraint::Length(1),
            Constraint::Length(1),         // divider
            Constraint::Length(1),
            Constraint::Length(5),         // 大字号代码
            Constraint::Length(1),
            Constraint::Length(1),         // divider
            Constraint::Length(1),
            Constraint::Length(2),         // 指纹 8 组（两行）
            Constraint::Length(1),
            Constraint::Length(1),         // hint
            Constraint::Min(0),
        ])
        .split(inner);

    let peer = Paragraph::new(Line::from(vec![
        Span::styled(
            format!("  {} ", pairing.peer),
            Style::default().fg(theme.ink()).add_modifier(Modifier::BOLD),
        ),
        Span::styled(
            format!("· {}", pairing.device_name),
            Style::default().fg(theme.muted()),
        ),
        Span::raw("  "),
        chip::chip(theme, "STRANGER", chip::Tone::Flame),
    ]));
    f.render_widget(peer, rows[0]);

    ascii_divider::render(f, rows[2], theme, "VERIFY CODE · 6 位代码");
    render_big_code(f, rows[4], theme, pairing.code);
    ascii_divider::render(f, rows[6], theme, "FINGERPRINT · 完整指纹");

    let fp_lines: Vec<Line> = split_fingerprint(pairing.fingerprint)
        .into_iter()
        .map(|row| {
            Line::from(Span::styled(
                row,
                Style::default()
                    .fg(theme.lime_deep())
                    .add_modifier(Modifier::BOLD),
            ))
            .alignment(Alignment::Center)
        })
        .collect();
    f.render_widget(Paragraph::new(fp_lines), rows[8]);

    let hint = Line::from(vec![
        Span::raw("  "),
        chip::chip(theme, "[a]", chip::Tone::Lime),
        Span::styled(" 允许一次   ", Style::default().fg(theme.ink())),
        chip::chip(theme, "[t]", chip::Tone::Lime),
        Span::styled(" 信任并记住   ", Style::default().fg(theme.ink())),
        chip::chip(theme, "[r]", chip::Tone::Flame),
        Span::styled(" 拒绝", Style::default().fg(theme.ink())),
    ])
    .alignment(Alignment::Center);
    f.render_widget(Paragraph::new(hint), rows[10]);
}

fn split_fingerprint(fp: &str) -> Vec<String> {
    let groups: Vec<&str> = fp.split(" · ").collect();
    let half = (groups.len() + 1) / 2;
    let a = groups[..half].join(" · ");
    let b = groups[half..].join(" · ");
    vec![a, b]
}

/// 把 6 位代码渲成 5 行高的块字体。
fn render_big_code(f: &mut Frame, area: Rect, theme: &Theme, code: &str) {
    // 只看前 6 个 alnum 字符
    let chars: Vec<char> = code.chars().filter(|c| c.is_alphanumeric()).take(6).collect();
    let bigfont = matches!(theme.chars, CharTier::Full);

    let mut rows = vec![String::new(); 5];
    for (i, &c) in chars.iter().enumerate() {
        if i > 0 {
            for r in rows.iter_mut() {
                r.push(' ');
                r.push(' ');
            }
        }
        // 中间位置插一个 · 分组（3 + 3）
        if i == 3 {
            for r in rows.iter_mut() {
                r.push('·');
                r.push(' ');
            }
        }
        let glyph = big_glyph(c, bigfont);
        for (r, g) in rows.iter_mut().zip(glyph.iter()) {
            r.push_str(g);
        }
    }

    let style = Style::default()
        .fg(theme.lime())
        .add_modifier(Modifier::BOLD);
    let lines: Vec<Line> = rows
        .into_iter()
        .map(|s| Line::from(Span::styled(s, style)).alignment(Alignment::Center))
        .collect();
    f.render_widget(Paragraph::new(lines), area);
}

/// 返回 5 行 ascii art。最小覆盖 0-9A-Z。
fn big_glyph(c: char, full: bool) -> [&'static str; 5] {
    let blk = if full { "█" } else { "#" };
    let _ = blk;
    match c.to_ascii_uppercase() {
        '0' => [" ███ ", "█   █", "█   █", "█   █", " ███ "],
        '1' => ["  █  ", " ██  ", "  █  ", "  █  ", " ███ "],
        '2' => [" ███ ", "█   █", "   █ ", "  █  ", "█████"],
        '3' => [" ███ ", "█   █", "   █ ", "█   █", " ███ "],
        '4' => ["█   █", "█   █", "█████", "    █", "    █"],
        '5' => ["█████", "█    ", "████ ", "    █", "████ "],
        '6' => [" ███ ", "█    ", "████ ", "█   █", " ███ "],
        '7' => ["█████", "    █", "   █ ", "  █  ", " █   "],
        '8' => [" ███ ", "█   █", " ███ ", "█   █", " ███ "],
        '9' => [" ███ ", "█   █", " ████", "    █", " ███ "],
        'A' => [" ███ ", "█   █", "█████", "█   █", "█   █"],
        'B' => ["████ ", "█   █", "████ ", "█   █", "████ "],
        'C' => [" ███ ", "█    ", "█    ", "█    ", " ███ "],
        'D' => ["████ ", "█   █", "█   █", "█   █", "████ "],
        'E' => ["█████", "█    ", "███  ", "█    ", "█████"],
        'F' => ["█████", "█    ", "███  ", "█    ", "█    "],
        'G' => [" ███ ", "█    ", "█  ██", "█   █", " ███ "],
        'H' => ["█   █", "█   █", "█████", "█   █", "█   █"],
        'I' => [" ███ ", "  █  ", "  █  ", "  █  ", " ███ "],
        'J' => ["  ███", "    █", "    █", "█   █", " ███ "],
        'K' => ["█   █", "█  █ ", "███  ", "█  █ ", "█   █"],
        'L' => ["█    ", "█    ", "█    ", "█    ", "█████"],
        'M' => ["█   █", "██ ██", "█ █ █", "█   █", "█   █"],
        'N' => ["█   █", "██  █", "█ █ █", "█  ██", "█   █"],
        'O' => [" ███ ", "█   █", "█   █", "█   █", " ███ "],
        'P' => ["████ ", "█   █", "████ ", "█    ", "█    "],
        'Q' => [" ███ ", "█   █", "█   █", "█  ██", " ████"],
        'R' => ["████ ", "█   █", "████ ", "█  █ ", "█   █"],
        'S' => [" ████", "█    ", " ███ ", "    █", "████ "],
        'T' => ["█████", "  █  ", "  █  ", "  █  ", "  █  "],
        'U' => ["█   █", "█   █", "█   █", "█   █", " ███ "],
        'V' => ["█   █", "█   █", "█   █", " █ █ ", "  █  "],
        'W' => ["█   █", "█   █", "█ █ █", "██ ██", "█   █"],
        'X' => ["█   █", " █ █ ", "  █  ", " █ █ ", "█   █"],
        'Y' => ["█   █", " █ █ ", "  █  ", "  █  ", "  █  "],
        'Z' => ["█████", "   █ ", "  █  ", " █   ", "█████"],
        _   => ["     ", "     ", "     ", "     ", "     "],
    }
}
