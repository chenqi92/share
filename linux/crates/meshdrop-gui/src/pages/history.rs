//! History / Library 页：按日分组的图/文件/文字 grid。

use crate::components::{ascii_divider, chip, file_chip, photo};
use crate::mock::{self, HistoryKind};
use adw::prelude::*;

pub fn build() -> gtk::Widget {
    let root = gtk::Box::new(gtk::Orientation::Vertical, 14);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(20);
    root.set_margin_end(20);
    root.set_hexpand(true);
    root.set_vexpand(true);

    // title
    let title_row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    let title = gtk::Label::new(Some("历史 · History"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    title_row.append(&title);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    title_row.append(&sp);
    title_row.append(&chip::chip("ALL · 全部 · 6", chip::Tone::Ink, true));
    title_row.append(&chip::chip("FILES · 文件", chip::Tone::Outline, true));
    title_row.append(&chip::chip("TEXT · 文字", chip::Tone::Outline, true));
    title_row.append(&chip::chip("IMAGE · 图片", chip::Tone::Outline, true));
    root.append(&title_row);

    root.append(&ascii_divider::divider("── TODAY · 今天 · 6 件 ──"));

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .build();
    let list = gtk::Box::new(gtk::Orientation::Vertical, 10);

    for item in mock::history() {
        list.append(&history_card(&item));
    }
    scroll.set_child(Some(&list));
    root.append(&scroll);

    root.upcast()
}

fn history_card(item: &mock::HistoryRow) -> gtk::Box {
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
        HistoryKind::Text { content } => {
            let lb = gtk::Label::new(Some(content));
            lb.set_halign(gtk::Align::Start);
            lb.set_wrap(true);
            lb.add_css_class("meshdrop-body");
            body_col.append(&lb);
        }
        HistoryKind::File { name, size, ext, progress } => {
            body_col.append(&file_chip::chip(name, size, ext, *progress));
        }
        HistoryKind::Image { count } => {
            let row_imgs = gtk::Box::new(gtk::Orientation::Horizontal, 6);
            for i in 0..(*count).min(3) {
                let p = photo::photo(96, 64, 30.0 + i as f64 * 110.0);
                row_imgs.append(&p);
            }
            body_col.append(&row_imgs);
            let lb = gtk::Label::new(Some(&format!("{} 张图片", count)));
            lb.add_css_class("meshdrop-meta");
            lb.set_halign(gtk::Align::Start);
            body_col.append(&lb);
        }
    }
    card.append(&body_col);

    // 右侧：peer + time + status
    let meta_col = gtk::Box::new(gtk::Orientation::Vertical, 4);
    meta_col.set_valign(gtk::Align::Center);
    meta_col.set_halign(gtk::Align::End);

    let peer_row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    peer_row.set_halign(gtk::Align::End);
    let peer = gtk::Label::new(Some(item.peer));
    peer.add_css_class("meshdrop-card-title");
    peer_row.append(&peer);
    meta_col.append(&peer_row);

    let time = gtk::Label::new(Some(&format!("今天 · {}", item.time)));
    time.add_css_class("meshdrop-meta");
    time.set_halign(gtk::Align::End);
    meta_col.append(&time);

    let status_text = match item.status {
        mock::HistoryStatus::Done         => "✓ 完成",
        mock::HistoryStatus::Transferring => "传输中…",
        mock::HistoryStatus::Queued       => "排队中",
        mock::HistoryStatus::Failed       => "失败",
    };
    let status_tone = match item.status {
        mock::HistoryStatus::Done         => chip::Tone::Lime,
        mock::HistoryStatus::Transferring => chip::Tone::Flame,
        mock::HistoryStatus::Queued       => chip::Tone::Outline,
        mock::HistoryStatus::Failed       => chip::Tone::Error,
    };
    let status_chip = chip::chip(status_text, status_tone, true);
    status_chip.set_halign(gtk::Align::End);
    meta_col.append(&status_chip);

    card.append(&meta_col);
    card
}
