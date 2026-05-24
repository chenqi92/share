//! Radar：核心组件。GTK4 `DrawingArea` + `add_tick_callback` 60fps 重绘。
//! sweep 旋转扫描臂（4.5s 一圈）+ pulse 设备点呼吸（2.6s）+ 3 环 + N/E/S/W 罗盘字母。
//! 设备点用 `gtk::Fixed` 容器另起一层，可点击。

use super::text;
use crate::view::ViewDevice;
use adw::prelude::*;
use std::cell::{Cell, RefCell};
use std::rc::Rc;
use std::time::Instant;

#[allow(dead_code)]
pub struct Radar {
    pub root: gtk::Overlay,
    pub area: gtk::DrawingArea,
    pub fixed: gtk::Fixed,
    pub selected: Rc<Cell<Option<usize>>>,
    pub devices: Rc<RefCell<Vec<ViewDevice>>>,
}

impl Radar {
    /// 用最新设备列表刷新 radar：替换内部数据 + 重建 label widgets。
    pub fn set_devices(&self, devs: Vec<ViewDevice>) {
        *self.devices.borrow_mut() = devs.clone();
        while let Some(child) = self.fixed.first_child() {
            self.fixed.remove(&child);
        }
        for (i, d) in devs.iter().enumerate() {
            let lbl_box = device_label_box(d);
            if Some(i) == self.selected.get() { lbl_box.add_css_class("selected"); }
            self.fixed.put(&lbl_box, 0.0, 0.0);
        }
        let (w, h) = (self.area.width() as f64, self.area.height() as f64);
        if w > 0.0 && h > 0.0 {
            layout_labels(&self.fixed, w, h, &devs);
        }
        self.area.queue_draw();
    }
}

pub fn build(devices: &[ViewDevice], selected_initial: Option<usize>) -> Radar {
    let area = gtk::DrawingArea::builder()
        .content_width(420)
        .content_height(420)
        .hexpand(true)
        .vexpand(true)
        .build();
    let start = Instant::now();
    let devices_rc: Rc<RefCell<Vec<ViewDevice>>> =
        Rc::new(RefCell::new(devices.to_vec()));
    let selected: Rc<Cell<Option<usize>>> = Rc::new(Cell::new(selected_initial));

    let dev_for_draw = devices_rc.clone();
    let sel_for_draw = selected.clone();
    area.set_draw_func(move |_, cr, w, h| {
        let devs = dev_for_draw.borrow();
        draw_radar(cr, w as f64, h as f64, start.elapsed().as_secs_f64(),
                   &devs, sel_for_draw.get());
    });
    area.add_tick_callback(move |a, _| {
        a.queue_draw();
        glib::ControlFlow::Continue
    });

    let fixed = gtk::Fixed::new();
    fixed.set_can_target(true);
    fixed.set_halign(gtk::Align::Fill);
    fixed.set_valign(gtk::Align::Fill);

    let center = center_card();

    for (i, d) in devices_rc.borrow().iter().enumerate() {
        let lbl_box = device_label_box(d);
        let cls = if Some(i) == selected.get() { Some("selected") } else { None };
        if let Some(c) = cls { lbl_box.add_css_class(c); }
        fixed.put(&lbl_box, 0.0, 0.0);
    }

    let area_clone = area.clone();
    let fixed_clone = fixed.clone();
    let devs_for_resize = devices_rc.clone();
    area.connect_resize(move |_, w, h| {
        let devs = devs_for_resize.borrow();
        layout_labels(&fixed_clone, w as f64, h as f64, &devs);
        area_clone.queue_draw();
    });

    let overlay = gtk::Overlay::new();
    overlay.set_child(Some(&area));
    overlay.add_overlay(&fixed);
    overlay.add_overlay(&center);
    center.set_halign(gtk::Align::Center);
    center.set_valign(gtk::Align::Center);

    Radar { root: overlay, area, fixed, selected, devices: devices_rc }
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
        text::draw_centered(cr, w/2.0, h/2.0 - 7.0, "YOU", "Space Grotesk", 13.0, true);
        cr.set_source_rgba(0.95, 0.95, 0.9, 0.7);
        text::draw_centered(cr, w/2.0, h/2.0 + 9.0, "192.168.1.42", "Geist Mono", 8.0, false);
    });
    b.append(&area);
    b
}

fn device_label_box(d: &ViewDevice) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 4);
    row.add_css_class("meshdrop-radar-label");
    let rtt = if d.rtt_ms > 0 { format!("{} ms", d.rtt_ms) } else { "—".into() };
    let txt = format!("{}  ·  {}  ·  {}", d.who, rtt, d.os);
    let lb = gtk::Label::new(Some(&txt));
    row.append(&lb);
    row
}

fn layout_labels(fixed: &gtk::Fixed, w: f64, h: f64, devs: &[ViewDevice]) {
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
              devs: &[ViewDevice], selected: Option<usize>) {
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

    cr.set_source_rgba(0.04, 0.04, 0.04, 0.30);
    for (label, dx, dy) in [("N", 0.0, -max_r - 8.0),
                             ("E", max_r + 12.0, 0.0),
                             ("S", 0.0, max_r + 8.0),
                             ("W", -max_r - 12.0, 0.0)] {
        text::draw_centered(cr, cx + dx, cy + dy, label, "Geist Mono", 10.0, true);
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
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.85);
        text::draw_centered(cr, x, y - 18.0, &d.who, "Space Grotesk", 11.0, true);
    }
}
