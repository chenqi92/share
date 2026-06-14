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

    let title = gtk::Label::new(Some("空态 · Empty States"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    root.append(&title);

    // 空态图标统一用几何 mono glyph，不用 emoji（DESIGN_SPEC §10）。
    root.append(&ascii_divider::divider("── EMPTY · 没有附近设备 ──"));
    root.append(&state_card(
        "◎",
        "暂无附近设备",
        "正在扫描 _meshdrop._tcp · 同一 Wi-Fi 下的其他设备会在几秒内出现。",
        Some(("再扫一次", icon_btn::IconBtnTone::Accent)),
        None));

    root.append(&ascii_divider::divider("── OFFLINE · 没连上局域网 ──"));
    root.append(&state_card(
        "⌁",
        "没连上局域网",
        "MeshDrop 需要本机至少在一个有线 / 无线网络上。请检查网线是否拔出，或 Wi-Fi 是否已连接。",
        Some(("打开网络设置", icon_btn::IconBtnTone::Default)),
        Some("LAN · DOWN")));

    root.append(&ascii_divider::divider("── FAILED · 上一次传输失败 ──"));
    root.append(&state_card(
        "✗",
        "对方拒收 · 校验失败",
        "demo-video.mp4 在传输 87% 时 SHA-256 校验失败。MeshDrop 不会落盘损坏文件。",
        Some(("重试", icon_btn::IconBtnTone::Default)),
        Some("FAILED · 0xE5")));

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
