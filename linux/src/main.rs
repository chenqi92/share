mod device;
mod discovery;
mod identity;
mod txt;
mod ui;

use adw::prelude::*;
use gtk::glib;
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

use crate::device::Device;
use crate::discovery::Discovery;
use crate::identity::Identity;
use crate::ui::MainWindow;

const APP_ID: &str = "drop.mesh.linux";

fn main() -> glib::ExitCode {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();

    let app = adw::Application::builder().application_id(APP_ID).build();
    app.connect_activate(build_ui);
    app.run()
}

fn build_ui(app: &adw::Application) {
    let identity = match Identity::load_or_create() {
        Ok(i) => Arc::new(i),
        Err(e) => {
            eprintln!("identity load failed: {e}");
            return;
        }
    };

    let display_name = hostname_or_default();
    let main_window = MainWindow::new(app, &display_name, &identity.fingerprint);
    let window = main_window.window.clone();

    let shared: Rc<RefCell<Option<MainWindow>>> = Rc::new(RefCell::new(Some(main_window)));

    // 设备变更 → 转发到 GTK 主线程
    let (tx, rx) = async_channel::unbounded::<Vec<Device>>();
    let shared_for_ui = shared.clone();
    glib::spawn_future_local(async move {
        while let Ok(list) = rx.recv().await {
            if let Some(w) = shared_for_ui.borrow().as_ref() {
                w.update_devices(&list);
            }
        }
    });

    if let Err(e) = Discovery::start(
        identity.clone(),
        display_name,
        Some(linux_model_string()),
        move |list| {
            let _ = tx.send_blocking(list);
        },
    ) {
        eprintln!("discovery start failed: {e}");
    }

    window.present();
}

fn hostname_or_default() -> String {
    std::env::var("HOSTNAME")
        .ok()
        .or_else(|| {
            std::fs::read_to_string("/etc/hostname")
                .ok()
                .map(|s| s.trim().to_string())
        })
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Linux".to_string())
}

fn linux_model_string() -> String {
    std::fs::read_to_string("/sys/class/dmi/id/product_name")
        .ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Linux PC".to_string())
}
