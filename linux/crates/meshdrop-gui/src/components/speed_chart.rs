//! SpeedChart：双向柱状速度图，上行 flame ↑ 下行 sky ↓。
//! 由 DrawingArea cairo 自绘。

use adw::prelude::*;
use std::cell::RefCell;
use std::rc::Rc;

/// 柱状图数据源：(上行高度, 下行高度)。共享给 draw_func，外部更新后 queue_draw。
pub type ChartData = Rc<RefCell<(Vec<u32>, Vec<u32>)>>;

/// 动态数据版：draw_func 每次从 `data` 读最新序列。外部更新 data 后调 `area.queue_draw()`。
pub fn chart_shared(data: ChartData, width: i32, height: i32) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(width).content_height(height).build();
    area.set_draw_func(move |_, cr, w, h| {
        let borrowed = data.borrow();
        let (up, down) = (&borrowed.0, &borrowed.1);
        let (w, h) = (w as f64, h as f64);
        let n = up.len().max(down.len()).max(1);
        let bw = w / n as f64 * 0.7;
        let gap = w / n as f64 * 0.3;
        let max_v = up.iter().chain(down.iter()).copied().max().unwrap_or(1) as f64;
        let mid = h / 2.0;
        let avail = h / 2.0 - 4.0;

        // mid line
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.10);
        cr.set_line_width(1.0);
        cr.move_to(0.0, mid); cr.line_to(w, mid); cr.stroke().ok();

        for i in 0..n {
            let x = i as f64 * (bw + gap) + gap / 2.0;
            // 上行 flame（朝上）
            if let Some(v) = up.get(i) {
                let bh = (*v as f64 / max_v) * avail;
                cr.set_source_rgba(1.0, 90.0/255.0, 44.0/255.0, 0.92);
                rounded_rect(cr, x, mid - bh, bw, bh, 2.0);
                cr.fill().ok();
            }
            // 下行 sky（朝下）
            if let Some(v) = down.get(i) {
                let bh = (*v as f64 / max_v) * avail;
                cr.set_source_rgba(77.0/255.0, 184.0/255.0, 1.0, 0.92);
                rounded_rect(cr, x, mid, bw, bh, 2.0);
                cr.fill().ok();
            }
        }
    });
    area
}

fn rounded_rect(cr: &gtk::cairo::Context, x: f64, y: f64, w: f64, h: f64, r: f64) {
    let r = r.min(w/2.0).min(h.abs()/2.0);
    cr.new_sub_path();
    cr.arc(x + w - r, y + r,     r, -std::f64::consts::FRAC_PI_2, 0.0);
    cr.arc(x + w - r, y + h - r, r, 0.0, std::f64::consts::FRAC_PI_2);
    cr.arc(x + r,     y + h - r, r, std::f64::consts::FRAC_PI_2, std::f64::consts::PI);
    cr.arc(x + r,     y + r,     r, std::f64::consts::PI, 3.0 * std::f64::consts::FRAC_PI_2);
    cr.close_path();
}
