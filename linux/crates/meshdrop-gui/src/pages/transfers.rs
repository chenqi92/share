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
    let head = gtk::Label::new(Some("当前会话 · SESSION"));
    head.add_css_class("meshdrop-card-title");
    head.set_halign(gtk::Align::Start);
    head_row.append(&head);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    head_row.append(&sp);
    let legend_up = gtk::Label::new(Some("↑ —"));
    legend_up.add_css_class("meshdrop-meta");
    legend_up.add_css_class("meshdrop-legend-up");
    let legend_down = gtk::Label::new(Some("↓ —"));
    legend_down.add_css_class("meshdrop-meta");
    legend_down.add_css_class("meshdrop-legend-down");
    let legend_total = gtk::Label::new(Some("· 0 B 已传输"));
    legend_total.add_css_class("meshdrop-meta");
    head_row.append(&legend_up);
    head_row.append(&legend_down);
    head_row.append(&legend_total);
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

    // history 与 metrics 都用来构 ViewTransferRow；任一变化都重建 list 行。
    let build = {
        let me_name = me_name.clone();
        move |handle: Option<&Rc<AppHandle>>| -> Vec<ViewTransferRow> {
            match handle {
                Some(h) => {
                    let history = h.history();
                    let metrics = h.engine.transfer_metrics_rx().borrow().clone();
                    history.iter()
                        .filter_map(|item| ViewTransferRow::from_history_with_metrics(
                            item, &me_name, metrics.get(&item.id)))
                        .collect()
                }
                None => mock::transfers().iter().map(|t| ViewTransferRow {
                    id: uuid::Uuid::nil(),
                    name: t.name.to_string(), size: t.size.to_string(), ext: t.ext.to_string(),
                    from: t.from.to_string(), to: t.to.to_string(),
                    progress: t.progress, state: t.state,
                    speed: t.speed.map(str::to_string), eta: t.eta.map(str::to_string),
                    saved_path: None,
                    fail_reason: None,
                }).collect(),
            }
        }
    };

    let initial = build(handle);
    fill_transfers(&list, &empty_card, &initial, handle.cloned());
    active_div.set_text(&format!("── ACTIVE · 进行中 · {} 件 ──",
        initial.iter().filter(|t| !is_terminal(t)).count()));

    if let Some(h) = handle {
        // history → 重建
        {
            let list_c = list.clone();
            let empty_c = empty_card.clone();
            let div_lbl = active_div.label.clone();
            let build_c = build.clone();
            let handle_c = h.clone();
            h.observe(h.engine.history_rx(), move |_items| {
                let views = build_c(Some(&handle_c));
                let active = views.iter().filter(|t| !is_terminal(t)).count();
                div_lbl.set_text(&format!("── ACTIVE · 进行中 · {} 件 ──", active));
                fill_transfers(&list_c, &empty_c, &views, Some(handle_c.clone()));
            });
        }
        // metrics → 重建（速率 / ETA 刷新）
        {
            let list_c = list.clone();
            let empty_c = empty_card.clone();
            let build_c = build.clone();
            let handle_c = h.clone();
            h.observe(h.engine.transfer_metrics_rx(), move |_m| {
                let views = build_c(Some(&handle_c));
                fill_transfers(&list_c, &empty_c, &views, Some(handle_c.clone()));
            });
        }
        // session legend：history + metrics 任一变都重新汇总
        {
            let legend_up = legend_up.clone();
            let legend_down = legend_down.clone();
            let legend_total = legend_total.clone();
            let handle_c = h.clone();
            let refresh = move || refresh_session_legend(&handle_c, &legend_up, &legend_down, &legend_total);
            refresh();
            let refresh_clone = refresh.clone();
            h.observe(h.engine.history_rx(), move |_| refresh_clone());
            h.observe(h.engine.transfer_metrics_rx(), move |_| refresh());
        }
    }

    root.upcast()
}

fn refresh_session_legend(
    handle: &Rc<AppHandle>,
    legend_up: &gtk::Label,
    legend_down: &gtk::Label,
    legend_total: &gtk::Label,
) {
    use meshdrop_core::history::{HistoryKind, TransferDirection, TransferStatus};
    let history = handle.history();
    let metrics = handle.engine.transfer_metrics_rx().borrow().clone();

    let mut total: u64 = 0;
    let mut up_bps: f64 = 0.0;
    let mut down_bps: f64 = 0.0;
    for h in &history {
        if let HistoryKind::File { size, .. } = &h.kind {
            total += *size;
        }
        if matches!(h.status, TransferStatus::Transferring { .. }) {
            if let Some(m) = metrics.get(&h.id) {
                match h.direction {
                    TransferDirection::Outgoing => up_bps += m.bytes_per_sec,
                    TransferDirection::Incoming => down_bps += m.bytes_per_sec,
                }
            }
        }
    }
    legend_up.set_text(&format!("↑ {}", format_bps(up_bps)));
    legend_down.set_text(&format!("↓ {}", format_bps(down_bps)));
    legend_total.set_text(&format!("· {} 已传输", meshdrop_core::history::format_bytes(total)));
}

fn format_bps(bps: f64) -> String {
    if bps <= 1.0 { return "—".into(); }
    if bps < 1024.0 { return format!("{:.0} B/s", bps); }
    if bps < 1024.0 * 1024.0 { return format!("{:.1} KB/s", bps / 1024.0); }
    format!("{:.1} MB/s", bps / 1024.0 / 1024.0)
}

fn fill_transfers(list: &gtk::Box, empty: &gtk::Box, rows: &[ViewTransferRow], handle: Option<Rc<AppHandle>>) {
    while let Some(child) = list.first_child() {
        list.remove(&child);
    }
    if rows.is_empty() {
        list.append(empty);
        return;
    }
    for r in rows {
        let cancel_cb: Option<Box<dyn Fn(uuid::Uuid) + 'static>> = handle.as_ref().map(|h| {
            let h = h.clone();
            Box::new(move |hid: uuid::Uuid| h.engine.cancel_transfer(hid)) as Box<dyn Fn(uuid::Uuid) + 'static>
        });
        let retry_cb: Option<Box<dyn Fn(uuid::Uuid) + 'static>> = handle.as_ref().map(|h| {
            let h = h.clone();
            Box::new(move |hid: uuid::Uuid| h.engine.retry_transfer(hid)) as Box<dyn Fn(uuid::Uuid) + 'static>
        });
        list.append(&transfer_row::row(r, cancel_cb, retry_cb));
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
