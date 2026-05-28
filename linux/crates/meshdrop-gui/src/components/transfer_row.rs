//! TransferRow：文件 icon (38×46) + name + size + 状态行 + 进度条 + speed/eta。
//! 状态色对应 §5：sending=flame ↑ / receiving=sky ↓ / done=limeDeep ✓ / failed=error × / queued=ink45 ·

use crate::components::{chip, file_chip};
use crate::mock::TransferState;
use crate::view::ViewTransferRow;
use adw::prelude::*;

/// 渲染一行；`on_cancel` 非空且状态是 Sending / Receiving 时，状态 chip 右侧加取消按钮。
/// `on_retry` 非空且状态是 Failed 时，状态 chip 右侧加重试按钮。
pub fn row(
    item: &ViewTransferRow,
    on_cancel: Option<Box<dyn Fn(uuid::Uuid) + 'static>>,
    on_retry: Option<Box<dyn Fn(uuid::Uuid) + 'static>>,
) -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Vertical, 8);
    card.add_css_class("meshdrop-card");

    let top = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    top.set_valign(gtk::Align::Center);
    top.append(&file_chip::chip(&item.name, &item.size, &item.ext, None));

    let state_box = gtk::Box::new(gtk::Orientation::Vertical, 4);
    state_box.set_halign(gtk::Align::End);
    state_box.set_valign(gtk::Align::Center);
    let state_tone = match item.state {
        TransferState::Done      => chip::Tone::Lime,
        TransferState::Sending   => chip::Tone::Flame,
        TransferState::Receiving => chip::Tone::Sky,
        TransferState::Queued    => chip::Tone::Outline,
        TransferState::Failed    => chip::Tone::Error,
    };
    let glyph_label = format!("{} {}", item.state.glyph(), item.state.label_en());
    let state_top = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    state_top.set_halign(gtk::Align::End);
    state_top.append(&chip::chip(&glyph_label, state_tone, true));

    let is_active = matches!(item.state, TransferState::Sending | TransferState::Receiving);
    if is_active {
        if let Some(cb) = on_cancel {
            let btn = gtk::Button::from_icon_name("window-close-symbolic");
            btn.set_tooltip_text(Some("取消传输 · Cancel"));
            btn.add_css_class("flat");
            btn.add_css_class("circular");
            let hid = item.id;
            btn.connect_clicked(move |_| cb(hid));
            state_top.append(&btn);
        }
    }
    if matches!(item.state, TransferState::Failed) {
        if let Some(cb) = on_retry {
            let btn = gtk::Button::from_icon_name("view-refresh-symbolic");
            btn.set_label("RETRY");
            btn.set_tooltip_text(Some("重试发送 · Retry"));
            btn.add_css_class("flat");
            let hid = item.id;
            btn.connect_clicked(move |_| cb(hid));
            state_top.append(&btn);
        }
    }
    state_box.append(&state_top);

    let arrow = gtk::Label::new(Some(&format!("{}  →  {}", item.from, item.to)));
    arrow.add_css_class("meshdrop-meta");
    arrow.set_halign(gtk::Align::End);
    state_box.append(&arrow);

    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    top.append(&spacer);
    top.append(&state_box);
    card.append(&top);

    let bottom = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    let bar = gtk::ProgressBar::new();
    bar.set_fraction(item.progress as f64 / 100.0);
    bar.add_css_class(item.state.css_class());
    bar.set_hexpand(true);
    bar.set_valign(gtk::Align::Center);
    bottom.append(&bar);

    let meta_str = match (item.speed.as_deref(), item.eta.as_deref(), item.progress) {
        (Some(sp), Some(eta), _) => format!("{}  ·  ETA {}  ·  {}%", sp, eta, item.progress),
        (None,     Some(eta), 100) => format!("✓ {}  ·  {}", item.state.label_cn(), eta),
        (None,     None,      0)   => "排队中…".to_string(),
        _ => format!("{}%", item.progress),
    };
    let meta = gtk::Label::new(Some(&meta_str));
    meta.add_css_class("meshdrop-meta");
    meta.set_width_chars(28);
    meta.set_xalign(1.0);
    bottom.append(&meta);
    card.append(&bottom);

    card
}
