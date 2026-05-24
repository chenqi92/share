//! Transfers 页：速度图 + filter chips + 任务列表。

use crate::components::{ascii_divider, chip, speed_chart, transfer_row};
use crate::mock;
use adw::prelude::*;

pub fn build() -> gtk::Widget {
    let root = gtk::Box::new(gtk::Orientation::Vertical, 14);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(20);
    root.set_margin_end(20);
    root.set_hexpand(true);
    root.set_vexpand(true);

    // 标题行
    let title_row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    let title = gtk::Label::new(Some("传输 · Transfers"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    title_row.append(&title);
    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    title_row.append(&spacer);
    title_row.append(&chip::chip("UP 8.4 MB/s", chip::Tone::Flame, true));
    title_row.append(&chip::chip("DOWN 11.7 MB/s", chip::Tone::Sky, true));
    root.append(&title_row);

    // 速度图卡
    let chart_card = gtk::Box::new(gtk::Orientation::Vertical, 8);
    chart_card.add_css_class("meshdrop-card");
    let head_row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    let head = gtk::Label::new(Some("当前会话速度"));
    head.add_css_class("meshdrop-card-title");
    head.set_halign(gtk::Align::Start);
    head_row.append(&head);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    head_row.append(&sp);
    let legend_up = gtk::Label::new(Some("↑ 上行"));
    legend_up.add_css_class("meshdrop-meta");
    legend_up.add_css_class("meshdrop-legend-up");
    let legend_down = gtk::Label::new(Some("↓ 下行"));
    legend_down.add_css_class("meshdrop-meta");
    legend_down.add_css_class("meshdrop-legend-down");
    head_row.append(&legend_up);
    head_row.append(&legend_down);
    chart_card.append(&head_row);

    let chart = speed_chart::chart(mock::UPLOAD_BARS, mock::DOWNLOAD_BARS, 600, 130);
    chart_card.append(&chart);
    root.append(&chart_card);

    // filter chips
    let filter_row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    let chips = [
        ("全部 · ALL", chip::Tone::Ink),
        ("进行中 · ACTIVE", chip::Tone::Outline),
        ("已完成 · DONE", chip::Tone::Outline),
        ("失败 · FAILED", chip::Tone::Outline),
    ];
    for (label, tone) in chips {
        let c = chip::chip(label, tone, true);
        filter_row.append(&c);
    }
    root.append(&filter_row);

    root.append(&ascii_divider::divider("── ACTIVE · 进行中 · 3 件 ──"));

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .build();
    let list = gtk::Box::new(gtk::Orientation::Vertical, 10);
    for item in mock::transfers() {
        list.append(&transfer_row::row(&item));
    }
    scroll.set_child(Some(&list));
    root.append(&scroll);

    root.upcast()
}
