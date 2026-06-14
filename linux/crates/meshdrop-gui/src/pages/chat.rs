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

    let div = ascii_divider::build(&t!("chat.conversation_divider", count = 0));
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
        .placeholder_text(t!("chat.composer_placeholder").as_ref())
        .hexpand(true)
        .build();
    composer.append(&entry);
    // mono glyph 代替 emoji：⊕ 附件、▤ 粘贴剪贴板（与导航 / TUI glyph 体系一致）。
    let attach_btn = icon_btn::icon_btn("⊕", &t!("chat.attach_tip"), icon_btn::IconBtnTone::Default);
    let paste_btn = icon_btn::icon_btn("▤", &t!("chat.paste_tip"), icon_btn::IconBtnTone::Default);
    composer.append(&attach_btn);
    composer.append(&paste_btn);
    let send_btn = icon_btn::icon_btn(&t!("common.send"), &t!("chat.send_tip"), icon_btn::IconBtnTone::Accent);
    composer.append(&send_btn);
    root.append(&composer);

    let target_peer: Rc<RefCell<Option<Device>>> = Rc::new(RefCell::new(None));

    match handle {
        Some(h) => {
            render_real_header(&head_holder, h, &target_peer);
            render_real_messages(&flow, h, &target_peer);
            div.set_text(&t!("chat.conversation_divider",
                count = count_for_peer(h, &target_peer.borrow())));

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
                div_c.set_text(&t!("chat.conversation_divider",
                    count = count_for_peer(&h_c2, &target_c2.borrow())));
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

            // 附件：FileDialog 选文件 → engine.send_file(当前目标设备)。
            let h_attach = h.clone();
            let target_attach = target_peer.clone();
            attach_btn.connect_clicked(move |btn| {
                let Some(peer) = target_attach.borrow().clone() else {
                    log::warn!("chat: 没有可发送的目标设备");
                    return;
                };
                let parent = btn.root().and_then(|r| r.downcast::<gtk::Window>().ok());
                let dialog = gtk::FileDialog::builder().title(t!("chat.pick_file_title").as_ref()).build();
                let h_pick = h_attach.clone();
                dialog.open(parent.as_ref(), gtk::gio::Cancellable::NONE, move |res| {
                    if let Ok(file) = res {
                        if let Some(path) = file.path() {
                            h_pick.send_file(peer.clone(), path);
                        }
                    }
                });
            });

            // 粘贴剪贴板：读系统剪贴板文本填入 entry（不自动发送，交用户确认）。
            let entry_paste = entry.clone();
            paste_btn.connect_clicked(move |btn| {
                let clipboard = btn.display().clipboard();
                let entry_c = entry_paste.clone();
                clipboard.read_text_async(gtk::gio::Cancellable::NONE, move |res| {
                    if let Ok(Some(text)) = res {
                        entry_c.set_text(text.as_str());
                    }
                });
            });
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
            let meta = gtk::Label::new(Some(&*t!("chat.header_meta", ip = ip,
                fp = crate::view::short_fingerprint(&d.fingerprint))));
            meta.add_css_class("meshdrop-meta");
            col.append(&meta);
            head.append(&col);
            head.append(&chip::chip_with_dot(&t!("chat.peer_chip"), chip::Tone::Mute, crate::color::LIME_DEEP));
        }
        None => {
            let lb = gtk::Label::new(Some(&*t!("chat.no_peer")));
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
    use msg_bubble::{BubbleBody, BubbleView};
    let side = match it.direction {
        TransferDirection::Outgoing => mock::Dir::Out,
        TransferDirection::Incoming => mock::Dir::In,
    };
    // 这一帧所需的临时 String 在本函数内存活到 bubble_view 调用结束即可，无需 leak。
    let time = it.created_at.hh_mm_ss();
    match &it.kind {
        HistoryKind::Text(t) => {
            let view = BubbleView { side, time: &time, body: BubbleBody::Text(t), delivered: true };
            msg_bubble::bubble_view(&view)
        }
        HistoryKind::File { name, size, .. } => {
            let size_str = meshdrop_core::history::format_bytes(*size);
            let ext = name.rsplit_once('.').map(|(_, e)| e).unwrap_or("file");
            let view = BubbleView {
                side, time: &time,
                body: BubbleBody::File { name, size: &size_str, ext },
                delivered: true,
            };
            msg_bubble::bubble_view(&view)
        }
    }
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
    let meta = gtk::Label::new(Some(&*t!("chat.header_meta_mock",
        os = peer.os, ip = peer.ip, rtt = peer.rtt_ms, fp = peer.fp_short)));
    meta.add_css_class("meshdrop-meta");
    col.append(&meta);
    row.append(&col);
    row.append(&chip::chip_with_dot(&t!("chat.peer_chip_trusted"), chip::Tone::Mute, crate::color::LIME_DEEP));
    head.append(&row);

    for msg in mock::chat_with_mengxi() {
        flow.append(&msg_bubble::bubble(&msg));
    }
    div_label.set_text(&t!("chat.today_divider", count = mock::chat_with_mengxi().len()));
}
