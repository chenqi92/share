//! File Offer 弹窗：从 engine.pending_offers_rx 取第一条挂起请求。
//! Accept / Reject 直接调用 engine.respond_file_offer。

use crate::components::{ascii_divider, avatar, chip, file_chip};
use crate::engine_bridge::AppHandle;
use crate::mock;
use adw::prelude::*;
use meshdrop_core::history::format_bytes;
use std::rc::Rc;
use uuid::Uuid;

struct OfferView {
    peer_name: String,
    initials: String,
    file_name: String,
    file_size: String,
    file_ext: String,
    offer_id: Option<Uuid>,
}

pub fn present(parent: &impl IsA<gtk::Window>, handle: Option<&Rc<AppHandle>>) -> adw::Window {
    let view = build_view(handle);

    let win = adw::Window::builder()
        .transient_for(parent)
        .modal(true)
        .title(t!("offer.window_title").as_ref())
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

    let title = gtk::Label::new(Some(&*t!("offer.title")));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    root.append(&title);

    let card = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    card.add_css_class("meshdrop-card");
    card.append(&avatar::avatar(&view.initials, "#C7B8FF", 40, avatar::Ring::None));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let nm = gtk::Label::new(Some(&view.peer_name));
    nm.add_css_class("meshdrop-card-title");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let who = gtk::Label::new(Some(&*t!("offer.pending")));
    who.add_css_class("meshdrop-meta");
    who.set_halign(gtk::Align::Start);
    col.append(&who);
    card.append(&col);
    card.append(&chip::chip(&t!("offer.chip"), chip::Tone::Outline, true));
    root.append(&card);

    root.append(&ascii_divider::divider(&t!("offer.file_divider")));
    let file_card = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    file_card.add_css_class("meshdrop-card");
    file_card.append(&file_chip::chip(&view.file_name, &view.file_size, &view.file_ext, None));
    root.append(&file_card);

    let save_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    save_row.set_margin_top(8);
    let save_lb = gtk::Label::new(Some(&*t!("offer.save_to")));
    save_lb.add_css_class("meshdrop-ascii-divider");
    save_row.append(&save_lb);
    let path_lb = gtk::Label::new(Some(&*t!("offer.save_path", name = view.peer_name)));
    path_lb.add_css_class("meshdrop-mono");
    path_lb.set_halign(gtk::Align::Start);
    save_row.append(&path_lb);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    save_row.append(&sp);
    let change = gtk::Button::with_label(&t!("common.change"));
    // 接收落盘目录由 core 按对端名固定派生，暂不支持单次改路径：禁用并说明，避免假按钮。
    change.set_sensitive(false);
    change.set_tooltip_text(Some(t!("offer.change_disabled_tip").as_ref()));
    save_row.append(&change);
    root.append(&save_row);

    let btn_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    btn_row.set_halign(gtk::Align::End);
    btn_row.set_margin_top(12);
    let reject = gtk::Button::with_label(&t!("offer.reject_btn"));
    reject.add_css_class("destructive-action");
    let accept = gtk::Button::with_label(&t!("offer.accept_btn"));
    accept.add_css_class("suggested-action");
    btn_row.append(&reject);
    btn_row.append(&accept);
    root.append(&btn_row);

    toolbar.set_content(Some(&root));
    win.set_content(Some(&toolbar));

    let oid = view.offer_id;
    let h_for_buttons = handle.cloned();

    let win_c = win.clone();
    let h_c = h_for_buttons.clone();
    reject.connect_clicked(move |_| {
        if let (Some(h), Some(id)) = (&h_c, oid) {
            h.respond_offer(id, false);
        }
        win_c.close();
    });
    let win_c = win.clone();
    let h_c = h_for_buttons.clone();
    accept.connect_clicked(move |_| {
        if let (Some(h), Some(id)) = (&h_c, oid) {
            h.respond_offer(id, true);
        }
        win_c.close();
    });

    win.present();
    win
}

fn build_view(handle: Option<&Rc<AppHandle>>) -> OfferView {
    match handle.and_then(|h| h.pending_offers().into_iter().next()) {
        Some(o) => {
            let ext = o.file_name.rsplit_once('.').map(|(_, e)| e).unwrap_or("file").to_string();
            OfferView {
                peer_name: o.peer.name.clone(),
                initials: crate::view::initials_of(&o.peer.name),
                file_name: o.file_name.clone(),
                file_size: format_bytes(o.file_size),
                file_ext: ext,
                offer_id: Some(o.id),
            }
        }
        None => {
            let m = mock::pending_offer();
            OfferView {
                peer_name: m.peer.to_string(),
                initials: "嘉".into(),
                file_name: m.file_name.to_string(),
                file_size: m.file_size.to_string(),
                file_ext: "pages".into(),
                offer_id: None,
            }
        }
    }
}
