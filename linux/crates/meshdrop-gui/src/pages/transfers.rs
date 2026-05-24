//! Transfers 页：速度图 + filter chips + 任务列表（按 engine.history 实时刷新）。

use crate::components::{ascii_divider, chip, speed_chart, transfer_row};
use crate::engine_bridge::AppHandle;
use crate::mock;
use crate::view::ViewTransferRow;
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
    let title = gtk::Label::new(Some("传输 · Transfers"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    title_row.append(&title);
    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    title_row.append(&spacer);
    title_row.append(&chip::chip("LIVE · 实时", chip::Tone::Flame, true));
    root.append(&title_row);

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

    let active_div = ascii_divider::build("── ACTIVE · 进行中 · 0 件 ──");
    root.append(&active_div.root);

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .build();
    let list = gtk::Box::new(gtk::Orientation::Vertical, 10);
    let empty_card = empty_card();
    list.append(&empty_card);
    scroll.set_child(Some(&list));
    root.append(&scroll);

    let me_name = handle.map(|h| h.engine.display_name.clone())
        .unwrap_or_else(|| mock::me().name.to_string());
    let initial: Vec<ViewTransferRow> = match handle {
        Some(h) => h.history().iter()
            .filter_map(|h| ViewTransferRow::from_history(h, &me_name)).collect(),
        None => mock::transfers().iter().map(|t| ViewTransferRow {
            name: t.name.to_string(), size: t.size.to_string(), ext: t.ext.to_string(),
            from: t.from.to_string(), to: t.to.to_string(),
            progress: t.progress, state: t.state,
            speed: t.speed.map(str::to_string), eta: t.eta.map(str::to_string),
        }).collect(),
    };
    fill_transfers(&list, &empty_card, &initial);
    active_div.set_text(&format!("── ACTIVE · 进行中 · {} 件 ──",
        initial.iter().filter(|t| !is_terminal(t)).count()));

    if let Some(h) = handle {
        let list_c = list.clone();
        let empty_c = empty_card.clone();
        let div_lbl = active_div.label.clone();
        let me_name_c = me_name.clone();
        h.observe(h.engine.history_rx(), move |items| {
            let views: Vec<ViewTransferRow> = items.iter()
                .filter_map(|h| ViewTransferRow::from_history(h, &me_name_c)).collect();
            let active = views.iter().filter(|t| !is_terminal(t)).count();
            div_lbl.set_text(&format!("── ACTIVE · 进行中 · {} 件 ──", active));
            fill_transfers(&list_c, &empty_c, &views);
        });
    }

    root.upcast()
}

fn fill_transfers(list: &gtk::Box, empty: &gtk::Box, rows: &[ViewTransferRow]) {
    while let Some(child) = list.first_child() {
        list.remove(&child);
    }
    if rows.is_empty() {
        list.append(empty);
        return;
    }
    for r in rows {
        list.append(&transfer_row::row(r));
    }
}

fn is_terminal(t: &ViewTransferRow) -> bool {
    matches!(t.state,
        crate::mock::TransferState::Done
        | crate::mock::TransferState::Failed
        | crate::mock::TransferState::Queued)
}

fn empty_card() -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Vertical, 6);
    card.add_css_class("meshdrop-card");
    let t = gtk::Label::new(Some("当前没有进行中的传输"));
    t.add_css_class("meshdrop-card-title");
    t.set_halign(gtk::Align::Start);
    card.append(&t);
    let h = gtk::Label::new(Some("拖文件到 MeshDrop 窗口或在 Discovery 选设备 → 发送。"));
    h.add_css_class("meshdrop-muted");
    h.set_halign(gtk::Align::Start);
    h.set_wrap(true);
    card.append(&h);
    card
}
