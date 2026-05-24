//! Radar：核心组件。GTK4 `DrawingArea` + `add_tick_callback` 60fps 重绘。
//! sweep 旋转扫描臂（4.5s 一圈）+ pulse 设备点呼吸（2.6s）+ 3 环 + N/E/S/W 罗盘字母。
//! 设备点用 `gtk::Fixed` 容器另起一层，可点击。

use crate::mock::MockDevice;
use adw::prelude::*;
use gtk::cairo::{FontSlant, FontWeight};
use std::cell::Cell;
use std::rc::Rc;
use std::time::Instant;

#[allow(dead_code)]
pub struct Radar {
    pub root: gtk::Overlay,
    pub area: gtk::DrawingArea,
    pub fixed: gtk::Fixed,
    pub selected: Rc<Cell<Option<usize>>>,
}

pub fn build(devices: &[MockDevice], selected_initial: Option<usize>) -> Radar {
    let area = gtk::DrawingArea::builder()
        .content_width(420)
        .content_height(420)
        .hexpand(true)
        .vexpand(true)
        .build();
    let start = Instant::now();
    let devs: Vec<MockDevice> = devices.to_vec();
    let selected: Rc<Cell<Option<usize>>> = Rc::new(Cell::new(selected_initial));

    let dev_for_draw = devs.clone();
    let sel_for_draw = selected.clone();
    area.set_draw_func(move |_, cr, w, h| {
        draw_radar(cr, w as f64, h as f64, start.elapsed().as_secs_f64(),
                   &dev_for_draw, sel_for_draw.get());
    });
    area.add_tick_callback(move |a, _| {
        a.queue_draw();
        glib::ControlFlow::Continue
    });

    let fixed = gtk::Fixed::new();
    fixed.set_can_target(true);
    fixed.set_halign(gtk::Align::Fill);
    fixed.set_valign(gtk::Align::Fill);

    // 中心 YOU 节点
    let center = center_card();
    // 居中放置：用 size_allocate 时间无法直接做，简化：放在 (0,0) 由 area 的中心绘制。
    // GTK4 Fixed 不参与 layout，所以我们在 overlay 中只放 device label，YOU 标签直接画。

    // device labels（小胶囊，浮在对应坐标）
    for (i, d) in devs.iter().enumerate() {
        let lbl_box = device_label_box(d);
        let cls = if Some(i) == selected.get() { Some("selected") } else { None };
        if let Some(c) = cls { lbl_box.add_css_class(c); }
        fixed.put(&lbl_box, 0.0, 0.0);
    }

    let area_clone = area.clone();
    let fixed_clone = fixed.clone();
    let devs_clone = devs.clone();
    area.connect_resize(move |_, w, h| {
        layout_labels(&fixed_clone, w as f64, h as f64, &devs_clone);
        area_clone.queue_draw();
    });

    let overlay = gtk::Overlay::new();
    overlay.set_child(Some(&area));
    overlay.add_overlay(&fixed);
    overlay.add_overlay(&center);
    center.set_halign(gtk::Align::Center);
    center.set_valign(gtk::Align::Center);

    Radar { root: overlay, area, fixed, selected }
}

fn center_card() -> gtk::Box {
    let b = gtk::Box::new(gtk::Orientation::Vertical, 1);
    b.set_size_request(64, 64);
    b.add_css_class("meshdrop-radar-center");
    // 直接用 DrawingArea 绘制
    let area = gtk::DrawingArea::builder().content_width(64).content_height(64).build();
    area.set_draw_func(|_, cr, w, h| {
        let (w, h) = (w as f64, h as f64);
        cr.set_source_rgb(10.0/255.0, 10.0/255.0, 10.0/255.0);
        cr.arc(w/2.0, h/2.0, w.min(h)/2.0 - 1.0, 0.0, std::f64::consts::TAU);
        cr.fill().ok();
        cr.set_source_rgba(221.0/255.0, 249.0/255.0, 75.0/255.0, 0.95);
        cr.select_font_face("Space Grotesk", FontSlant::Normal, FontWeight::Bold);
        cr.set_font_size(12.0);
        if let Ok(ext) = cr.text_extents("YOU") {
            cr.move_to(w/2.0 - ext.width()/2.0 - ext.x_bearing(),
                       h/2.0 - 4.0 - ext.y_bearing()/2.0);
            let _ = cr.show_text("YOU");
        }
        cr.set_source_rgba(0.95, 0.95, 0.9, 0.7);
        cr.select_font_face("Geist Mono", FontSlant::Normal, FontWeight::Normal);
        cr.set_font_size(7.5);
        let ip = "192.168.1.42";
        if let Ok(ext) = cr.text_extents(ip) {
            cr.move_to(w/2.0 - ext.width()/2.0 - ext.x_bearing(),
                       h/2.0 + 10.0 - ext.y_bearing()/2.0);
            let _ = cr.show_text(ip);
        }
    });
    b.append(&area);
    b
}

fn device_label_box(d: &crate::mock::MockDevice) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 4);
    row.add_css_class("meshdrop-radar-label");
    let txt = format!("{}  ·  {} ms  ·  {}", d.who, d.rtt_ms, d.os);
    let lb = gtk::Label::new(Some(&txt));
    row.append(&lb);
    row
}

fn layout_labels(fixed: &gtk::Fixed, w: f64, h: f64, devs: &[crate::mock::MockDevice]) {
    let cx = w / 2.0;
    let cy = h / 2.0;
    let max_r = (w.min(h) / 2.0) * 0.9;
    let mut child = fixed.first_child();
    let mut idx = 0;
    while let Some(c) = child.clone() {
        if let Some(d) = devs.get(idx) {
            let ang = d.angle.to_radians();
            let r = max_r * d.dist;
            let x = cx + ang.cos() * r;
            let y = cy + ang.sin() * r;
            // label 偏移 18px（避免覆盖设备点）
            fixed.move_(&c, x - 60.0, y - 12.0 + 22.0);
        }
        idx += 1;
        child = c.next_sibling();
    }
}

fn draw_radar(cr: &gtk::cairo::Context, w: f64, h: f64, t: f64,
              devs: &[crate::mock::MockDevice], selected: Option<usize>) {
    let cx = w / 2.0;
    let cy = h / 2.0;
    let max_r = (w.min(h) / 2.0) * 0.9;

    // 3 环
    for k in [0.33, 0.66, 1.0] {
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.10);
        cr.set_line_width(1.0);
        cr.arc(cx, cy, max_r * k, 0.0, std::f64::consts::TAU);
        cr.stroke().ok();
    }

    // 十字 + N/E/S/W
    cr.set_source_rgba(0.04, 0.04, 0.04, 0.06);
    cr.move_to(cx - max_r, cy); cr.line_to(cx + max_r, cy);
    cr.move_to(cx, cy - max_r); cr.line_to(cx, cy + max_r);
    cr.stroke().ok();

    cr.select_font_face("Geist Mono", FontSlant::Normal, FontWeight::Bold);
    cr.set_font_size(9.0);
    cr.set_source_rgba(0.04, 0.04, 0.04, 0.30);
    for (label, dx, dy) in [("N", 0.0, -max_r - 12.0),
                             ("E", max_r + 10.0, 4.0),
                             ("S", 0.0, max_r + 16.0),
                             ("W", -max_r - 16.0, 4.0)] {
        if let Ok(ext) = cr.text_extents(label) {
            cr.move_to(cx + dx - ext.width() / 2.0 - ext.x_bearing(),
                       cy + dy - ext.height() / 2.0 - ext.y_bearing());
            let _ = cr.show_text(label);
        }
    }

    // sweep arm（4.5s/圈，lime 透明渐变扇形）
    let sweep_dur = 4.5;
    let angle = (t / sweep_dur) * std::f64::consts::TAU;
    let span = 0.55;
    let grad = gtk::cairo::RadialGradient::new(cx, cy, 0.0, cx, cy, max_r);
    grad.add_color_stop_rgba(0.0, 221.0/255.0, 249.0/255.0, 75.0/255.0, 0.35);
    grad.add_color_stop_rgba(1.0, 221.0/255.0, 249.0/255.0, 75.0/255.0, 0.0);
    cr.set_source(&grad).ok();
    cr.move_to(cx, cy);
    cr.arc(cx, cy, max_r, angle - span, angle);
    cr.close_path();
    cr.fill().ok();

    // 设备点 + 呼吸 halo
    for (i, d) in devs.iter().enumerate() {
        let ang = d.angle.to_radians();
        let r = max_r * d.dist;
        let x = cx + ang.cos() * r;
        let y = cy + ang.sin() * r;

        let phase = (t * std::f64::consts::TAU / 2.6 + i as f64 * 0.6).sin().abs();
        let halo_r = 14.0 + phase * 10.0;

        let is_selected = Some(i) == selected;
        let (dot_r, dot_g, dot_b) = if is_selected { (1.0, 90.0/255.0, 44.0/255.0) }
                                    else { (221.0/255.0, 249.0/255.0, 75.0/255.0) };

        cr.set_source_rgba(dot_r, dot_g, dot_b, 0.25 * (1.0 - phase * 0.5));
        cr.arc(x, y, halo_r, 0.0, std::f64::consts::TAU);
        cr.fill().ok();

        cr.set_source_rgb(dot_r, dot_g, dot_b);
        cr.arc(x, y, 7.0, 0.0, std::f64::consts::TAU);
        cr.fill().ok();
        cr.set_source_rgb(10.0/255.0, 10.0/255.0, 10.0/255.0);
        cr.set_line_width(1.5);
        cr.arc(x, y, 7.0, 0.0, std::f64::consts::TAU);
        cr.stroke().ok();

        // selected：拉一条 flame 虚线到中心
        if is_selected {
            cr.set_source_rgba(1.0, 90.0/255.0, 44.0/255.0, 0.55);
            cr.set_line_width(1.2);
            cr.set_dash(&[4.0, 4.0], 0.0);
            cr.move_to(cx, cy);
            cr.line_to(x, y);
            cr.stroke().ok();
            cr.set_dash(&[], 0.0);
        }

        // who 标签（在点上方略偏左）
        cr.select_font_face("Space Grotesk", FontSlant::Normal, FontWeight::Bold);
        cr.set_font_size(10.0);
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.85);
        let who = d.who;
        if let Ok(ext) = cr.text_extents(who) {
            cr.move_to(x - ext.width() / 2.0 - ext.x_bearing(),
                       y - 14.0 - ext.y_bearing()/2.0);
            let _ = cr.show_text(who);
        }
    }
}
