//! ASCII divider — 左右两条 hr + 中间 mono uppercase label。
//! 例：`── TODAY · 今天 · 5 件 ──`

use crate::ui::theme::Theme;
use ratatui::layout::Rect;
use ratatui::style::{Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::Paragraph;
use ratatui::Frame;

pub fn render(f: &mut Frame, area: Rect, theme: &Theme, label: &str) {
    if area.width < 4 || area.height < 1 {
        return;
    }
    let label = label.to_uppercase();
    // 间距 1 字符模拟 letterSpacing
    let mut wide = String::with_capacity(label.len() * 2);
    for (i, c) in label.chars().enumerate() {
        if i > 0 { wide.push(' '); }
        wide.push(c);
    }
    let total = area.width as usize;
    let label_w = wide.chars().count() + 4; // 两边各 2 空格
    let side = total.saturating_sub(label_w) / 2;
    let dash = theme.divider_dash();
    let left: String = std::iter::repeat(dash).take(side).collect();
    let right: String = std::iter::repeat(dash).take(total.saturating_sub(side + label_w)).collect();

    let muted = Style::default().fg(theme.muted());
    let line = Line::from(vec![
        Span::styled(left, muted),
        Span::raw("  "),
        Span::styled(wide, Style::default().fg(theme.muted()).add_modifier(Modifier::BOLD)),
        Span::raw("  "),
        Span::styled(right, muted),
    ]);
    f.render_widget(Paragraph::new(line), area);
}
