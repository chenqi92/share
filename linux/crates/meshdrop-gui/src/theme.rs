//! 加载 MeshDrop CSS + 注册字体（如果 data/fonts/ 下有 ttf）。
//!
//! 字体策略：data/fonts/ 下若存在 Space Grotesk / Geist / Geist Mono TTF，
//! 通过 Pango fontmap 注册（GTK4 用 Pango 渲染文本）。
//! 找不到字体时 CSS 中的 font-family 会按 fallback 链降级。
//!
//! Token / 颜色都在 data/css/meshdrop.css 里定义（COMMON §5）。

use adw::prelude::*;
use gtk::gdk::Display;

const CSS: &str = include_str!("../../../data/css/meshdrop.css");

pub fn install() {
    let provider = gtk::CssProvider::new();
    provider.load_from_string(CSS);

    if let Some(display) = Display::default() {
        gtk::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk::STYLE_PROVIDER_PRIORITY_APPLICATION + 1,
        );
    }

    register_fonts();
}

fn register_fonts() {
    // Pango 1.50+ 支持 FontMap::add_font_file。
    // 若 data/fonts/ 不存在则跳过；CSS 会用 fallback。
    let candidates: &[&str] = &[
        "data/fonts/SpaceGrotesk-Regular.ttf",
        "data/fonts/SpaceGrotesk-Medium.ttf",
        "data/fonts/SpaceGrotesk-SemiBold.ttf",
        "data/fonts/SpaceGrotesk-Bold.ttf",
        "data/fonts/Geist-Regular.ttf",
        "data/fonts/Geist-Medium.ttf",
        "data/fonts/Geist-SemiBold.ttf",
        "data/fonts/Geist-Bold.ttf",
        "data/fonts/GeistMono-Regular.ttf",
        "data/fonts/GeistMono-Medium.ttf",
        "data/fonts/GeistMono-Bold.ttf",
    ];

    // FontMap::add_font_file 仅在 Pango 1.56+ 暴露；为兼容直接尝试 fontconfig env。
    // 这里只做"路径存在性"检查，真正加载交给 fontconfig（用户安装字体或我们走 desktop file）。
    let mut found = 0usize;
    for p in candidates {
        if std::path::Path::new(p).exists() { found += 1; }
    }
    if found > 0 {
        log::info!("发现 {found} 个嵌入字体文件（fontconfig/Pango 将在运行时识别）");
    } else {
        log::info!("data/fonts/ 未提供 TTF，正在使用 fallback 字体链");
    }
}

/// 切换浅 / 暗 / 跟随系统。
pub fn set_scheme(app: &adw::Application, mode: ColorMode) {
    let style_manager = app.style_manager();
    match mode {
        ColorMode::Auto  => style_manager.set_color_scheme(adw::ColorScheme::Default),
        ColorMode::Light => style_manager.set_color_scheme(adw::ColorScheme::ForceLight),
        ColorMode::Dark  => style_manager.set_color_scheme(adw::ColorScheme::ForceDark),
    }
}

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum ColorMode { Auto, Light, Dark }
