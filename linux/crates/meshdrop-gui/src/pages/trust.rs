//! Trust Manager 页：已配对设备表格。
//! 真 engine 模式下：从 TrustStore::snapshot() 读取。

use crate::components::{ascii_divider, avatar, chip, icon_btn};
use crate::engine_bridge::AppHandle;
use crate::mock;
use crate::view::ViewTrustEntry;
use adw::prelude::*;
use std::rc::Rc;

pub fn build(handle: Option<&Rc<AppHandle>>) -> gtk::Widget {
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
    let count_chip = chip::chip("0 台 · DEVICES", chip::Tone::Mute, true);
    title_row.append(&count_chip);
    root.append(&title_row);

    let hint = gtk::Label::new(Some(
        "信任记录写在 ~/.local/share/meshdrop/trust.json。撤销后下次对方发起会再次出现配对弹窗。"));
    hint.add_css_class("meshdrop-muted");
    hint.set_halign(gtk::Align::Start);
    hint.set_wrap(true);
    root.append(&hint);

    root.append(&ascii_divider::divider("── PAIRED · 已配对 ──"));

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
    scroll.set_child(Some(&list));
    root.append(&scroll);

    let entries: Vec<ViewTrustEntry> = match handle {
        Some(h) => h.engine.trust_store.snapshot().iter()
            .map(ViewTrustEntry::from_record).collect(),
        None => mock::trust().iter().map(|t| ViewTrustEntry {
            who: t.who.to_string(),
            device_name: t.device_name.to_string(),
            fingerprint: t.fingerprint.to_string(),
            paired_at: t.paired_at.to_string(),
            last_seen: t.last_seen.to_string(),
        }).collect(),
    };
    let n = entries.len();
    fill_trust(&list, &entries, handle);
    count_chip.set_tooltip_text(Some(&format!("共 {} 台", n)));
    title_row.queue_draw();

    // Trust store 没有 watch；订阅 devices_rx 触发刷新作为代理
    // （配对成功后 device 会重新发现，刷新代价低）。
    if let Some(h) = handle {
        let list_c = list.clone();
        let h_c = h.clone();
        h.observe(h.engine.devices_rx(), move |_| {
            let snap: Vec<ViewTrustEntry> = h_c.engine.trust_store.snapshot()
                .iter().map(ViewTrustEntry::from_record).collect();
            fill_trust(&list_c, &snap, Some(&h_c));
        });
    }

    root.upcast()
}

fn fill_trust(list: &gtk::Box, entries: &[ViewTrustEntry], handle: Option<&Rc<AppHandle>>) {
    while let Some(child) = list.first_child() {
        list.remove(&child);
    }
    if entries.is_empty() {
        let card = gtk::Box::new(gtk::Orientation::Vertical, 6);
        card.add_css_class("meshdrop-card");
        let t = gtk::Label::new(Some("还没有配对的设备"));
        t.add_css_class("meshdrop-card-title");
        t.set_halign(gtk::Align::Start);
        card.append(&t);
        let h = gtk::Label::new(Some("当对方首次连接时会弹出配对窗，确认后写入信任库。"));
        h.add_css_class("meshdrop-muted");
        h.set_halign(gtk::Align::Start);
        h.set_wrap(true);
        card.append(&h);
        list.append(&card);
        return;
    }
    for entry in entries {
        list.append(&trust_row(entry, handle));
    }
}

fn trust_row(entry: &ViewTrustEntry, handle: Option<&Rc<AppHandle>>) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    row.add_css_class("meshdrop-trust-row");

    let dev = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    dev.set_size_request(200, -1);
    dev.append(&avatar::avatar(&initials(&entry.who), seed_color(&entry.who), 30, avatar::Ring::None));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 1);
    let who = gtk::Label::new(Some(&entry.who));
    who.add_css_class("meshdrop-card-title");
    who.set_halign(gtk::Align::Start);
    col.append(&who);
    let dn = gtk::Label::new(Some(&entry.device_name));
    dn.add_css_class("meshdrop-meta");
    dn.set_halign(gtk::Align::Start);
    col.append(&dn);
    dev.append(&col);
    row.append(&dev);

    let fp = gtk::Label::new(Some(&entry.fingerprint));
    fp.add_css_class("meshdrop-mono");
    fp.set_size_request(260, -1);
    fp.set_xalign(0.0);
    row.append(&fp);

    let paired = gtk::Label::new(Some(&entry.paired_at));
    paired.add_css_class("meshdrop-meta");
    paired.set_size_request(110, -1);
    paired.set_xalign(0.0);
    row.append(&paired);

    let last = gtk::Label::new(Some(&entry.last_seen));
    last.add_css_class("meshdrop-meta");
    last.set_size_request(130, -1);
    last.set_xalign(0.0);
    row.append(&last);

    let btn = icon_btn::icon_btn("撤销", "撤销信任", icon_btn::IconBtnTone::Danger);
    btn.set_size_request(90, -1);
    if let Some(h) = handle {
        let h_c = h.clone();
        let fp_raw = entry.fingerprint.replace([' ', '·'], "").to_lowercase();
        btn.connect_clicked(move |_| {
            h_c.engine.trust_store.revoke(&fp_raw);
        });
    }
    row.append(&btn);

    row
}

fn initials(who: &str) -> String {
    if let Some(first) = who.chars().next() {
        first.to_string()
    } else { "·".to_string() }
}

fn seed_color(who: &str) -> &str {
    crate::view::palette_color(who.bytes().map(|b| b as usize).sum())
}
