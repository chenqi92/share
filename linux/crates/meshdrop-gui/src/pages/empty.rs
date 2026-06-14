//! Empty / Offline / Failed 三种空态展示页。

use crate::components::{ascii_divider, chip, icon_btn};
use adw::prelude::*;

pub fn build() -> gtk::Widget {
    let root = gtk::Box::new(gtk::Orientation::Vertical, 18);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(20);
    root.set_margin_end(20);
    root.set_hexpand(true);
    root.set_vexpand(true);

    let title = gtk::Label::new(Some(&*t!("empty.title")));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    root.append(&title);

    // 空态图标统一用几何 mono glyph，不用 emoji（DESIGN_SPEC §10）。
    root.append(&ascii_divider::divider(&t!("empty.nearby_divider")));
    root.append(&state_card(
        "◎",
        &t!("empty.nearby_title"),
        &t!("empty.nearby_body"),
        Some((t!("empty.nearby_action").as_ref(), icon_btn::IconBtnTone::Accent)),
        None));

    root.append(&ascii_divider::divider(&t!("empty.offline_divider")));
    root.append(&state_card(
        "⌁",
        &t!("empty.offline_title"),
        &t!("empty.offline_body"),
        Some((t!("empty.offline_action").as_ref(), icon_btn::IconBtnTone::Default)),
        Some(t!("empty.offline_badge").as_ref())));

    root.append(&ascii_divider::divider(&t!("empty.failed_divider")));
    root.append(&state_card(
        "✗",
        &t!("empty.failed_title"),
        &t!("empty.failed_body"),
        Some((t!("empty.failed_action").as_ref(), icon_btn::IconBtnTone::Default)),
        Some(t!("empty.failed_badge").as_ref())));

    root.upcast()
}

fn state_card(
    glyph: &str, title: &str, body: &str,
    action: Option<(&str, icon_btn::IconBtnTone)>,
    badge: Option<&str>,
) -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Horizontal, 14);
    card.add_css_class("meshdrop-card");

    let g = gtk::Label::new(Some(glyph));
    g.add_css_class("meshdrop-display");
    g.set_size_request(56, 56);
    card.append(&g);

    let col = gtk::Box::new(gtk::Orientation::Vertical, 4);
    col.set_hexpand(true);

    let head_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    let t = gtk::Label::new(Some(title));
    t.add_css_class("meshdrop-card-title");
    t.set_halign(gtk::Align::Start);
    head_row.append(&t);
    if let Some(b) = badge {
        head_row.append(&chip::chip(b, chip::Tone::Error, true));
    }
    col.append(&head_row);

    let body_lb = gtk::Label::new(Some(body));
    body_lb.add_css_class("meshdrop-muted");
    body_lb.set_halign(gtk::Align::Start);
    body_lb.set_wrap(true);
    body_lb.set_max_width_chars(56);
    body_lb.set_xalign(0.0);
    col.append(&body_lb);
    card.append(&col);

    if let Some((label, tone)) = action {
        let btn = icon_btn::icon_btn(label, label, tone);
        btn.set_valign(gtk::Align::Center);
        card.append(&btn);
    }
    card
}
