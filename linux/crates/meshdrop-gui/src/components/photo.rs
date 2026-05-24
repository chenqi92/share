//! Photo 占位 / 缩略图：渐变背景 + 假地平线 + 假太阳 + 山形。按 hue 参数调色。

use adw::prelude::*;
use gtk::cairo;

pub fn photo(w: i32, h: i32, hue: f64) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(w).content_height(h).build();
    area.set_draw_func(move |_, cr, w, h| {
        let (w, h) = (w as f64, h as f64);
        let (r1, g1, b1) = hsl(hue, 0.55, 0.85);
        let (r2, g2, b2) = hsl((hue + 40.0) % 360.0, 0.5, 0.55);

        let pat = cairo::LinearGradient::new(0.0, 0.0, 0.0, h);
        pat.add_color_stop_rgb(0.0, r1, g1, b1);
        pat.add_color_stop_rgb(1.0, r2, g2, b2);
        cr.set_source(&pat).ok();
        cr.rectangle(0.0, 0.0, w, h);
        cr.fill().ok();

        // 太阳
        let cx = w * 0.78;
        let cy = h * 0.32;
        cr.set_source_rgba(1.0, 1.0, 1.0, 0.85);
        cr.arc(cx, cy, w.min(h) * 0.08, 0.0, std::f64::consts::TAU);
        cr.fill().ok();

        // 远山
        let hor = h * 0.62;
        cr.set_source_rgba(0.04, 0.04, 0.06, 0.4);
        cr.move_to(0.0, hor);
        cr.line_to(w * 0.18, hor - h * 0.18);
        cr.line_to(w * 0.36, hor - h * 0.05);
        cr.line_to(w * 0.55, hor - h * 0.20);
        cr.line_to(w * 0.75, hor - h * 0.08);
        cr.line_to(w, hor - h * 0.15);
        cr.line_to(w, h);
        cr.line_to(0.0, h);
        cr.close_path();
        cr.fill().ok();

        // 地平线
        cr.set_source_rgba(0.04, 0.04, 0.06, 0.18);
        cr.set_line_width(1.0);
        cr.move_to(0.0, hor);
        cr.line_to(w, hor);
        cr.stroke().ok();
    });
    area
}

fn hsl(h: f64, s: f64, l: f64) -> (f64, f64, f64) {
    let c = (1.0 - (2.0 * l - 1.0).abs()) * s;
    let h6 = (h % 360.0) / 60.0;
    let x = c * (1.0 - (h6 % 2.0 - 1.0).abs());
    let (r, g, b) = match h6 as i32 {
        0 => (c, x, 0.0),
        1 => (x, c, 0.0),
        2 => (0.0, c, x),
        3 => (0.0, x, c),
        4 => (x, 0.0, c),
        _ => (c, 0.0, x),
    };
    let m = l - c / 2.0;
    (r + m, g + m, b + m)
}
