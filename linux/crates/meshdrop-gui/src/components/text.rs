//! 把 pango layout 居中绘到 cairo 上的小工具。
//! 比 cairo toy text 强：自动 fontconfig fallback，能渲染 CJK / emoji。

use gtk::cairo;
use gtk::pango;

/// 在 (cx, cy) 居中绘制一段文字。
/// `family_pri` 是首选字体（找不到自动 fallback 到系统 sans）。
pub fn draw_centered(
    cr: &cairo::Context,
    cx: f64, cy: f64,
    text: &str,
    family_pri: &str,
    px: f64,
    bold: bool,
) {
    let layout = pangocairo::functions::create_layout(cr);
    let weight = if bold { "Bold" } else { "Regular" };
    // 多字体 fallback 链：首选 → 中文 → 系统 sans
    let desc_str = format!(
        "{family_pri},PingFang SC,Noto Sans CJK SC,Noto Sans SC,sans {weight} {}px",
        px as i32
    );
    let desc = pango::FontDescription::from_string(&desc_str);
    layout.set_font_description(Some(&desc));
    layout.set_text(text);
    let (tw, th) = layout.pixel_size();
    cr.move_to(cx - tw as f64 / 2.0, cy - th as f64 / 2.0);
    pangocairo::functions::show_layout(cr, &layout);
}
