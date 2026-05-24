//! MeshDrop GUI 入口（GTK4 / libadwaita）。
//!
//! 本轮 UI-FIRST：所有页面由 mock 数据驱动，不接 backend。等所有端 UI 对齐后，
//! 下一轮再把 meshdrop-core 的 ShareEngine 桥接回来。
//!
//! 隐藏的 `--screenshots <dir>` 模式：用 GTK4 snapshot API 把全部 page + dialog
//! × light/dark 渲染成 PNG 并退出（用于 PR 截图）。

mod components;
mod dialogs;
mod mock;
mod notify;
mod pages;
mod screenshots;
mod theme;
mod ui;

use adw::prelude::*;
use gtk::glib;

const APP_ID: &str = "com.welape.meshdrop.linux";

fn main() -> glib::ExitCode {
    env_logger::Builder::from_env(
        env_logger::Env::default().default_filter_or("info"),
    ).init();

    let args: Vec<String> = std::env::args().collect();
    let screenshot_dir: Option<String> = args.iter().position(|a| a == "--screenshots")
        .and_then(|i| args.get(i + 1).cloned())
        .or_else(|| if args.iter().any(|a| a == "--screenshots") {
            Some("screenshots".to_string())
        } else { None });

    // adw::Application 默认会拦截命令行参数并报错。用 HANDLES_COMMAND_LINE
    // 防止内置 default-handler 把我们的 --screenshots 视为非法。
    let app = adw::Application::builder()
        .application_id(APP_ID)
        .flags(gtk::gio::ApplicationFlags::NON_UNIQUE
             | gtk::gio::ApplicationFlags::HANDLES_COMMAND_LINE)
        .build();

    // 让 application 不去校验命令行：我们直接消费掉。
    app.connect_command_line(move |a, _cl| {
        a.activate();
        0
    });

    let app_for_wire = app.clone();
    app.connect_startup(move |_| theme::wire_app(&app_for_wire));

    if let Some(dir) = screenshot_dir {
        app.connect_activate(move |a| screenshots::run(a, &dir));
    } else {
        app.connect_activate(ui::build);
    }
    app.run()
}
