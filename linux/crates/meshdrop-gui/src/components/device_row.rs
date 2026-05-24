//! sidebar / 列表行用的小卡片。
//! avatar(28) + KindGlyph + 名字 + (OS · RTT) + 在线小点
//! selected 时背景 lime_soft + 1px lime 描边。

use crate::components::{avatar::{avatar, Ring}, chip::dot, kind_glyph::glyph};
use crate::mock::MockDevice;
use adw::prelude::*;

pub fn build(d: &MockDevice, selected: bool) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    row.add_css_class("meshdrop-device-row");
    if selected { row.add_css_class("selected"); }

    let av = avatar(d.initials, d.color, 32, Ring::None);
    row.append(&av);

    let col = gtk::Box::new(gtk::Orientation::Vertical, 1);
    col.set_hexpand(true);
    col.set_valign(gtk::Align::Center);

    let name = gtk::Label::new(Some(d.name));
    name.set_halign(gtk::Align::Start);
    name.add_css_class("meshdrop-card-title");
    col.append(&name);

    let sub_row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    sub_row.set_halign(gtk::Align::Start);
    sub_row.append(&glyph(d.kind, 11));
    let sub = gtk::Label::new(Some(&format!("{} · {} ms", d.os, d.rtt_ms)));
    sub.add_css_class("meshdrop-meta");
    sub_row.append(&sub);
    col.append(&sub_row);

    row.append(&col);

    let online_dot = dot("#A8C800", 8);
    online_dot.set_valign(gtk::Align::Center);
    online_dot.set_halign(gtk::Align::Center);
    row.append(&online_dot);

    row
}
