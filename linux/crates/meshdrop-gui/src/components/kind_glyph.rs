//! KindGlyph：每 OS 一个 12×12 线条小 svg。
//! mac=方框+底线 / win=4 格田字 / ipad=圆角矩形+小圆 / ios&android=圆角窄矩形+底线。

use crate::mock::DeviceKind;
use adw::prelude::*;

pub fn glyph(kind: DeviceKind, size: i32) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(size).content_height(size).build();
    area.set_draw_func(move |_, cr, w, h| {
        let s = w.min(h) as f64;
        let x0 = (w as f64 - s) / 2.0;
        let y0 = (h as f64 - s) / 2.0;
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.85);
        cr.set_line_width(1.2);
        match kind {
            DeviceKind::Mac => {
                // 方框 + 底线
                let r = 1.4;
                rect(cr, x0 + 1.0, y0 + 1.0, s - 2.0, s - 4.0, r);
                cr.stroke().ok();
                cr.move_to(x0 + 2.0, y0 + s - 1.0);
                cr.line_to(x0 + s - 2.0, y0 + s - 1.0);
                cr.stroke().ok();
            }
            DeviceKind::Win => {
                // 4 格田字
                let g = s / 2.0;
                rect(cr, x0 + 1.0, y0 + 1.0,         g - 1.5, g - 1.5, 0.6);
                cr.stroke().ok();
                rect(cr, x0 + g + 0.5, y0 + 1.0,     g - 1.5, g - 1.5, 0.6);
                cr.stroke().ok();
                rect(cr, x0 + 1.0, y0 + g + 0.5,     g - 1.5, g - 1.5, 0.6);
                cr.stroke().ok();
                rect(cr, x0 + g + 0.5, y0 + g + 0.5, g - 1.5, g - 1.5, 0.6);
                cr.stroke().ok();
            }
            DeviceKind::Linux => {
                // 企鹅简化：圆顶 + 椭圆底
                cr.arc(x0 + s / 2.0, y0 + s * 0.42, s * 0.30, 0.0, std::f64::consts::TAU);
                cr.stroke().ok();
                rect(cr, x0 + s * 0.22, y0 + s * 0.55, s * 0.56, s * 0.38, s * 0.18);
                cr.stroke().ok();
            }
            DeviceKind::Ipad => {
                // 大圆角矩形 + 底部小圆
                rect(cr, x0 + 1.0, y0 + 1.0, s - 2.0, s - 2.0, 2.0);
                cr.stroke().ok();
                cr.arc(x0 + s / 2.0, y0 + s - 2.5, 0.7, 0.0, std::f64::consts::TAU);
                cr.fill().ok();
            }
            DeviceKind::Ios | DeviceKind::Android => {
                // 圆角窄矩形 + 底线
                rect(cr, x0 + s * 0.25, y0 + 0.5, s * 0.5, s - 1.0, 1.2);
                cr.stroke().ok();
                cr.move_to(x0 + s * 0.4, y0 + s - 1.7);
                cr.line_to(x0 + s * 0.6, y0 + s - 1.7);
                cr.stroke().ok();
            }
        }
    });
    area
}

fn rect(cr: &gtk::cairo::Context, x: f64, y: f64, w: f64, h: f64, r: f64) {
    cr.new_sub_path();
    cr.arc(x + w - r, y + r,     r, -std::f64::consts::FRAC_PI_2, 0.0);
    cr.arc(x + w - r, y + h - r, r, 0.0, std::f64::consts::FRAC_PI_2);
    cr.arc(x + r,     y + h - r, r, std::f64::consts::FRAC_PI_2, std::f64::consts::PI);
    cr.arc(x + r,     y + r,     r, std::f64::consts::PI, 3.0 * std::f64::consts::FRAC_PI_2);
    cr.close_path();
}
