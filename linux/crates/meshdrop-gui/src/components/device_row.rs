//! sidebar / 列表行用的小卡片。
//! avatar(28) + KindGlyph + 名字 + (OS · RTT) + 在线小点
//! selected 时背景 lime_soft + 1px lime 描边。

use crate::components::{avatar::{avatar, Ring}, chip::dot, icon_btn, kind_glyph::glyph};
use crate::engine_bridge::AppHandle;
use crate::view::ViewDevice;
use adw::prelude::*;
use gtk::gio::prelude::FileExt; // gio::File::path()
use std::rc::Rc;

pub fn build(d: &ViewDevice, selected: bool) -> gtk::Box {
    build_with_handle(d, selected, None)
}

/// 带 engine 句柄版本：附一个「发送」按钮，点了弹文件选择器并调 engine.send_file。
/// handle 为 None（sidebar / screenshots mock）时不加发送按钮。
pub fn build_with_handle(
    d: &ViewDevice,
    selected: bool,
    handle: Option<&Rc<AppHandle>>,
) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    row.add_css_class("meshdrop-device-row");
    if selected { row.add_css_class("selected"); }

    let av = avatar(&d.initials, &d.color, 32, Ring::None);
    row.append(&av);

    let col = gtk::Box::new(gtk::Orientation::Vertical, 1);
    col.set_hexpand(true);
    col.set_valign(gtk::Align::Center);

    let name = gtk::Label::new(Some(&d.name));
    name.set_halign(gtk::Align::Start);
    name.add_css_class("meshdrop-card-title");
    col.append(&name);

    let sub_row = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    sub_row.set_halign(gtk::Align::Start);
    sub_row.append(&glyph(d.kind, 11));
    let rtt = if d.rtt_ms > 0 { format!("{} ms", d.rtt_ms) } else { "—".to_string() };
    let sub = gtk::Label::new(Some(&format!("{} · {}", d.os, rtt)));
    sub.add_css_class("meshdrop-meta");
    sub_row.append(&sub);
    col.append(&sub_row);

    row.append(&col);

    let online_dot = dot("#A8C800", 8);
    online_dot.set_valign(gtk::Align::Center);
    online_dot.set_halign(gtk::Align::Center);
    row.append(&online_dot);

    // 真实 engine 模式：附发送按钮（discovery 右栏列表用）。
    if let Some(h) = handle {
        let send = icon_btn::icon_btn(&t!("common.send"), &t!("device_row.send_tip"), icon_btn::IconBtnTone::Accent);
        send.set_valign(gtk::Align::Center);
        let h_c = h.clone();
        let dev_id = d.id.clone();
        let dev_name = d.name.clone();
        send.connect_clicked(move |_| {
            // 实时按 id 取当前 CoreDevice（host / 在线状态可能已变）。
            let Some(peer) = h_c.devices().into_iter().find(|dv| dv.id == dev_id) else {
                log::warn!("（discovery）{} 已离线，无法发送", dev_name);
                return;
            };
            pick_file_and_send(&h_c, peer);
        });
        row.append(&send);
    }

    row
}

/// 弹 GTK 文件选择器；用户确认后调 engine.send_file 把文件发给 peer。
fn pick_file_and_send(handle: &Rc<AppHandle>, peer: meshdrop_core::Device) {
    let dialog = gtk::FileDialog::builder()
        .title(t!("device_row.pick_file_title").as_ref())
        .modal(true)
        .build();
    let h_c = handle.clone();
    let peer_name = peer.name.clone();
    // parent 传 None：modal 文件对话框仍能正常弹出，避免向上 downcast 顶层窗口。
    dialog.open(
        gtk::Window::NONE,
        gtk::gio::Cancellable::NONE,
        move |res| match res {
            Ok(file) => {
                if let Some(path) = file.path() {
                    log::info!("（discovery）发送 {:?} → {}", path, peer_name);
                    h_c.send_file(peer.clone(), path);
                }
            }
            // 用户取消 / 关闭对话框 —— 静默忽略。
            Err(e) => log::debug!("文件选择取消：{}", e),
        },
    );
}
