use crate::device::{Device, DeviceOS};
use adw::prelude::*;
use gtk::glib;
use std::cell::RefCell;
use std::rc::Rc;

pub struct MainWindow {
    pub window: adw::ApplicationWindow,
    list_box: gtk::ListBox,
    empty_state: adw::StatusPage,
    stack: gtk::Stack,
    title_row: adw::ActionRow,
    fingerprint_label: gtk::Label,
}

impl MainWindow {
    pub fn new(app: &adw::Application, display_name: &str, fingerprint: &str) -> Self {
        let window = adw::ApplicationWindow::builder()
            .application(app)
            .default_width(480)
            .default_height(640)
            .title("MeshDrop")
            .icon_name("drop.mesh.linux")
            .build();

        let toolbar_view = adw::ToolbarView::new();
        let header = adw::HeaderBar::new();
        let title = adw::WindowTitle::new("MeshDrop", "局域网分享");
        header.set_title_widget(Some(&title));
        toolbar_view.add_top_bar(&header);

        let content = gtk::Box::new(gtk::Orientation::Vertical, 0);

        // 顶部本机卡片
        let group = adw::PreferencesGroup::new();
        group.set_margin_top(12);
        group.set_margin_bottom(12);
        group.set_margin_start(12);
        group.set_margin_end(12);

        let title_row = adw::ActionRow::builder()
            .title(display_name)
            .subtitle("正在广告本机…")
            .build();
        let icon = gtk::Image::from_icon_name("network-wireless-symbolic");
        title_row.add_prefix(&icon);

        let fingerprint_label = gtk::Label::builder()
            .label(&fingerprint[..16])
            .css_classes(["caption", "monospace", "dim-label"])
            .build();
        title_row.add_suffix(&fingerprint_label);

        group.add(&title_row);
        content.append(&group);

        // 设备列表 / 空状态切换
        let stack = gtk::Stack::new();
        stack.set_vexpand(true);

        let list_box = gtk::ListBox::builder()
            .selection_mode(gtk::SelectionMode::None)
            .css_classes(["boxed-list"])
            .margin_start(12)
            .margin_end(12)
            .margin_bottom(12)
            .build();
        let scroller = gtk::ScrolledWindow::builder()
            .hscrollbar_policy(gtk::PolicyType::Never)
            .child(&list_box)
            .build();

        let empty_state = adw::StatusPage::builder()
            .icon_name("system-search-symbolic")
            .title("正在搜索附近设备")
            .description("确保对方设备在同一 Wi-Fi 下并已启动 MeshDrop")
            .build();

        stack.add_named(&empty_state, Some("empty"));
        stack.add_named(&scroller, Some("list"));
        stack.set_visible_child_name("empty");

        content.append(&stack);
        toolbar_view.set_content(Some(&content));
        window.set_content(Some(&toolbar_view));

        Self {
            window,
            list_box,
            empty_state: empty_state.clone(),
            stack,
            title_row,
            fingerprint_label,
        }
    }

    pub fn update_devices(&self, devices: &[Device]) {
        // 清空
        while let Some(child) = self.list_box.first_child() {
            self.list_box.remove(&child);
        }
        if devices.is_empty() {
            self.stack.set_visible_child_name("empty");
            return;
        }
        for d in devices {
            self.list_box.append(&row_for(d));
        }
        self.stack.set_visible_child_name("list");
    }
}

fn row_for(device: &Device) -> adw::ActionRow {
    let row = adw::ActionRow::builder()
        .title(&device.name)
        .subtitle(
            device
                .model
                .as_ref()
                .map(|m| format!("{} · {}", device.os, m))
                .unwrap_or_else(|| device.os.to_string()),
        )
        .activatable(true)
        .build();
    row.add_prefix(&gtk::Image::from_icon_name(icon_name(device.os)));
    let chevron = gtk::Image::from_icon_name("go-next-symbolic");
    chevron.add_css_class("dim-label");
    row.add_suffix(&chevron);
    row
}

fn icon_name(os: DeviceOS) -> &'static str {
    match os {
        DeviceOS::Ios | DeviceOS::Android => "phone-symbolic",
        DeviceOS::Macos | DeviceOS::Windows | DeviceOS::Linux => "computer-symbolic",
    }
}

/// 用 RefCell 共享 MainWindow 引用，给后台线程通过 glib::idle_add_local 推更新。
pub type SharedWindow = Rc<RefCell<Option<MainWindow>>>;
