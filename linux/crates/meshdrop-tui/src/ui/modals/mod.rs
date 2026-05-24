pub mod send;
pub mod pairing;
pub mod file_offer;

use ratatui::layout::Rect;

pub fn centered(w: u16, h: u16, full: Rect) -> Rect {
    let w = w.min(full.width);
    let h = h.min(full.height);
    let x = full.x + (full.width - w) / 2;
    let y = full.y + (full.height - h) / 2;
    Rect { x, y, width: w, height: h }
}
