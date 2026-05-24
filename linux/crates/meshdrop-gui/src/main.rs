//! MeshDrop GUI 入口（GTK4 / libadwaita）。
//!
//! 本轮 UI-FIRST：所有页面由 mock 数据驱动，不接 backend。等所有端 UI 对齐后，
//! 下一轮再把 meshdrop-core 的 ShareEngine 桥接回来。

mod components;
mod dialogs;
mod mock;
mod notify;
mod pages;
mod theme;
mod ui;

use adw::prelude::*;
use gtk::glib;

const APP_ID: &str = "com.welape.meshdrop.linux";

fn main() -> glib::ExitCode {
    env_logger::Builder::from_env(
        env_logger::Env::default().default_filter_or("info"),
    ).init();

    let app = adw::Application::builder()
        .application_id(APP_ID)
        .build();
    app.connect_activate(ui::build);
    app.run()
}
