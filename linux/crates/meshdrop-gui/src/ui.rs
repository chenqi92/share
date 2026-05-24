//! GTK4 / libadwaita UI。简化版：libadwaita 标准 widget。
//! 重点是把 core 的 ShareEngine 完整接进来。

use adw::prelude::*;
use meshdrop_core::{
    history::format_bytes, Device, DeviceOS, HistoryItem, HistoryKind, PairingDecision,
    PendingFileOffer, PendingPairing, ShareEngine, TransferDirection, TransferStatus,
};
use std::cell::RefCell;
use std::path::PathBuf;
use std::rc::Rc;

#[derive(Clone)]
pub struct MainWindow {
    pub window: adw::ApplicationWindow,
    inner: Rc<Inner>,
}

struct Inner {
    devices_box: gtk::ListBox,
    devices_state: RefCell<Vec<Device>>,
    history_box: gtk::ListBox,
    engine: RefCell<Option<ShareEngine>>,
}

impl MainWindow {
    pub fn new(app: &adw::Application, display_name: &str, fingerprint: &str) -> Self {
        let window = adw::ApplicationWindow::builder()
            .application(app)
            .default_width(560)
            .default_height(720)
            .title("MeshDrop")
            .icon_name("drop.mesh.linux")
            .build();

        let toolbar = adw::ToolbarView::new();
        let header = adw::HeaderBar::new();
        header.set_title_widget(Some(&adw::WindowTitle::new("MeshDrop", "局域网分享")));
        toolbar.add_top_bar(&header);

        let content = gtk::Box::new(gtk::Orientation::Vertical, 0);

        // 顶部 SelfBanner
        let group = adw::PreferencesGroup::new();
        group.set_margin_top(12); group.set_margin_bottom(12);
        group.set_margin_start(12); group.set_margin_end(12);
        let title_row = adw::ActionRow::builder()
            .title(display_name)
            .subtitle(format!("本机 · 指纹 {}", &fingerprint[..8]))
            .build();
        let icon = gtk::Image::from_icon_name("network-wireless-symbolic");
        title_row.add_prefix(&icon);
        group.add(&title_row);
        content.append(&group);

        let devices_label = gtk::Label::builder()
            .label("附近设备")
            .halign(gtk::Align::Start)
            .margin_start(20).margin_top(8).margin_bottom(6)
            .css_classes(["heading"])
            .build();
        content.append(&devices_label);

        let devices_box = gtk::ListBox::builder()
            .selection_mode(gtk::SelectionMode::None)
            .css_classes(["boxed-list"])
            .margin_start(12).margin_end(12).margin_bottom(8)
            .build();
        content.append(&devices_box);

        let history_label = gtk::Label::builder()
            .label("历史")
            .halign(gtk::Align::Start)
            .margin_start(20).margin_top(8).margin_bottom(6)
            .css_classes(["heading"])
            .build();
        content.append(&history_label);

        let history_scroll = gtk::ScrolledWindow::builder()
            .hscrollbar_policy(gtk::PolicyType::Never)
            .vexpand(true)
            .build();
        let history_box = gtk::ListBox::builder()
            .selection_mode(gtk::SelectionMode::None)
            .css_classes(["boxed-list"])
            .margin_start(12).margin_end(12).margin_bottom(12)
            .build();
        history_scroll.set_child(Some(&history_box));
        content.append(&history_scroll);

        toolbar.set_content(Some(&content));
        window.set_content(Some(&toolbar));

        Self {
            window,
            inner: Rc::new(Inner {
                devices_box,
                devices_state: RefCell::new(Vec::new()),
                history_box,
                engine: RefCell::new(None),
            }),
        }
    }

    pub fn set_engine(&self, engine: ShareEngine) {
        *self.inner.engine.borrow_mut() = Some(engine);
    }

    pub fn update_devices(&self, devices: &[Device]) {
        *self.inner.devices_state.borrow_mut() = devices.to_vec();
        let listbox = &self.inner.devices_box;
        while let Some(child) = listbox.first_child() { listbox.remove(&child); }

        if devices.is_empty() {
            let placeholder = adw::ActionRow::builder()
                .title("正在搜索附近设备…")
                .subtitle("确保对方设备在同一 Wi-Fi 或局域网下，并已启动 MeshDrop")
                .build();
            listbox.append(&placeholder);
            return;
        }

        for d in devices {
            let row = adw::ActionRow::builder()
                .title(&d.name)
                .subtitle(device_subtitle(d))
                .activatable(true)
                .build();
            row.add_prefix(&gtk::Image::from_icon_name(os_icon(d.os)));
            row.add_suffix(&gtk::Image::from_icon_name("go-next-symbolic"));

            let win = self.window.clone();
            let engine_ref = self.inner.engine.clone();
            let device_clone = d.clone();
            row.connect_activated(move |_| {
                if let Some(engine) = engine_ref.borrow().clone() {
                    show_send_dialog(&win, engine, device_clone.clone());
                }
            });
            listbox.append(&row);
        }
    }

    pub fn update_history(&self, history: &[HistoryItem]) {
        let listbox = &self.inner.history_box;
        while let Some(child) = listbox.first_child() { listbox.remove(&child); }
        if history.is_empty() {
            let placeholder = adw::ActionRow::builder().title("暂无历史").build();
            listbox.append(&placeholder);
            return;
        }
        for item in history.iter().take(50) {
            let arrow = if item.direction == TransferDirection::Outgoing { "↗" } else { "↙" };
            let title = format!("{} {} · {}", arrow, item.peer.name, history_content(&item.kind));
            let subtitle = history_status(&item.status);
            let row = adw::ActionRow::builder()
                .title(&title)
                .subtitle(&subtitle)
                .build();
            listbox.append(&row);
        }
    }

    pub fn show_pairing(&self, pending: PendingPairing, engine: ShareEngine) {
        let dialog = adw::MessageDialog::builder()
            .transient_for(&self.window)
            .heading(format!("{} 想要连接", pending.peer.name))
            .body(format!("指纹: {}\n\n请确认与对方设备显示的一致再放行。", pending.peer.human_fingerprint()))
            .build();
        dialog.add_response("reject", "拒绝");
        dialog.add_response("once", "允许一次");
        dialog.add_response("trust", "允许并记住");
        dialog.set_response_appearance("trust", adw::ResponseAppearance::Suggested);
        dialog.set_response_appearance("reject", adw::ResponseAppearance::Destructive);
        let pid = pending.id;
        dialog.connect_response(None, move |dlg, resp| {
            let decision = match resp {
                "trust" => PairingDecision::Trust,
                "once"  => PairingDecision::AllowOnce,
                _       => PairingDecision::Reject,
            };
            engine.respond_pairing(pid, decision);
            dlg.close();
        });
        dialog.present();
    }

    pub fn show_file_offer(&self, offer: PendingFileOffer, engine: ShareEngine) {
        let dialog = adw::MessageDialog::builder()
            .transient_for(&self.window)
            .heading(format!("{} 想发送文件", offer.peer.name))
            .body(format!("{} ({})\n\n保存到 ~/Downloads/MeshDrop/", offer.file_name, offer.formatted_size()))
            .build();
        dialog.add_response("reject", "拒绝");
        dialog.add_response("accept", "接受");
        dialog.set_response_appearance("accept", adw::ResponseAppearance::Suggested);
        dialog.set_response_appearance("reject", adw::ResponseAppearance::Destructive);
        let oid = offer.id;
        dialog.connect_response(None, move |dlg, resp| {
            engine.respond_file_offer(oid, resp == "accept");
            dlg.close();
        });
        dialog.present();
    }
}

// ─── 辅助 ────────────────────────────────────────────────────────────

fn os_icon(os: DeviceOS) -> &'static str {
    match os {
        DeviceOS::Ios | DeviceOS::Android => "phone-symbolic",
        DeviceOS::Macos | DeviceOS::Windows | DeviceOS::Linux => "computer-symbolic",
    }
}

fn device_subtitle(d: &Device) -> String {
    match &d.model {
        Some(m) => format!("{} · {}", d.os, m),
        None => d.os.to_string(),
    }
}

fn history_content(kind: &HistoryKind) -> String {
    match kind {
        HistoryKind::Text(s) => {
            if s.chars().count() > 40 {
                let truncated: String = s.chars().take(40).collect();
                format!("{}…", truncated)
            } else { s.clone() }
        }
        HistoryKind::File { name, size, .. } => format!("📄 {} ({})", name, format_bytes(*size)),
    }
}

fn history_status(status: &TransferStatus) -> String {
    match status {
        TransferStatus::Pending => "准备中…".into(),
        TransferStatus::WaitingApproval => "等待对方接受…".into(),
        TransferStatus::Transferring { done, total } =>
            format!("{} / {}", format_bytes(*done), format_bytes(*total)),
        TransferStatus::Completed => "✓ 完成".into(),
        TransferStatus::Failed(r) => format!("✗ {}", r),
        TransferStatus::Canceled => "已取消".into(),
    }
}

// ─── SendDialog ──────────────────────────────────────────────────────

fn show_send_dialog(parent: &adw::ApplicationWindow, engine: ShareEngine, device: Device) {
    let dialog = adw::Window::builder()
        .transient_for(parent)
        .modal(true)
        .title(format!("发送到 {}", device.name))
        .default_width(420)
        .default_height(360)
        .build();

    let toolbar = adw::ToolbarView::new();
    let header = adw::HeaderBar::new();
    toolbar.add_top_bar(&header);

    let content = gtk::Box::new(gtk::Orientation::Vertical, 12);
    content.set_margin_top(16); content.set_margin_bottom(16);
    content.set_margin_start(16); content.set_margin_end(16);

    let stack = gtk::Stack::new();

    let text_view = gtk::TextView::builder()
        .accepts_tab(false)
        .top_margin(8).bottom_margin(8).left_margin(8).right_margin(8)
        .build();
    let text_scroll = gtk::ScrolledWindow::builder()
        .min_content_height(140)
        .css_classes(["card"])
        .child(&text_view)
        .build();
    stack.add_titled(&text_scroll, Some("text"), "文本");

    let file_box = gtk::Box::new(gtk::Orientation::Vertical, 8);
    let file_label = gtk::Label::builder()
        .label("未选择文件")
        .halign(gtk::Align::Start)
        .build();
    let pick_btn = gtk::Button::with_label("选择文件…");
    file_box.append(&pick_btn);
    file_box.append(&file_label);
    stack.add_titled(&file_box, Some("file"), "文件");

    let stack_switcher = gtk::StackSwitcher::builder()
        .stack(&stack)
        .halign(gtk::Align::Center)
        .build();
    content.append(&stack_switcher);
    content.append(&stack);

    let btn_box = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    btn_box.set_halign(gtk::Align::End);
    let cancel_btn = gtk::Button::with_label("取消");
    let send_btn = gtk::Button::with_label("发送");
    send_btn.add_css_class("suggested-action");
    btn_box.append(&cancel_btn);
    btn_box.append(&send_btn);
    content.append(&btn_box);

    toolbar.set_content(Some(&content));
    dialog.set_content(Some(&toolbar));

    let selected_file: Rc<RefCell<Option<PathBuf>>> = Rc::new(RefCell::new(None));

    let file_label_c = file_label.clone();
    let selected_c = selected_file.clone();
    let parent_c = parent.clone();
    pick_btn.connect_clicked(move |_| {
        let chooser = gtk::FileChooserDialog::builder()
            .title("选择要发送的文件")
            .transient_for(&parent_c)
            .modal(true)
            .action(gtk::FileChooserAction::Open)
            .build();
        chooser.add_button("取消", gtk::ResponseType::Cancel);
        chooser.add_button("选择", gtk::ResponseType::Accept);
        let selected_inner = selected_c.clone();
        let label_inner = file_label_c.clone();
        chooser.connect_response(move |c, resp| {
            if resp == gtk::ResponseType::Accept {
                if let Some(file) = c.file().and_then(|f| f.path()) {
                    let name = file.file_name().and_then(|n| n.to_str()).unwrap_or("?").to_string();
                    let size = std::fs::metadata(&file).map(|m| m.len()).unwrap_or(0);
                    label_inner.set_text(&format!("{} ({})", name, format_bytes(size)));
                    *selected_inner.borrow_mut() = Some(file);
                }
            }
            c.close();
        });
        chooser.present();
    });

    let dialog_c = dialog.clone();
    cancel_btn.connect_clicked(move |_| dialog_c.close());

    let stack_c = stack.clone();
    let text_view_c = text_view.clone();
    let selected_c2 = selected_file.clone();
    let engine_c = engine.clone();
    let device_c = device.clone();
    let dialog_c = dialog.clone();
    send_btn.connect_clicked(move |_| {
        match stack_c.visible_child_name().as_deref() {
            Some("text") => {
                let buffer = text_view_c.buffer();
                let (start, end) = buffer.bounds();
                let text = buffer.text(&start, &end, false).to_string();
                if !text.trim().is_empty() {
                    engine_c.send_text(device_c.clone(), text);
                }
            }
            Some("file") => {
                if let Some(path) = selected_c2.borrow().clone() {
                    engine_c.send_file(device_c.clone(), path);
                }
            }
            _ => {}
        }
        dialog_c.close();
    });

    dialog.present();
}
