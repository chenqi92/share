//! File Offer 弹窗：来自对方的文件 + 可选文字便签。

use crate::components::{ascii_divider, avatar, chip, file_chip};
use crate::mock;
use adw::prelude::*;

pub fn present(parent: &impl IsA<gtk::Window>) {
    let offer = mock::pending_offer();

    let win = adw::Window::builder()
        .transient_for(parent)
        .modal(true)
        .title("接收文件 · Receive")
        .default_width(480)
        .default_height(440)
        .build();

    let toolbar = adw::ToolbarView::new();
    toolbar.add_top_bar(&adw::HeaderBar::new());

    let root = gtk::Box::new(gtk::Orientation::Vertical, 12);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(20);
    root.set_margin_end(20);

    let title = gtk::Label::new(Some("收到一个文件 · Receive offer"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    root.append(&title);

    // peer 卡片
    let card = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    card.add_css_class("meshdrop-card");
    card.append(&avatar::avatar("嘉", "#C7B8FF", 40, avatar::Ring::None));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let nm = gtk::Label::new(Some(offer.device_name));
    nm.add_css_class("meshdrop-card-title");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let who = gtk::Label::new(Some(&format!("来自 · {} · {}", offer.peer, offer.received_at)));
    who.add_css_class("meshdrop-meta");
    who.set_halign(gtk::Align::Start);
    col.append(&who);
    card.append(&col);
    card.append(&chip::chip("E2E · TRUSTED", chip::Tone::Lime, true));
    root.append(&card);

    // 文件
    root.append(&ascii_divider::divider("── FILE · 文件 ──"));
    let file_card = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    file_card.add_css_class("meshdrop-card");
    file_card.append(&file_chip::chip(offer.file_name, offer.file_size, "pages", None));
    root.append(&file_card);

    // 文字便签
    if let Some(note) = offer.note {
        root.append(&ascii_divider::divider("── NOTE · 文字便签 ──"));
        let note_card = gtk::Box::new(gtk::Orientation::Vertical, 0);
        note_card.add_css_class("meshdrop-card-flat");
        let lb = gtk::Label::new(Some(note));
        lb.set_wrap(true);
        lb.set_xalign(0.0);
        lb.set_halign(gtk::Align::Start);
        lb.add_css_class("meshdrop-body");
        note_card.append(&lb);
        root.append(&note_card);
    }

    // 保存路径
    let save_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    save_row.set_margin_top(8);
    let save_lb = gtk::Label::new(Some("保存到"));
    save_lb.add_css_class("meshdrop-ascii-divider");
    save_row.append(&save_lb);
    let path_lb = gtk::Label::new(Some("~/Downloads/MeshDrop/嘉伟/"));
    path_lb.add_css_class("meshdrop-mono");
    path_lb.set_halign(gtk::Align::Start);
    save_row.append(&path_lb);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    save_row.append(&sp);
    let change = gtk::Button::with_label("更改…");
    save_row.append(&change);
    root.append(&save_row);

    // 按钮
    let btn_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    btn_row.set_halign(gtk::Align::End);
    btn_row.set_margin_top(12);
    let reject = gtk::Button::with_label("拒绝 · Reject");
    reject.add_css_class("destructive-action");
    let accept = gtk::Button::with_label("接受 · Accept");
    accept.add_css_class("suggested-action");
    btn_row.append(&reject);
    btn_row.append(&accept);
    root.append(&btn_row);

    toolbar.set_content(Some(&root));
    win.set_content(Some(&toolbar));

    let win_c = win.clone();
    reject.connect_clicked(move |_| win_c.close());
    let win_c = win.clone();
    accept.connect_clicked(move |_| win_c.close());

    win.present();
}
