//! MeshDrop GUI 入口（GTK4 / libadwaita）。
//!
//! 启动流程：
//!   1. 建 tokio runtime + meshdrop-core::ShareEngine（mDNS + TCP listener）
//!   2. 启 Web Gateway（默认 :7384，rustls + 6 字符 pairing code）
//!   3. 进 GTK 主循环：ui::build_shell 接收 AppHandle，按 watch::Receiver
//!      订阅 engine 状态，更新 sidebar / pages / dialogs
//!
//! `--screenshots <dir>` 模式跳过 engine 启动，纯 mock 渲染（PR 截图用）。

mod components;
mod dialogs;
mod engine_bridge;
mod mock;
mod notify;
mod pages;
mod screenshots;
mod theme;
mod ui;
mod view;

use adw::prelude::*;
use gtk::glib;
use std::rc::Rc;

use engine_bridge::AppHandle;

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

    let app = adw::Application::builder()
        .application_id(APP_ID)
        .flags(gtk::gio::ApplicationFlags::NON_UNIQUE
             | gtk::gio::ApplicationFlags::HANDLES_COMMAND_LINE)
        .build();

    app.connect_command_line(move |a, _cl| {
        a.activate();
        0
    });

    let app_for_wire = app.clone();
    app.connect_startup(move |_| theme::wire_app(&app_for_wire));

    if let Some(dir) = screenshot_dir {
        app.connect_activate(move |a| screenshots::run(a, &dir));
    } else {
        // 真启动：先建 AppHandle，再交给 UI
        let handle = match AppHandle::start() {
            Ok(h) => Some(Rc::new(h)),
            Err(e) => {
                log::error!("AppHandle 启动失败：{}", e);
                None
            }
        };
        app.connect_activate(move |a| ui::build(a, handle.clone()));
    }
    app.run()
}
