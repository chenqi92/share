//! MeshDrop logo / wordmark / lockup。
//! 两个交叠空心圆环 + 中间 lime 实心圆点（viewBox 24×24，COMMON §4）。

use adw::prelude::*;
use gtk::cairo;

#[derive(Copy, Clone)]
#[allow(dead_code)]
pub enum LogoTone { Dark, Light }

/// 矢量 logo（cairo 自绘）。
pub fn mark(size: i32, tone: LogoTone) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(size).content_height(size).build();
    area.set_draw_func(move |_, cr, w, h| draw_mark(cr, w as f64, h as f64, tone));
    area
}

fn draw_mark(cr: &cairo::Context, w: f64, h: f64, tone: LogoTone) {
    let scale = w.min(h) / 24.0;
    cr.save().ok();
    cr.translate((w - 24.0 * scale) / 2.0, (h - 24.0 * scale) / 2.0);
    cr.scale(scale, scale);

    let (sr, sg, sb) = match tone {
        LogoTone::Dark  => (10.0 / 255.0, 10.0 / 255.0, 10.0 / 255.0),
        LogoTone::Light => (232.0 / 255.0, 227.0 / 255.0, 214.0 / 255.0),
    };
    cr.set_source_rgb(sr, sg, sb);
    cr.set_line_width(2.0);

    cr.arc(9.0, 12.0, 6.5, 0.0, std::f64::consts::TAU);
    cr.stroke().ok();
    cr.arc(15.0, 12.0, 6.5, 0.0, std::f64::consts::TAU);
    cr.stroke().ok();

    // lime dot
    cr.set_source_rgb(221.0 / 255.0, 249.0 / 255.0, 75.0 / 255.0);
    cr.arc(12.0, 12.0, 1.8, 0.0, std::f64::consts::TAU);
    cr.fill().ok();

    cr.restore().ok();
}

/// wordmark：小写 meshdrop + 紧贴 lime 圆点。
pub fn wordmark() -> gtk::Box {
    wordmark_sized(18)
}

pub fn wordmark_sized(font_px: i32) -> gtk::Box {
    let b = gtk::Box::new(gtk::Orientation::Horizontal, 4);
    b.set_valign(gtk::Align::Center);
    let label = gtk::Label::new(None);
    label.add_css_class("meshdrop-display");
    label.set_markup(&format!(
        "<span font_family=\"Space Grotesk\" font_weight=\"700\" letter_spacing=\"-450\" size=\"{}\">meshdrop</span>",
        font_px * gtk::pango::SCALE
    ));
    let dot_sz = (font_px as f64 * 0.45).round() as i32;
    let dot = gtk::DrawingArea::builder()
        .content_width(dot_sz + 2)
        .content_height(font_px)
        .build();
    let r = (font_px as f64 * 0.18).max(2.5);
    dot.set_draw_func(move |_, cr, w, h| {
        let cx = w as f64 / 2.0;
        let cy = h as f64 * 0.72;
        cr.set_source_rgb(221.0 / 255.0, 249.0 / 255.0, 75.0 / 255.0);
        cr.arc(cx, cy, r, 0.0, std::f64::consts::TAU);
        cr.fill().ok();
    });
    b.append(&label);
    b.append(&dot);
    b
}

/// logo + wordmark 横排锁定组合。
pub fn lockup(size: i32, tone: LogoTone) -> gtk::Box {
    let b = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    b.set_valign(gtk::Align::Center);
    b.append(&mark(size, tone));
    b.append(&wordmark());
    b
}
