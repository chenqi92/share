//! Discovery / Nearby 页：本机卡 + 雷达 + 设备列表 + 空态。

use crate::components::{ascii_divider, chip, meshdrop_logo, radar};
use crate::engine_bridge::AppHandle;
use crate::mock;
use crate::view::ViewDevice;
use adw::prelude::*;
use std::rc::Rc;

pub fn build(handle: Option<&Rc<AppHandle>>) -> gtk::Widget {
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
    let me_card = gtk::Box::new(gtk::Orientation::Horizontal, 14);
    me_card.add_css_class("meshdrop-card");
    me_card.append(&crate::components::avatar::avatar("我", "#DDF94B", 40,
                                                      crate::components::avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let (me_name, me_meta) = match handle {
        Some(h) => {
            let ip = h.self_ip.borrow().clone().unwrap_or_else(|| "—".into());
            (
                h.engine.display_name.clone(),
                format!("Linux · {} · 端口 {} · 指纹 {}", ip, h.engine.listen_port, h.fingerprint()),
            )
        }
        None => {
            let m = mock::me();
            (m.name.to_string(),
             format!("{} · {} · 指纹 {}", m.os, m.ip, m.fingerprint))
        }
    };
    let nm = gtk::Label::new(Some(&me_name));
    nm.add_css_class("meshdrop-card-title");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let meta = gtk::Label::new(Some(&me_meta));
    meta.add_css_class("meshdrop-meta");
    meta.set_halign(gtk::Align::Start);
    col.append(&meta);
    me_card.append(&col);

    let vis_chip = chip::chip("可见 · VISIBLE", chip::Tone::Lime, true);
    vis_chip.set_valign(gtk::Align::Center);
    me_card.append(&vis_chip);
    left.append(&me_card);

    // 雷达 divider（数量动态）
    let radar_div = ascii_divider::build("── RADAR · 雷达 · 0 PEERS ──");
    left.append(&radar_div.root);

    let initial_views: Vec<ViewDevice> = match handle {
        Some(h) => h.devices().iter().enumerate()
            .map(|(i, d)| ViewDevice::from_device(d, i)).collect(),
        None => mock::devices().iter().map(ViewDevice::from_mock).collect(),
    };
    // real 模式用本机真实 LAN IP 作为雷达中心标注；mock / screenshots 回退占位。
    let self_ip = handle.and_then(|h| h.self_ip.borrow().clone());
    let r = radar::build(&initial_views, None, self_ip);
    r.root.set_size_request(380, 380);
    left.append(&r.root);
    radar_div.set_text(&format!("── RADAR · 雷达 · {} PEERS ──", initial_views.len()));

    root.append(&left);

    // 右：设备列表 + 空态 / 错误占位
    let right = gtk::Box::new(gtk::Orientation::Vertical, 12);
    right.set_size_request(320, -1);
    right.set_vexpand(true);
    right.set_margin_top(18);
    right.set_margin_bottom(18);
    right.set_margin_start(10);
    right.set_margin_end(18);

    let devices_div = ascii_divider::build("── DEVICES · 设备 · 0 ──");
    right.append(&devices_div.root);

    // 列表容器 + 空态占位
    let list_card = gtk::Box::new(gtk::Orientation::Vertical, 6);
    list_card.add_css_class("meshdrop-card-flat");
    right.append(&list_card);

    let empty_card = build_empty_card();
    right.append(&empty_card);
    empty_card.set_visible(initial_views.is_empty());

    // 初始填充
    fill_devices(&list_card, &initial_views, handle);
    devices_div.set_text(&format!("── DEVICES · 设备 · {} ──", initial_views.len()));

    // 终端块（保留视觉占位）
    right.append(&ascii_divider::divider("── TERMINAL · trace ──"));
    let term = gtk::Box::new(gtk::Orientation::Vertical, 2);
    term.add_css_class("meshdrop-terminal");
    let lines = match handle {
        Some(h) => vec![
            format!("$ meshdrop --version"),
            format!("  meshdrop 0.2.0 · build 20260524"),
            String::new(),
            format!("$ self.id"),
            format!("  {}", h.engine.identity.id),
            format!("$ listen"),
            format!("  0.0.0.0:{}", h.engine.listen_port),
            format!("  https://0.0.0.0:{} · web gateway",
                h.gateway_port().unwrap_or(0)),
        ],
        None => vec![
            "$ meshdrop --version".to_string(),
            "  meshdrop 0.2.0 · build 20260524".to_string(),
            String::new(),
            "$ avahi-browse -rt _meshdrop._tcp".to_string(),
            "  (mock 数据, 用 --screenshots 渲染)".to_string(),
        ],
    };
    for line in lines {
        let l = gtk::Label::new(Some(&line));
        l.set_halign(gtk::Align::Start);
        l.set_xalign(0.0);
        term.append(&l);
    }
    right.append(&term);

    root.append(&right);

    // 订阅：刷新 radar + 列表 + 空态
    if let Some(h) = handle {
        let list_clone = list_card.clone();
        let empty_clone = empty_card.clone();
        let radar_handle = r;
        let dev_div_lbl = devices_div.label.clone();
        let radar_div_lbl = radar_div.label.clone();
        let h_for_rows = h.clone();
        h.observe(h.engine.devices_rx(), move |devs| {
            let views: Vec<ViewDevice> = devs.iter().enumerate()
                .map(|(i, d)| ViewDevice::from_device(d, i)).collect();
            fill_devices(&list_clone, &views, Some(&h_for_rows));
            empty_clone.set_visible(views.is_empty());
            dev_div_lbl.set_text(&format!("── DEVICES · 设备 · {} ──", views.len()));
            radar_div_lbl.set_text(&format!("── RADAR · 雷达 · {} PEERS ──", views.len()));
            radar_handle.set_devices(views);
        });
    }

    root.upcast()
}

fn fill_devices(container: &gtk::Box, devs: &[ViewDevice], handle: Option<&Rc<AppHandle>>) {
    while let Some(child) = container.first_child() {
        container.remove(&child);
    }
    for d in devs {
        let row = crate::components::device_row::build_with_handle(d, false, handle);
        container.append(&row);
    }
}

fn build_empty_card() -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Vertical, 6);
    card.add_css_class("meshdrop-card");
    let title = gtk::Label::new(Some("附近没有 MeshDrop 设备"));
    title.add_css_class("meshdrop-card-title");
    title.set_halign(gtk::Align::Start);
    card.append(&title);
    let hint = gtk::Label::new(Some(
        "正在扫描 _meshdrop._tcp · 同 Wi-Fi 下的其他设备会在几秒内出现。\n让朋友也打开试试。"));
    hint.add_css_class("meshdrop-muted");
    hint.set_halign(gtk::Align::Start);
    hint.set_wrap(true);
    hint.set_xalign(0.0);
    card.append(&hint);
    card
}
