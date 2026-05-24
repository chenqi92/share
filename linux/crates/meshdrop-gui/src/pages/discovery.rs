//! Discovery / Nearby 页：本机卡 + 雷达 + 设备列表 + 终端块。

use crate::components::{ascii_divider, chip, meshdrop_logo, radar};
use crate::mock;
use adw::prelude::*;

pub fn build() -> gtk::Widget {
    let root = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    root.set_hexpand(true);
    root.set_vexpand(true);

    // 左：本机 + 雷达
    let left = gtk::Box::new(gtk::Orientation::Vertical, 14);
    left.set_hexpand(true);
    left.set_vexpand(true);
    left.set_margin_top(18);
    left.set_margin_bottom(18);
    left.set_margin_start(20);
    left.set_margin_end(10);

    // hero 行
    let hero_row = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    hero_row.append(&meshdrop_logo::mark(34, meshdrop_logo::LogoTone::Dark));
    let hero_col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    let title = gtk::Label::new(Some("附近 · Nearby"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    hero_col.append(&title);
    let sub = gtk::Label::new(Some("一个内网，任何设备，谁都能 ping 到。"));
    sub.add_css_class("meshdrop-muted");
    sub.set_halign(gtk::Align::Start);
    hero_col.append(&sub);
    hero_row.append(&hero_col);
    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    hero_row.append(&spacer);
    hero_row.append(&chip::chip_with_dot("LIVE · LAN", chip::Tone::Mute, "#A8C800"));
    left.append(&hero_row);

    // 本机卡
    let me = mock::me();
    let me_card = gtk::Box::new(gtk::Orientation::Horizontal, 14);
    me_card.add_css_class("meshdrop-card");
    me_card.append(&crate::components::avatar::avatar("我", "#DDF94B", 40,
                                                      crate::components::avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let nm = gtk::Label::new(Some(me.name));
    nm.add_css_class("meshdrop-card-title");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let meta = gtk::Label::new(Some(&format!("{} · {} · 指纹 {}", me.os, me.ip, me.fingerprint)));
    meta.add_css_class("meshdrop-meta");
    meta.set_halign(gtk::Align::Start);
    col.append(&meta);
    me_card.append(&col);

    let vis_chip = chip::chip("可见 · VISIBLE", chip::Tone::Lime, true);
    vis_chip.set_valign(gtk::Align::Center);
    me_card.append(&vis_chip);
    left.append(&me_card);

    // 雷达
    left.append(&ascii_divider::divider("── RADAR · 雷达 · 5 PEERS ──"));
    let r = radar::build(&mock::devices(), Some(mock::CHAT_PEER_INDEX));
    r.root.set_size_request(380, 380);
    left.append(&r.root);

    root.append(&left);

    // 右：设备列表 + 终端块
    let right = gtk::Box::new(gtk::Orientation::Vertical, 12);
    right.set_size_request(320, -1);
    right.set_vexpand(true);
    right.set_margin_top(18);
    right.set_margin_bottom(18);
    right.set_margin_start(10);
    right.set_margin_end(18);

    right.append(&ascii_divider::divider("── DEVICES · 设备 ──"));

    let list = gtk::Box::new(gtk::Orientation::Vertical, 6);
    list.add_css_class("meshdrop-card-flat");
    for (i, d) in mock::devices().iter().enumerate() {
        let row = crate::components::device_row::build(d, i == mock::CHAT_PEER_INDEX);
        list.append(&row);
    }
    right.append(&list);

    right.append(&ascii_divider::divider("── TERMINAL · trace ──"));

    let term = gtk::Box::new(gtk::Orientation::Vertical, 2);
    term.add_css_class("meshdrop-terminal");
    for line in [
        "$ meshdrop --version",
        "  meshdrop 0.2.0 · build 20260524",
        "",
        "$ avahi-browse -rt _meshdrop._tcp",
        "+ lily   _meshdrop._tcp  RTT 18 ms   ZX8K…",
        "+ kun    _meshdrop._tcp  RTT 32 ms   P3R7…",
        "+ jiawei _meshdrop._tcp  RTT 14 ms   T8XW…",
        "+ mengxi _meshdrop._tcp  RTT 26 ms   QA8N…",
        "+ dev01  _meshdrop._tcp  RTT 41 ms   X3WF…",
        "",
        "$ tail -f /var/log/meshdrop.log",
        "  [14:18:02] ↓ mengxi  IMG_4821~38.heic  128 MB",
        "  [14:10:55] ↑ mengxi  设计稿_v3_final.fig  14.2 MB",
        "  [14:08:19] ↑ jiawei  iOS-mocks-final.zip  67% · 8.4 MB/s",
        "  [13:42:08] ✓ dev01   release-notes.md  4.8 KB",
    ] {
        let l = gtk::Label::new(Some(line));
        l.set_halign(gtk::Align::Start);
        l.set_xalign(0.0);
        term.append(&l);
    }
    right.append(&term);

    root.append(&right);
    root.upcast()
}
