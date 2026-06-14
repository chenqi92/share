//! TransferRow：文件 icon (38×46) + name + size + 状态行 + 进度条 + speed/eta。
//! 状态色对应 §5：sending=flame ↑ / receiving=sky ↓ / done=limeDeep ✓ / failed=error × / queued=ink45 ·

use crate::components::{chip, file_chip};
use crate::mock::TransferState;
use crate::view::ViewTransferRow;
use adw::prelude::*;

/// 传输状态的本地化标签（i18n key 见 locales 的 state.*）。
fn state_label(s: TransferState) -> String {
    let key = match s {
        TransferState::Done      => "state.done",
        TransferState::Sending   => "state.sending",
        TransferState::Receiving => "state.receiving",
        TransferState::Queued    => "state.queued",
        TransferState::Failed    => "state.failed",
    };
    t!(key).to_string()
}

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
    let glyph_label = format!("{} {}", item.state.glyph(), state_label(item.state));
    let state_top = gtk::Box::new(gtk::Orientation::Horizontal, 6);
    state_top.set_halign(gtk::Align::End);
    state_top.append(&chip::chip(&glyph_label, state_tone, true));

    let is_active = matches!(item.state, TransferState::Sending | TransferState::Receiving);
    if is_active {
        if let Some(cb) = on_cancel {
            let btn = gtk::Button::from_icon_name("window-close-symbolic");
            btn.set_tooltip_text(Some(t!("transfers.cancel_tip").as_ref()));
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
            btn.set_label(t!("common.retry").as_ref());
            btn.set_tooltip_text(Some(t!("transfers.retry_tip").as_ref()));
            btn.add_css_class("flat");
            let hid = item.id;
            btn.connect_clicked(move |_| cb(hid));
            state_top.append(&btn);
        }
    }
    if matches!(item.state, TransferState::Done) {
        if let Some(path) = item.saved_path.clone() {
            let reveal_btn = gtk::Button::from_icon_name("folder-open-symbolic");
            reveal_btn.set_tooltip_text(Some(t!("transfers.reveal_tip").as_ref()));
            reveal_btn.add_css_class("flat");
            reveal_btn.add_css_class("circular");
            let parent = path.parent().map(|p| p.to_path_buf()).unwrap_or_else(|| path.clone());
            reveal_btn.connect_clicked(move |_| {
                let _ = std::process::Command::new("xdg-open").arg(&parent).spawn();
            });
            state_top.append(&reveal_btn);

            let open_btn = gtk::Button::from_icon_name("document-open-symbolic");
            open_btn.set_tooltip_text(Some(t!("transfers.open_tip").as_ref()));
            open_btn.add_css_class("flat");
            open_btn.add_css_class("circular");
            let p = path;
            open_btn.connect_clicked(move |_| {
                let _ = std::process::Command::new("xdg-open").arg(&p).spawn();
            });
            state_top.append(&open_btn);
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

    let is_failed = matches!(item.state, TransferState::Failed);
    let failed_fallback = t!("transfers.failed_fallback");
    let meta_str = if is_failed {
        // 失败：优先显示具体原因（校验失败 / 连接中断 / 拒收 …）
        format!("× {}", item.fail_reason.as_deref().unwrap_or(failed_fallback.as_ref()))
    } else {
        match (item.speed.as_deref(), item.eta.as_deref(), item.progress) {
            (Some(sp), Some(eta), _) => format!("{}  ·  ETA {}  ·  {}%", sp, eta, item.progress),
            (None,     Some(eta), 100) => format!("✓ {}  ·  {}", state_label(item.state), eta),
            (None,     None,      0)   => t!("transfers.queued").to_string(),
            _ => format!("{}%", item.progress),
        }
    };
    let meta = gtk::Label::new(Some(&meta_str));
    meta.add_css_class("meshdrop-meta");
    if is_failed { meta.add_css_class("meshdrop-error"); }
    meta.set_width_chars(28);
    meta.set_xalign(1.0);
    bottom.append(&meta);
    card.append(&bottom);

    card
}
