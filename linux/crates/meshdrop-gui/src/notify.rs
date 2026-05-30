//! 桌面通知封装：用 GIO 的 `Notification` + `Application::send_notification`，
//! 走 org.freedesktop.Notifications / org.gtk.Notifications，无需额外依赖。

use gtk::gio;
use gtk::prelude::*;

pub fn toast(app: &impl IsA<gio::Application>, summary: &str, body: &str) {
    let n = gio::Notification::new(summary);
    n.set_body(Some(body));
    app.send_notification(None, &n);
}
