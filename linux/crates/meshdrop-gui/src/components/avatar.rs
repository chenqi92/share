//! 圆形 Avatar：彩色背景 + initials 字符，可选双层 ring。

use super::text;
use adw::prelude::*;

#[derive(Copy, Clone)]
#[allow(dead_code)]
pub enum Ring { None, Lime, Flame }

pub fn avatar(initials: &str, color_hex: &str, size: i32, ring: Ring) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(size).content_height(size).build();
    let (r, g, b) = parse_hex(color_hex);
    let initials = initials.to_string();
    area.set_draw_func(move |_, cr, w, h| {
        let cx = w as f64 / 2.0;
        let cy = h as f64 / 2.0;
        let pad = match ring { Ring::None => 0.0, _ => 3.0 };
        let outer = (w.min(h) as f64) / 2.0 - 1.0;
        let radius = outer - pad;

        match ring {
            Ring::None => {},
            Ring::Lime => {
                cr.set_source_rgba(221.0/255.0, 249.0/255.0, 75.0/255.0, 1.0);
                cr.set_line_width(2.0);
                cr.arc(cx, cy, outer, 0.0, std::f64::consts::TAU);
                cr.stroke().ok();
            },
            Ring::Flame => {
                cr.set_source_rgba(1.0, 90.0/255.0, 44.0/255.0, 1.0);
                cr.set_line_width(2.0);
                cr.arc(cx, cy, outer, 0.0, std::f64::consts::TAU);
                cr.stroke().ok();
            },
        }

        cr.set_source_rgb(r, g, b);
        cr.arc(cx, cy, radius, 0.0, std::f64::consts::TAU);
        cr.fill().ok();

        cr.set_source_rgba(0.04, 0.04, 0.04, 0.88);
        text::draw_centered(cr, cx, cy, &initials, "Space Grotesk", radius * 0.9, true);
    });
    area
}

pub fn parse_hex(s: &str) -> (f64, f64, f64) {
    let s = s.trim_start_matches('#');
    if s.len() != 6 { return (0.5, 0.5, 0.5); }
    let parse = |a: usize| u8::from_str_radix(&s[a..a + 2], 16).unwrap_or(128) as f64 / 255.0;
    (parse(0), parse(2), parse(4))
}

