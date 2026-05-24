//! FileChip：纸样 icon + 文件名 + 大小（可选进度）。
//! "纸样"用 cairo 自绘（白底 + 右上折角 + mono 大写扩展名彩色）。

use super::text;
use adw::prelude::*;

pub fn chip(name: &str, size: &str, ext: &str, progress: Option<u32>) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    row.set_valign(gtk::Align::Center);

    let icon = paper_icon(ext, 38, 46);
    row.append(&icon);

    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    col.set_valign(gtk::Align::Center);

    let nm = gtk::Label::new(Some(name));
    nm.set_halign(gtk::Align::Start);
    nm.set_ellipsize(gtk::pango::EllipsizeMode::Middle);
    nm.add_css_class("meshdrop-card-title");
    col.append(&nm);

    let sub = gtk::Label::new(Some(size));
    sub.set_halign(gtk::Align::Start);
    sub.add_css_class("meshdrop-meta");
    col.append(&sub);

    if let Some(p) = progress {
        let bar = gtk::ProgressBar::new();
        bar.set_fraction(p as f64 / 100.0);
        bar.set_hexpand(true);
        col.append(&bar);
    }
    row.append(&col);
    row
}

fn paper_icon(ext: &str, w: i32, h: i32) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(w).content_height(h).build();
    let ext_up = ext.to_uppercase();
    let (r, g, b) = ext_color(ext);
    area.set_draw_func(move |_, cr, w, h| {
        let pad = 1.5;
        let fold = 9.0;
        let rw = w as f64 - pad * 2.0;
        let rh = h as f64 - pad * 2.0;
        let x = pad;
        let y = pad;

        // 主体 path：右上角折一刀
        cr.new_path();
        cr.move_to(x, y);
        cr.line_to(x + rw - fold, y);
        cr.line_to(x + rw, y + fold);
        cr.line_to(x + rw, y + rh);
        cr.line_to(x, y + rh);
        cr.close_path();
        cr.set_source_rgb(1.0, 1.0, 1.0);
        cr.fill_preserve().ok();
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.5);
        cr.set_line_width(1.0);
        cr.stroke().ok();

        // 折角阴影三角
        cr.new_path();
        cr.move_to(x + rw - fold, y);
        cr.line_to(x + rw, y + fold);
        cr.line_to(x + rw - fold, y + fold);
        cr.close_path();
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.10);
        cr.fill().ok();

        // ext 标签底色块
        let tag_h = 12.0;
        let ty = y + rh - tag_h - 4.0;
        let tx = x + 4.0;
        let tw = rw - 8.0;
        cr.new_path();
        cr.rectangle(tx, ty, tw, tag_h);
        cr.set_source_rgba(r, g, b, 1.0);
        cr.fill().ok();

        // ext 文字（pango，自动 fallback）
        cr.set_source_rgb(1.0, 1.0, 1.0);
        text::draw_centered(cr, tx + tw / 2.0, ty + tag_h / 2.0, &ext_up, "Geist Mono", 9.0, true);
    });
    area
}

fn ext_color(ext: &str) -> (f64, f64, f64) {
    match ext.to_lowercase().as_str() {
        "fig" => (0.65, 0.31, 0.95),
        "zip" | "tar" | "7z" => (0.95, 0.40, 0.15),
        "pdf" => (0.86, 0.20, 0.20),
        "mp4" | "mov" | "mkv" => (0.30, 0.45, 0.95),
        "heic" | "jpg" | "jpeg" | "png" | "gif" => (0.10, 0.60, 0.40),
        "md" | "txt" => (0.06, 0.06, 0.06),
        "doc" | "docx" | "pages" => (0.16, 0.40, 0.85),
        _ => (0.32, 0.32, 0.32),
    }
}
