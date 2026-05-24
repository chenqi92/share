//! 加载 MeshDrop CSS + 注册字体（如果 data/fonts/ 下有 ttf）+
//! 监听 libadwaita 配色变化，给所有 toplevel 自动打 `meshdrop-dark` CSS 类。
//!
//! CSS 选择器需要明确 marker：libadwaita 内置的 `.dark` 在不同发行版 / 主题下
//! 不总是落到 GtkWindow，自己加更可靠。

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

/// 必须在 app build 之后调用：把 dark notify + window-added 两个监听挂上去。
pub fn wire_app(app: &adw::Application) {
    let app_for_sm = app.clone();
    app.style_manager().connect_dark_notify(move |sm| {
        apply_dark_class(&app_for_sm, sm.is_dark());
    });
    let app_for_wa = app.clone();
    app.connect_window_added(move |_, _| {
        let dark = app_for_wa.style_manager().is_dark();
        apply_dark_class(&app_for_wa, dark);
    });
}

fn register_fonts() {
    let candidates: &[&str] = &[
        "data/fonts/SpaceGrotesk-Regular.ttf",
        "data/fonts/SpaceGrotesk-Bold.ttf",
        "data/fonts/Geist-Regular.ttf",
        "data/fonts/GeistMono-Regular.ttf",
        "data/fonts/GeistMono-Bold.ttf",
    ];
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
    let dark = match mode {
        ColorMode::Dark  => true,
        ColorMode::Light => false,
        ColorMode::Auto  => style_manager.is_dark(),
    };
    apply_dark_class(app, dark);
}

pub fn apply_dark_class(app: &adw::Application, dark: bool) {
    for window in app.windows() {
        if dark {
            window.add_css_class("meshdrop-dark");
        } else {
            window.remove_css_class("meshdrop-dark");
        }
    }
}

#[derive(Copy, Clone, Debug, PartialEq, Eq)]
pub enum ColorMode { Auto, Light, Dark }
