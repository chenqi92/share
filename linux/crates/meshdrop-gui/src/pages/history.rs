//! History / Library 页：按日分组的图/文件/文字 grid。
//! 当 handle.is_some()：订阅 engine.history_rx 实时刷新。
//! 否则使用 mock 数据（screenshots 模式）。

use crate::components::{ascii_divider, chip, file_chip, icon_btn};
use crate::engine_bridge::AppHandle;
use crate::mock;
use crate::view::{ViewHistoryKind, ViewHistoryRow};
use adw::prelude::*;
use std::rc::Rc;

pub fn build(handle: Option<&Rc<AppHandle>>) -> gtk::Widget {
    let root = gtk::Box::new(gtk::Orientation::Vertical, 14);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(20);
    root.set_margin_end(20);
    root.set_hexpand(true);
    root.set_vexpand(true);

    let title_row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    let title = gtk::Label::new(Some("历史 · History"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    title_row.append(&title);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    title_row.append(&sp);
    let count_chip = chip::chip("ALL · 全部 · 0", chip::Tone::Ink, true);
    title_row.append(&count_chip);
    title_row.append(&chip::chip("FILES · 文件", chip::Tone::Outline, true));
    title_row.append(&chip::chip("TEXT · 文字", chip::Tone::Outline, true));
    title_row.append(&chip::chip("IMAGE · 图片", chip::Tone::Outline, true));
    // 清空历史按钮 —— 仅真实模式生效，mock（screenshots）下禁用。
    let clear_btn = icon_btn::icon_btn("清空 · Clear", "清空全部历史记录", icon_btn::IconBtnTone::Danger);
    title_row.append(&clear_btn);
    root.append(&title_row);

    if let Some(h) = handle {
        let h_c = h.clone();
        clear_btn.connect_clicked(move |_| {
            h_c.clear_history();
        });
    } else {
        clear_btn.set_sensitive(false);
    }

    let today_div = ascii_divider::build("── TODAY · 今天 · 0 件 ──");
    root.append(&today_div.root);

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .build();
    let list = gtk::Box::new(gtk::Orientation::Vertical, 10);

    let empty_card = build_empty_card();
    list.append(&empty_card);

    scroll.set_child(Some(&list));
    root.append(&scroll);

    let initial: Vec<ViewHistoryRow> = match handle {
        Some(h) => h.history().iter().map(ViewHistoryRow::from_item).collect(),
        None => mock::history().iter().map(view_from_mock).collect(),
    };
    fill_history(&list, &empty_card, &initial);
    today_div.set_text(&format!("── TODAY · 今天 · {} 件 ──", initial.len()));
    count_chip.set_tooltip_text(Some(&format!("共 {} 条", initial.len())));

    if let Some(h) = handle {
        let list_c = list.clone();
        let empty_c = empty_card.clone();
        let today_lbl = today_div.label.clone();
        h.observe(h.engine.history_rx(), move |items| {
            let views: Vec<ViewHistoryRow> = items.iter().map(ViewHistoryRow::from_item).collect();
            fill_history(&list_c, &empty_c, &views);
            today_lbl.set_text(&format!("── TODAY · 今天 · {} 件 ──", views.len()));
        });
    }

    root.upcast()
}

fn fill_history(list: &gtk::Box, empty: &gtk::Box, rows: &[ViewHistoryRow]) {
    while let Some(child) = list.first_child() {
        list.remove(&child);
    }
    if rows.is_empty() {
        list.append(empty);
        return;
    }
    for r in rows {
        list.append(&history_card(r));
    }
}

fn history_card(item: &ViewHistoryRow) -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    card.add_css_class("meshdrop-card");

    let arrow_chip = match item.dir {
        mock::Dir::In  => chip::chip("↓ IN", chip::Tone::Sky,   true),
        mock::Dir::Out => chip::chip("↑ OUT", chip::Tone::Flame, true),
    };
    arrow_chip.set_valign(gtk::Align::Center);
    card.append(&arrow_chip);

    let body_col = gtk::Box::new(gtk::Orientation::Vertical, 6);
    body_col.set_hexpand(true);

    match &item.kind {
        ViewHistoryKind::Text(content) => {
            let lb = gtk::Label::new(Some(content));
            lb.set_halign(gtk::Align::Start);
            lb.set_wrap(true);
            lb.add_css_class("meshdrop-body");
            body_col.append(&lb);
        }
        ViewHistoryKind::File { name, size, ext, progress } => {
            body_col.append(&file_chip::chip(name, size, ext, *progress));
        }
    }
    card.append(&body_col);

    let meta_col = gtk::Box::new(gtk::Orientation::Vertical, 4);
    meta_col.set_valign(gtk::Align::Center);
    meta_col.set_halign(gtk::Align::End);

    let peer_row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    peer_row.set_halign(gtk::Align::End);
    let peer = gtk::Label::new(Some(&item.peer));
    peer.add_css_class("meshdrop-card-title");
    peer_row.append(&peer);
    meta_col.append(&peer_row);

    let time = gtk::Label::new(Some(&format!("今天 · {}", item.time)));
    time.add_css_class("meshdrop-meta");
    time.set_halign(gtk::Align::End);
    meta_col.append(&time);

    let (status_text, status_tone) = match item.status {
        mock::HistoryStatus::Done         => ("✓ 完成", chip::Tone::Lime),
        mock::HistoryStatus::Transferring => ("传输中…", chip::Tone::Flame),
        mock::HistoryStatus::Queued       => ("排队中", chip::Tone::Outline),
        mock::HistoryStatus::Failed       => ("失败", chip::Tone::Error),
    };
    let status_chip = chip::chip(status_text, status_tone, true);
    status_chip.set_halign(gtk::Align::End);
    meta_col.append(&status_chip);

    card.append(&meta_col);
    card
}

fn build_empty_card() -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Vertical, 6);
    card.add_css_class("meshdrop-card");
    let title = gtk::Label::new(Some("还没有传输记录"));
    title.add_css_class("meshdrop-card-title");
    title.set_halign(gtk::Align::Start);
    card.append(&title);
    let hint = gtk::Label::new(Some(
        "从 Discovery 选一台设备，把文件 / 文字推过去 —— 这里会出现。"));
    hint.add_css_class("meshdrop-muted");
    hint.set_halign(gtk::Align::Start);
    hint.set_wrap(true);
    card.append(&hint);
    card
}

fn view_from_mock(m: &mock::HistoryRow) -> ViewHistoryRow {
    let kind = match &m.kind {
        mock::HistoryKind::Text { content } => ViewHistoryKind::Text((*content).to_string()),
        mock::HistoryKind::File { name, size, ext, progress } => ViewHistoryKind::File {
            name: (*name).to_string(), size: (*size).to_string(),
            ext: (*ext).to_string(), progress: *progress,
        },
        mock::HistoryKind::Image { count } => ViewHistoryKind::Text(format!("{} 张图片", count)),
    };
    ViewHistoryRow {
        id: m.id.to_string(),
        dir: m.dir,
        peer: m.peer.to_string(),
        time: m.time.to_string(),
        kind,
        status: m.status,
    }
}
