//! Chat 页：选第一个 LAN 设备作为对话目标，列出与该设备的历史，composer 真发文本。
//! 没设备时显示空态。

use crate::components::{ascii_divider, avatar, chip, icon_btn, msg_bubble};
use crate::engine_bridge::AppHandle;
use crate::mock;
use crate::view::{initials_of, palette_color};
use adw::prelude::*;
use meshdrop_core::history::{HistoryItem, HistoryKind, TransferDirection};
use meshdrop_core::Device;
use std::cell::RefCell;
use std::rc::Rc;

pub fn build(handle: Option<&Rc<AppHandle>>) -> gtk::Widget {
    let root = gtk::Box::new(gtk::Orientation::Vertical, 0);
    root.set_hexpand(true);
    root.set_vexpand(true);

    let head_holder = gtk::Box::new(gtk::Orientation::Vertical, 0);
    root.append(&head_holder);

    let div = ascii_divider::build("── CONVERSATION · 0 条 ──");
    div.root.set_margin_start(20);
    div.root.set_margin_end(20);
    root.append(&div.root);

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .hexpand(true)
        .build();
    let flow = gtk::Box::new(gtk::Orientation::Vertical, 8);
    flow.set_margin_top(8);
    flow.set_margin_bottom(8);
    flow.set_margin_start(20);
    flow.set_margin_end(20);
    scroll.set_child(Some(&flow));
    root.append(&scroll);

    let composer = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    composer.add_css_class("meshdrop-composer");
    let entry = gtk::Entry::builder()
        .placeholder_text("写一条消息… · Enter 发送")
        .hexpand(true)
        .build();
    composer.append(&entry);
    composer.append(&icon_btn::icon_btn("📎", "附件", icon_btn::IconBtnTone::Default));
    composer.append(&icon_btn::icon_btn("📋", "粘贴剪贴板", icon_btn::IconBtnTone::Default));
    let send_btn = icon_btn::icon_btn("发送", "发送（Enter）", icon_btn::IconBtnTone::Accent);
    composer.append(&send_btn);
    root.append(&composer);

    let target_peer: Rc<RefCell<Option<Device>>> = Rc::new(RefCell::new(None));

    match handle {
        Some(h) => {
            render_real_header(&head_holder, h, &target_peer);
            render_real_messages(&flow, h, &target_peer);
            div.set_text(&format!("── CONVERSATION · {} 条 ──",
                count_for_peer(h, &target_peer.borrow())));

            // 订阅 device 变化：当目标 peer 离线 / 新增时刷新 header
            let head_c = head_holder.clone();
            let h_c = h.clone();
            let target_c = target_peer.clone();
            h.observe(h.engine.devices_rx(), move |_| {
                render_real_header(&head_c, &h_c, &target_c);
            });

            // 订阅 history：每次更新刷消息流
            let flow_c = flow.clone();
            let h_c2 = h.clone();
            let target_c2 = target_peer.clone();
            let div_c = div.label.clone();
            h.observe(h.engine.history_rx(), move |_| {
                render_real_messages(&flow_c, &h_c2, &target_c2);
                div_c.set_text(&format!("── CONVERSATION · {} 条 ──",
                    count_for_peer(&h_c2, &target_c2.borrow())));
            });

            // composer 回调
            let entry_c = entry.clone();
            let h_c3 = h.clone();
            let target_c3 = target_peer.clone();
            let send_cb = move || {
                let text = entry_c.text().to_string();
                if text.is_empty() { return; }
                if let Some(peer) = target_c3.borrow().clone() {
                    h_c3.send_text(peer, text);
                    entry_c.set_text("");
                } else {
                    log::warn!("chat: 没有可发送的目标设备");
                }
            };
            let send_cb = Rc::new(send_cb);
            let s = send_cb.clone();
            send_btn.connect_clicked(move |_| s());
            let s2 = send_cb.clone();
            entry.connect_activate(move |_| s2());
        }
        None => render_mock(&head_holder, &flow, &div.label),
    }

    root.upcast()
}

fn render_real_header(holder: &gtk::Box, h: &Rc<AppHandle>, target: &Rc<RefCell<Option<Device>>>) {
    while let Some(child) = holder.first_child() {
        holder.remove(&child);
    }
    let devs = h.devices();
    let peer = devs.first().cloned();
    *target.borrow_mut() = peer.clone();

    let head = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    head.set_margin_top(16);
    head.set_margin_bottom(8);
    head.set_margin_start(20);
    head.set_margin_end(20);

    match peer {
        Some(d) => {
            let color = palette_color(0).to_string();
            let initials = initials_of(&d.name);
            head.append(&avatar::avatar(&initials, &color, 44, avatar::Ring::Lime));
            let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
            col.set_hexpand(true);
            let nm = gtk::Label::new(Some(&d.name));
            nm.add_css_class("meshdrop-section");
            nm.set_halign(gtk::Align::Start);
            col.append(&nm);
            let ip = d.host.clone().unwrap_or_default();
            let meta = gtk::Label::new(Some(&format!("Linux · {} · 指纹 {}", ip,
                crate::view::short_fingerprint(&d.fingerprint))));
            meta.add_css_class("meshdrop-meta");
            col.append(&meta);
            head.append(&col);
            head.append(&chip::chip_with_dot("E2E · LAN", chip::Tone::Mute, "#A8C800"));
        }
        None => {
            let lb = gtk::Label::new(Some("没有可对话的设备"));
            lb.add_css_class("meshdrop-section");
            lb.set_halign(gtk::Align::Start);
            head.append(&lb);
        }
    }
    holder.append(&head);
}

fn render_real_messages(flow: &gtk::Box, h: &Rc<AppHandle>, target: &Rc<RefCell<Option<Device>>>) {
    while let Some(child) = flow.first_child() {
        flow.remove(&child);
    }
    let Some(peer) = target.borrow().clone() else {
        return;
    };
    let history = h.history();
    let mut items: Vec<&HistoryItem> = history.iter()
        .filter(|h| h.peer.id == peer.id).collect();
    items.reverse();
    for it in items {
        flow.append(&item_bubble(it));
    }
}

fn item_bubble(it: &HistoryItem) -> gtk::Box {
    let side = match it.direction {
        TransferDirection::Outgoing => mock::Dir::Out,
        TransferDirection::Incoming => mock::Dir::In,
    };
    let body = match &it.kind {
        HistoryKind::Text(t) => mock::ChatBody::Text(string_to_static(t)),
        HistoryKind::File { name, size, .. } => mock::ChatBody::File {
            name: string_to_static(name),
            size: string_to_static(&meshdrop_core::history::format_bytes(*size)),
            ext: string_to_static(name.rsplit_once('.').map(|(_, e)| e).unwrap_or("file")),
        },
    };
    let msg = mock::ChatMsg {
        side,
        time: string_to_static(&it.created_at.hh_mm_ss()),
        body,
        delivered: true,
    };
    msg_bubble::bubble(&msg)
}

// `msg_bubble::bubble` 要 `&'static str` 字段；把 String 永久泄漏成静态串。
// 数量上聊天历史不会无界增长（用户长会话时仍可接受），如有担心未来可换 Cow。
fn string_to_static(s: &str) -> &'static str {
    Box::leak(s.to_string().into_boxed_str())
}

fn count_for_peer(h: &Rc<AppHandle>, peer: &Option<Device>) -> usize {
    let Some(p) = peer else { return 0 };
    h.history().iter().filter(|item| item.peer.id == p.id).count()
}

fn render_mock(head: &gtk::Box, flow: &gtk::Box, div_label: &gtk::Label) {
    let peer = mock::devices()[mock::CHAT_PEER_INDEX].clone();
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    row.set_margin_top(16);
    row.set_margin_bottom(8);
    row.set_margin_start(20);
    row.set_margin_end(20);
    row.append(&avatar::avatar(peer.initials, peer.color, 44, avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let nm = gtk::Label::new(Some(peer.name));
    nm.add_css_class("meshdrop-section");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let meta = gtk::Label::new(Some(&format!("{} · {} · {} ms · 指纹 {}",
        peer.os, peer.ip, peer.rtt_ms, peer.fp_short)));
    meta.add_css_class("meshdrop-meta");
    col.append(&meta);
    row.append(&col);
    row.append(&chip::chip_with_dot("E2E · TRUSTED", chip::Tone::Mute, "#A8C800"));
    head.append(&row);

    for msg in mock::chat_with_mengxi() {
        flow.append(&msg_bubble::bubble(&msg));
    }
    div_label.set_text(&format!("── TODAY · 今天 · {} 条 ──", mock::chat_with_mengxi().len()));
}
