//! Clipboard 页：显式把一段文字推给第一台 LAN 设备 + 查看收到的剪贴板推送。
//! handle.is_some() 时订阅 engine.clipboard_rx 实时刷新；否则空态（screenshots 模式）。
//! 协议见 protocol/messages.md §0x11 —— 由用户点一下才发，不是后台静默同步。

use crate::components::{ascii_divider, chip, icon_btn};
use crate::engine_bridge::AppHandle;
use adw::prelude::*;
use meshdrop_core::ClipboardEntry;
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
    let title = gtk::Label::new(Some(&*t!("clipboard.title")));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    title_row.append(&title);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    title_row.append(&sp);
    let count_chip = chip::chip(&t!("clipboard.inbox_chip", count = 0), chip::Tone::Ink, true);
    title_row.append(&count_chip);
    root.append(&title_row);

    // ── 推送编辑器 ──
    let composer = gtk::Box::new(gtk::Orientation::Vertical, 8);
    composer.add_css_class("meshdrop-card");

    let target_lbl = gtk::Label::new(Some(&*t!("clipboard.push_to_none")));
    target_lbl.add_css_class("meshdrop-meta");
    target_lbl.set_halign(gtk::Align::Start);
    composer.append(&target_lbl);

    let text_scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .min_content_height(80)
        .build();
    let textview = gtk::TextView::new();
    textview.set_wrap_mode(gtk::WrapMode::WordChar);
    textview.add_css_class("meshdrop-body");
    text_scroll.set_child(Some(&textview));
    composer.append(&text_scroll);
    let buffer = textview.buffer();

    let btn_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    let read_btn = icon_btn::icon_btn(&t!("clipboard.read_btn"), &t!("clipboard.read_btn_tip"), icon_btn::IconBtnTone::Default);
    btn_row.append(&read_btn);
    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    btn_row.append(&spacer);
    let push_btn = icon_btn::icon_btn(&t!("clipboard.push_btn"), &t!("clipboard.push_btn_tip"), icon_btn::IconBtnTone::Accent);
    btn_row.append(&push_btn);
    composer.append(&btn_row);
    root.append(&composer);

    // 读取系统剪贴板 → 填入编辑器
    let buffer_r = buffer.clone();
    read_btn.connect_clicked(move |_| {
        if let Some(display) = gtk::gdk::Display::default() {
            let cb = display.clipboard();
            let buf = buffer_r.clone();
            cb.read_text_async(gtk::gio::Cancellable::NONE, move |res| {
                if let Ok(Some(text)) = res {
                    buf.set_text(text.as_str());
                }
            });
        }
    });

    let div = ascii_divider::build(&t!("clipboard.inbox_divider", count = 0));
    root.append(&div.root);

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .build();
    let list = gtk::Box::new(gtk::Orientation::Vertical, 10);
    let empty_card = build_empty_card();
    list.append(&empty_card);
    scroll.set_child(Some(&list));
    root.append(&scroll);

    if let Some(h) = handle {
        // 推送：取当前第一台设备作为目标
        let h_push = h.clone();
        let buffer_p = buffer.clone();
        push_btn.connect_clicked(move |_| {
            let (start, end) = buffer_p.bounds();
            let content = buffer_p.text(&start, &end, false).trim().to_string();
            if content.is_empty() { return; }
            let Some(peer) = h_push.devices().into_iter().next() else {
                log::warn!("clipboard: 没有可推送的目标设备");
                return;
            };
            let kind = clip_kind(&content);
            h_push.push_clipboard(peer, content, kind);
            buffer_p.set_text("");
        });

        // 目标设备标签随 devices 变化刷新
        let target_c = target_lbl.clone();
        let h_dev = h.clone();
        h.observe(h.engine.devices_rx(), move |_| {
            match h_dev.devices().into_iter().next() {
                Some(d) => target_c.set_text(&t!("clipboard.push_to", name = d.name)),
                None => target_c.set_text(&t!("clipboard.push_to_none")),
            }
        });

        // 收件列表随 clipboard_rx 刷新
        let list_c = list.clone();
        let empty_c = empty_card.clone();
        let div_lbl = div.label.clone();
        let count_c = count_chip.clone();
        h.observe(h.engine.clipboard_rx(), move |entries| {
            fill_inbox(&list_c, &empty_c, entries);
            div_lbl.set_text(&t!("clipboard.inbox_divider", count = entries.len()));
            count_c.set_tooltip_text(Some(&*t!("clipboard.total_count", count = entries.len())));
        });
    }

    root.upcast()
}

fn fill_inbox(list: &gtk::Box, empty: &gtk::Box, entries: &[ClipboardEntry]) {
    while let Some(child) = list.first_child() {
        list.remove(&child);
    }
    if entries.is_empty() {
        list.append(empty);
        return;
    }
    for e in entries {
        list.append(&inbox_card(e));
    }
}

fn inbox_card(e: &ClipboardEntry) -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Vertical, 6);
    card.add_css_class("meshdrop-card");

    let head = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    let peer = gtk::Label::new(Some(&format!("↓ {}", e.peer_name)));
    peer.add_css_class("meshdrop-card-title");
    peer.set_halign(gtk::Align::Start);
    head.append(&peer);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    head.append(&sp);
    let tone = match e.kind.as_str() {
        "link" => chip::Tone::Sky,
        "code" => chip::Tone::Flame,
        _ => chip::Tone::Outline,
    };
    head.append(&chip::chip(&e.kind.to_uppercase(), tone, true));
    card.append(&head);

    let body = gtk::Label::new(Some(&e.content));
    body.add_css_class(if e.kind == "code" { "meshdrop-mono" } else { "meshdrop-body" });
    body.set_halign(gtk::Align::Start);
    body.set_wrap(true);
    body.set_selectable(true);
    card.append(&body);

    let actions = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    let sp2 = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp2.set_hexpand(true);
    actions.append(&sp2);
    let copy_btn = icon_btn::icon_btn(&t!("common.copy"), &t!("clipboard.copy_tip"), icon_btn::IconBtnTone::Default);
    let content = e.content.clone();
    copy_btn.connect_clicked(move |_| {
        if let Some(display) = gtk::gdk::Display::default() {
            display.clipboard().set_text(&content);
        }
    });
    actions.append(&copy_btn);
    card.append(&actions);

    card
}

fn build_empty_card() -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Vertical, 6);
    card.add_css_class("meshdrop-card");
    let title = gtk::Label::new(Some(&*t!("clipboard.empty_title")));
    title.add_css_class("meshdrop-card-title");
    title.set_halign(gtk::Align::Start);
    card.append(&title);
    let hint = gtk::Label::new(Some(&*t!("clipboard.empty_hint")));
    hint.add_css_class("meshdrop-muted");
    hint.set_halign(gtk::Align::Start);
    hint.set_wrap(true);
    card.append(&hint);
    card
}

/// 按内容粗判剪贴板 kind（与各端同口径）。
fn clip_kind(content: &str) -> String {
    let t = content.trim();
    if (t.starts_with("http://") || t.starts_with("https://")) && !t.chars().any(|c| c.is_whitespace()) {
        return "link".to_string();
    }
    if t.contains('\n') && t.chars().any(|c| "{};=<>/".contains(c)) {
        return "code".to_string();
    }
    "text".to_string()
}
