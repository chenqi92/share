//! 胶囊 Chip。5 种 tone + outline / mute / lime / ink / flame / sky / error。
//! 固定 height 20px，radius 999。mono=true 时走 mono 字体 + uppercase。

use adw::prelude::*;

#[derive(Copy, Clone)]
pub enum Tone { Mute, Lime, Ink, Outline, Flame, Sky, Error }

impl Tone {
    fn css(self) -> &'static str {
        match self {
            Tone::Mute    => "tone-mute",
            Tone::Lime    => "tone-lime",
            Tone::Ink     => "tone-ink",
            Tone::Outline => "tone-outline",
            Tone::Flame   => "tone-flame",
            Tone::Sky     => "tone-sky",
            Tone::Error   => "tone-error",
        }
    }
}

pub fn chip(text: &str, tone: Tone, mono: bool) -> gtk::Label {
    let lb = gtk::Label::new(Some(text));
    lb.add_css_class("meshdrop-chip");
    lb.add_css_class(tone.css());
    if mono { lb.add_css_class("mono"); }
    lb.set_valign(gtk::Align::Center);
    lb
}

/// 带前缀小色点的 chip（例如  ●  ONLINE）。
pub fn chip_with_dot(text: &str, tone: Tone, dot_color: &str) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    row.add_css_class("meshdrop-chip");
    row.add_css_class(tone.css());
    row.add_css_class("mono");
    row.set_valign(gtk::Align::Center);
    let dot = dot(dot_color, 7);
    row.append(&dot);
    let lb = gtk::Label::new(Some(text));
    row.append(&lb);
    row
}

pub fn dot(color_hex: &str, size: i32) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(size).content_height(size).build();
    let (r, g, b) = super::avatar::parse_hex(color_hex);
    area.set_draw_func(move |_, cr, w, h| {
        cr.set_source_rgb(r, g, b);
        cr.arc(w as f64 / 2.0, h as f64 / 2.0, (w.min(h) as f64) / 2.0 - 0.5, 0.0, std::f64::consts::TAU);
        cr.fill().ok();
    });
    area
}
