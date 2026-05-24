//! Trust Manager 页：已配对设备表格 + 指纹列 + 撤销按钮。

use crate::components::{ascii_divider, avatar, chip, icon_btn};
use crate::mock;
use adw::prelude::*;

pub fn build() -> gtk::Widget {
    let root = gtk::Box::new(gtk::Orientation::Vertical, 14);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(20);
    root.set_margin_end(20);
    root.set_hexpand(true);
    root.set_vexpand(true);

    let title_row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    let title = gtk::Label::new(Some("已配对 · Trusted"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    title_row.append(&title);
    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    title_row.append(&sp);
    title_row.append(&chip::chip(
        &format!("{} 台 · DEVICES", mock::trust().len()),
        chip::Tone::Mute, true));
    root.append(&title_row);

    let hint = gtk::Label::new(Some(
        "信任记录写在 ~/.config/meshdrop/trust.json。撤销后下次对方发起会再次出现配对弹窗。"));
    hint.add_css_class("meshdrop-muted");
    hint.set_halign(gtk::Align::Start);
    hint.set_wrap(true);
    root.append(&hint);

    root.append(&ascii_divider::divider("── PAIRED · 已配对 ──"));

    // 表头
    let header = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    header.set_margin_start(12);
    header.set_margin_end(12);
    for (label, w) in [("设备", 200), ("指纹（前 4 组）", 260), ("配对日期", 110), ("最近在线", 130), ("", 90)] {
        let l = gtk::Label::new(Some(label));
        l.set_xalign(0.0);
        l.add_css_class("meshdrop-ascii-divider");
        l.set_size_request(w, -1);
        header.append(&l);
    }
    root.append(&header);

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .build();
    let list = gtk::Box::new(gtk::Orientation::Vertical, 8);

    for entry in mock::trust() {
        list.append(&trust_row(&entry));
    }
    scroll.set_child(Some(&list));
    root.append(&scroll);

    root.upcast()
}

fn trust_row(entry: &mock::TrustEntry) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    row.add_css_class("meshdrop-trust-row");

    // 设备列
    let dev = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    dev.set_size_request(200, -1);
    dev.append(&avatar::avatar(initials(entry.who), seed_color(entry.who), 30, avatar::Ring::None));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 1);
    let who = gtk::Label::new(Some(entry.who));
    who.add_css_class("meshdrop-card-title");
    who.set_halign(gtk::Align::Start);
    col.append(&who);
    let dn = gtk::Label::new(Some(entry.device_name));
    dn.add_css_class("meshdrop-meta");
    dn.set_halign(gtk::Align::Start);
    col.append(&dn);
    dev.append(&col);
    row.append(&dev);

    // 指纹列
    let fp = gtk::Label::new(Some(entry.fingerprint));
    fp.add_css_class("meshdrop-mono");
    fp.set_size_request(260, -1);
    fp.set_xalign(0.0);
    row.append(&fp);

    let paired = gtk::Label::new(Some(entry.paired_at));
    paired.add_css_class("meshdrop-meta");
    paired.set_size_request(110, -1);
    paired.set_xalign(0.0);
    row.append(&paired);

    let last = gtk::Label::new(Some(entry.last_seen));
    last.add_css_class("meshdrop-meta");
    last.set_size_request(130, -1);
    last.set_xalign(0.0);
    row.append(&last);

    let btn = icon_btn::icon_btn("撤销", "撤销信任", icon_btn::IconBtnTone::Danger);
    btn.set_size_request(90, -1);
    row.append(&btn);

    row
}

fn initials(who: &str) -> &str {
    // 中文首字
    if who.starts_with(|c: char| c.is_ascii()) {
        &who[..1.min(who.len())]
    } else {
        let first = who.chars().next().unwrap_or('·');
        // 返回 &str 不太好；这里改成静态映射。
        match first {
            '李' => "李", '坤' => "坤", '嘉' => "嘉", '孟' => "孟", '工' => "工",
            _ => "·",
        }
    }
}
fn seed_color(who: &str) -> &str {
    match who {
        "李莉" => "#FFB4A1",
        "坤"   => "#B7E5C8",
        "嘉伟" => "#C7B8FF",
        "孟茜" => "#FFD970",
        "工位机" => "#9AD0FF",
        _ => "#E2DCCD",
    }
}
