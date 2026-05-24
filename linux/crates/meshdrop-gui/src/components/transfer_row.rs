//! TransferRow：文件 icon (38×46) + name + size + 状态行 + 进度条 + speed/eta。
//! 状态色对应 §5：sending=flame ↑ / receiving=sky ↓ / done=limeDeep ✓ / failed=error × / queued=ink45 ·

use crate::components::{chip, file_chip};
use crate::mock::{TransferRow, TransferState};
use adw::prelude::*;

pub fn row(item: &TransferRow) -> gtk::Box {
    let card = gtk::Box::new(gtk::Orientation::Vertical, 8);
    card.add_css_class("meshdrop-card");

    // 顶部：file_chip + 状态 chip + arrow
    let top = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    top.set_valign(gtk::Align::Center);
    top.append(&file_chip::chip(item.name, item.size, item.ext, None));

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
    state_box.append(&chip::chip(&glyph_label, state_tone, true));

    let arrow = gtk::Label::new(Some(&format!("{}  →  {}", item.from, item.to)));
    arrow.add_css_class("meshdrop-meta");
    arrow.set_halign(gtk::Align::End);
    state_box.append(&arrow);

    let spacer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    spacer.set_hexpand(true);
    top.append(&spacer);
    top.append(&state_box);
    card.append(&top);

    // 进度条 + speed / eta
    let bottom = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    let bar = gtk::ProgressBar::new();
    bar.set_fraction(item.progress as f64 / 100.0);
    bar.add_css_class(item.state.css_class());
    bar.set_hexpand(true);
    bar.set_valign(gtk::Align::Center);
    bottom.append(&bar);

    let meta_str = match (item.speed, item.eta, item.progress) {
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
