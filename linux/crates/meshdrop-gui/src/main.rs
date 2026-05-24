//! MeshDrop GUI 入口。使用 GTK4 / libadwaita。
//!
//! 桥接 tokio (meshdrop-core 的引擎) 和 GLib 主循环：
//! - 在 GTK app activate 之前启 tokio runtime
//! - 各 watch::Receiver 由后台 tokio task 监听，通过 async_channel 推给 GTK 主线程

mod ui;

use adw::prelude::*;
use anyhow::Result;
use gtk::glib;
use meshdrop_core::{
    Device, HistoryItem, Identity, PendingFileOffer, PendingPairing, ShareEngine,
};
use std::sync::Arc;
use std::sync::OnceLock;

const APP_ID: &str = "drop.mesh.linux";

static TOKIO_RT: OnceLock<tokio::runtime::Runtime> = OnceLock::new();

fn rt() -> &'static tokio::runtime::Runtime {
    TOKIO_RT.get_or_init(|| {
        tokio::runtime::Builder::new_multi_thread()
            .enable_all().build().expect("tokio rt")
    })
}

fn main() -> glib::ExitCode {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    let _ = rt();      // 提前初始化 runtime

    let app = adw::Application::builder().application_id(APP_ID).build();
    app.connect_activate(build_ui);
    app.run()
}

fn build_ui(app: &adw::Application) {
    let identity = match Identity::load_or_create() {
        Ok(i) => Arc::new(i),
        Err(e) => { eprintln!("identity load failed: {e}"); return; }
    };
    let display_name = hostname_or_default();
    let model = linux_model_string();

    // 启动引擎（block_on tokio runtime）
    let engine = match rt().block_on(ShareEngine::start(identity.clone(), display_name.clone(), Some(model))) {
        Ok(e) => e,
        Err(e) => { eprintln!("engine start failed: {e}"); return; }
    };

    let win = ui::MainWindow::new(app, &display_name, &identity.fingerprint);
    let window = win.window.clone();

    // 4 个 watch 通道桥接到 GTK 主循环
    let (dev_tx, dev_rx) = async_channel::unbounded::<Vec<Device>>();
    let (his_tx, his_rx) = async_channel::unbounded::<Vec<HistoryItem>>();
    let (pp_tx, pp_rx)   = async_channel::unbounded::<Vec<PendingPairing>>();
    let (po_tx, po_rx)   = async_channel::unbounded::<Vec<PendingFileOffer>>();

    spawn_watch_forwarder(engine.devices_rx(), dev_tx);
    spawn_watch_forwarder(engine.history_rx(), his_tx);
    spawn_watch_forwarder(engine.pending_pairings_rx(), pp_tx);
    spawn_watch_forwarder(engine.pending_offers_rx(), po_tx);

    let win_for_dev = win.clone();
    glib::spawn_future_local(async move {
        while let Ok(list) = dev_rx.recv().await { win_for_dev.update_devices(&list); }
    });
    let win_for_his = win.clone();
    glib::spawn_future_local(async move {
        while let Ok(list) = his_rx.recv().await { win_for_his.update_history(&list); }
    });
    let engine_for_pair = engine.clone();
    let win_for_pp = win.clone();
    glib::spawn_future_local(async move {
        while let Ok(list) = pp_rx.recv().await {
            if let Some(pair) = list.first() {
                win_for_pp.show_pairing(pair.clone(), engine_for_pair.clone());
            }
        }
    });
    let engine_for_offer = engine.clone();
    let win_for_po = win.clone();
    glib::spawn_future_local(async move {
        while let Ok(list) = po_rx.recv().await {
            if let Some(offer) = list.first() {
                win_for_po.show_file_offer(offer.clone(), engine_for_offer.clone());
            }
        }
    });

    win.set_engine(engine);
    window.present();
}

fn spawn_watch_forwarder<T: Clone + Send + 'static>(
    mut rx: tokio::sync::watch::Receiver<T>,
    tx: async_channel::Sender<T>,
) {
    rt().spawn(async move {
        loop {
            // borrow + clone + send
            let value = rx.borrow().clone();
            if tx.send(value).await.is_err() { break; }
            if rx.changed().await.is_err() { break; }
        }
    });
}

fn hostname_or_default() -> String {
    std::env::var("HOSTNAME").ok()
        .or_else(|| std::fs::read_to_string("/etc/hostname").ok().map(|s| s.trim().to_string()))
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Linux".to_string())
}

fn linux_model_string() -> String {
    std::fs::read_to_string("/sys/class/dmi/id/product_name").ok()
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Linux PC".to_string())
}
