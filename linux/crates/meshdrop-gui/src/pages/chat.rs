//! Chat 页：与某设备对话流 + composer + (drag overlay 由父层提供)。

use crate::components::{ascii_divider, avatar, chip, icon_btn, msg_bubble};
use crate::mock;
use adw::prelude::*;

pub fn build() -> gtk::Widget {
    let root = gtk::Box::new(gtk::Orientation::Vertical, 0);
    root.set_hexpand(true);
    root.set_vexpand(true);

    let peer = mock::devices()[mock::CHAT_PEER_INDEX].clone();

    // 顶部 peer 卡片
    let head = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    head.set_margin_top(16);
    head.set_margin_bottom(8);
    head.set_margin_start(20);
    head.set_margin_end(20);

    head.append(&avatar::avatar(peer.initials, peer.color, 44, avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let nm = gtk::Label::new(Some(peer.name));
    nm.add_css_class("meshdrop-section");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let sub_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    let meta = gtk::Label::new(Some(&format!("{} · {} · {} ms · 指纹 {}",
        peer.os, peer.ip, peer.rtt_ms, peer.fp_short)));
    meta.add_css_class("meshdrop-meta");
    sub_row.append(&meta);
    col.append(&sub_row);
    head.append(&col);

    head.append(&chip::chip_with_dot("E2E · TRUSTED", chip::Tone::Mute, "#A8C800"));
    head.append(&icon_btn::icon_btn("⋯", "更多", icon_btn::IconBtnTone::Default));
    root.append(&head);

    let div = ascii_divider::divider("── TODAY · 今天 · 6 条 ──");
    div.set_margin_start(20);
    div.set_margin_end(20);
    root.append(&div);

    // 消息流
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

    for msg in mock::chat_with_mengxi() {
        flow.append(&msg_bubble::bubble(&msg));
    }
    scroll.set_child(Some(&flow));
    root.append(&scroll);

    // composer
    let composer = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    composer.add_css_class("meshdrop-composer");

    let entry = gtk::Entry::builder()
        .placeholder_text("写一条消息发给 孟茜… · Enter 发送 · ⌘V 粘贴文字便签")
        .hexpand(true)
        .build();
    composer.append(&entry);

    composer.append(&icon_btn::icon_btn("📎", "附件", icon_btn::IconBtnTone::Default));
    composer.append(&icon_btn::icon_btn("📋", "粘贴剪贴板", icon_btn::IconBtnTone::Default));
    composer.append(&icon_btn::icon_btn("发送", "发送（Enter）", icon_btn::IconBtnTone::Accent));

    root.append(&composer);

    root.upcast()
}
