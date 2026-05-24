//! `--screenshots <out_dir>` 模式：把所有页面 + 弹窗 + light/dark
//! 共 22 张 PNG 离线渲染并保存。
//!
//! 通过 GTK4 `WidgetPaintable::snapshot` + `Native::renderer().render_texture()`
//! 把窗口内容渲染成 `gdk::Texture`，再 `save_to_png`。
//!
//! 工作流：
//!   1. 创建 shell，present()
//!   2. 主循环 pump 一段时间等 layout
//!   3. 切换 stack → snapshot → 保存
//!   4. 切换 light/dark → 重复
//!   5. 弹出各对话框 → snapshot → close
//!   6. shell-light / shell-dark
//!   7. app.quit()

use crate::dialogs;
use crate::theme;
use crate::ui;
use adw::prelude::*;
use gtk::glib;
use std::path::Path;
use std::time::{Duration, Instant};

const PAGES: &[(&str, &str)] = &[
    ("discovery", "linux-gui-discovery"),
    ("chat",      "linux-gui-chat"),
    ("transfers", "linux-gui-transfers"),
    ("history",   "linux-gui-history"),
    ("trust",     "linux-gui-trust"),
    ("settings",  "linux-gui-settings"),
    ("empty",     "linux-gui-empty"),
];

pub fn run(app: &adw::Application, out_dir: &str) {
    let out_dir = out_dir.to_string();
    std::fs::create_dir_all(&out_dir).ok();

    let shell = ui::build_shell(app, None);
    shell.window.set_default_size(1280, 820);
    shell.window.present();
    pump_ms(700);

    // ── LIGHT ──
    theme::set_scheme(app, theme::ColorMode::Light);
    pump_ms(300);
    for (page, slug) in PAGES {
        shell.stack.set_visible_child_name(page);
        pump_ms(280);
        let path = format!("{}/{}-light.png", out_dir, slug);
        snapshot_window(&shell.window, &path);
        log::info!("📸  {path}");
    }
    shell.stack.set_visible_child_name("discovery");
    pump_ms(200);
    snapshot_window(&shell.window, &format!("{}/linux-gui-shell-light.png", out_dir));
    log::info!("📸  shell-light");

    // ── 弹窗（light）──
    let pair = dialogs::pairing::present(&shell.window, None);
    pair.set_default_size(560, 720);
    pump_ms(600);
    snapshot_window(&pair, &format!("{}/linux-gui-pairing-light.png", out_dir));
    log::info!("📸  pairing-light");
    pair.close();
    pump_ms(150);

    let offer = dialogs::file_offer::present(&shell.window, None);
    offer.set_default_size(520, 520);
    pump_ms(600);
    snapshot_window(&offer, &format!("{}/linux-gui-receive-light.png", out_dir));
    log::info!("📸  receive-light");
    offer.close();
    pump_ms(150);

    let onbo = dialogs::onboarding::present(&shell.window);
    onbo.set_default_size(600, 600);
    pump_ms(600);
    snapshot_window(&onbo, &format!("{}/linux-gui-onboarding-light.png", out_dir));
    log::info!("📸  onboarding-light");
    onbo.close();
    pump_ms(150);

    // ── DARK ──
    theme::set_scheme(app, theme::ColorMode::Dark);
    pump_ms(500);
    for (page, slug) in PAGES {
        shell.stack.set_visible_child_name(page);
        pump_ms(280);
        let path = format!("{}/{}-dark.png", out_dir, slug);
        snapshot_window(&shell.window, &path);
        log::info!("📸  {path}");
    }
    shell.stack.set_visible_child_name("discovery");
    pump_ms(200);
    snapshot_window(&shell.window, &format!("{}/linux-gui-shell-dark.png", out_dir));
    log::info!("📸  shell-dark");

    let pair = dialogs::pairing::present(&shell.window, None);
    pair.set_default_size(560, 720);
    pump_ms(600);
    snapshot_window(&pair, &format!("{}/linux-gui-pairing-dark.png", out_dir));
    log::info!("📸  pairing-dark");
    pair.close();
    pump_ms(150);

    let offer = dialogs::file_offer::present(&shell.window, None);
    offer.set_default_size(520, 520);
    pump_ms(600);
    snapshot_window(&offer, &format!("{}/linux-gui-receive-dark.png", out_dir));
    log::info!("📸  receive-dark");
    offer.close();
    pump_ms(150);

    let onbo = dialogs::onboarding::present(&shell.window);
    onbo.set_default_size(600, 600);
    pump_ms(600);
    snapshot_window(&onbo, &format!("{}/linux-gui-onboarding-dark.png", out_dir));
    log::info!("📸  onboarding-dark");
    onbo.close();
    pump_ms(150);

    // count
    let count = count_pngs(&out_dir);
    log::info!("== 完成 == 共 {count} 张 PNG 写到 {out_dir}");
    app.quit();
}

fn snapshot_window(window: &impl IsA<gtk::Widget>, path: &str) -> bool {
    let widget = window.clone().upcast::<gtk::Widget>();

    // 触发布局
    widget.queue_resize();
    pump_ms(60);

    let Some(native) = widget.native() else {
        log::warn!("no native for {path}");
        return false;
    };
    let Some(renderer) = native.renderer() else {
        log::warn!("no renderer for {path}");
        return false;
    };

    let w = widget.width().max(640);
    let h = widget.height().max(480);

    let paintable = gtk::WidgetPaintable::new(Some(&widget));
    let snapshot = gtk::Snapshot::new();
    paintable.snapshot(
        &snapshot.clone().upcast::<gtk::gdk::Snapshot>(),
        w as f64,
        h as f64,
    );

    let Some(node) = snapshot.to_node() else {
        log::warn!("no node for {path}");
        return false;
    };
    let bounds = gtk::graphene::Rect::new(0.0, 0.0, w as f32, h as f32);
    let texture = renderer.render_texture(&node, Some(&bounds));
    match texture.save_to_png(path) {
        Ok(()) => true,
        Err(e) => { log::warn!("save_to_png {path}: {e}"); false }
    }
}

fn pump_ms(ms: u64) {
    let ctx = glib::MainContext::default();
    let deadline = Instant::now() + Duration::from_millis(ms);
    while Instant::now() < deadline {
        // 处理所有立即可分发的事件
        while ctx.iteration(false) {}
        std::thread::sleep(Duration::from_millis(10));
    }
    // 再清一遍尾巴
    while ctx.iteration(false) {}
}

fn count_pngs(dir: &str) -> usize {
    let Ok(rd) = std::fs::read_dir(Path::new(dir)) else { return 0 };
    rd.filter_map(|e| e.ok())
        .filter(|e| e.path().extension().map(|x| x == "png").unwrap_or(false))
        .count()
}
