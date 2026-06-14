//! Pairing 弹窗：从 engine.pending_pairings_rx 取第一条挂起的请求；
//! 三个按钮分别派发 PairingDecision::Reject / AllowOnce / Trust。
//! handle 为 None 时（screenshots）回退到 mock 数据。

use crate::components::{ascii_divider, avatar, chip};
use crate::engine_bridge::AppHandle;
use crate::mock;
use adw::prelude::*;
use meshdrop_core::PairingDecision;
use std::rc::Rc;
use uuid::Uuid;

struct PairingView {
    title: String,
    sub: String,
    device_name: String,
    initials: String,
    code: String,
    fingerprint_full: String,
    pairing_id: Option<Uuid>,
}

pub fn present(parent: &impl IsA<gtk::Window>, handle: Option<&Rc<AppHandle>>) -> adw::Window {
    let view = build_view(handle);

    let win = adw::Window::builder()
        .transient_for(parent)
        .modal(true)
        .title("配对 · Pairing")
        .default_width(520)
        .default_height(620)
        .build();

    let toolbar = adw::ToolbarView::new();
    let header = adw::HeaderBar::new();
    toolbar.add_top_bar(&header);

    let root = gtk::Box::new(gtk::Orientation::Vertical, 14);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(20);
    root.set_margin_end(20);

    let title = gtk::Label::new(Some(&view.title));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    root.append(&title);

    let sub = gtk::Label::new(Some(&view.sub));
    sub.add_css_class("meshdrop-section");
    sub.set_halign(gtk::Align::Start);
    root.append(&sub);

    let card = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    card.add_css_class("meshdrop-card");
    card.append(&avatar::avatar(&view.initials, "#FFB4A1", 44, avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 1);
    let nm = gtk::Label::new(Some(&view.device_name));
    nm.add_css_class("meshdrop-card-title");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let m = gtk::Label::new(Some("等待确认 · pending"));
    m.add_css_class("meshdrop-meta");
    m.set_halign(gtk::Align::Start);
    col.append(&m);
    col.set_hexpand(true);
    card.append(&col);
    // 身份用 Ed25519 + SHA-256 指纹（非 X25519）；传输 v0.1 明文。不宣称 E2E。
    let chip_id = chip::chip("Ed25519 · TOFU", chip::Tone::Mute, true);
    chip_id.set_valign(gtk::Align::Center);
    card.append(&chip_id);
    root.append(&card);

    root.append(&ascii_divider::divider("── VERIFY · 验证 ──"));
    let qr_row = gtk::Box::new(gtk::Orientation::Horizontal, 16);
    qr_row.set_halign(gtk::Align::Center);

    let qr = fake_qr(160);
    qr_row.append(&qr);

    let code_col = gtk::Box::new(gtk::Orientation::Vertical, 6);
    code_col.set_valign(gtk::Align::Center);
    let lbl = gtk::Label::new(Some("六字符验证码 · 6-char code"));
    lbl.add_css_class("meshdrop-ascii-divider");
    lbl.set_halign(gtk::Align::Start);
    code_col.append(&lbl);
    let code = gtk::Label::new(None);
    code.add_css_class("meshdrop-display");
    code.add_css_class("meshdrop-mono");
    code.set_xalign(0.0);
    code.set_markup(&format!(
        "<span font_family=\"Geist Mono\" font_weight=\"700\" size=\"32000\" letter_spacing=\"600\">{}</span>",
        glib::markup_escape_text(&view.code)));
    code_col.append(&code);
    let hint = gtk::Label::new(Some(
        "请让对方在 TA 的 MeshDrop 中输入同样的 6 字符 ——\n或扫码 / 直接对比指纹。"));
    hint.add_css_class("meshdrop-muted");
    hint.set_xalign(0.0);
    hint.set_wrap(true);
    code_col.append(&hint);

    qr_row.append(&code_col);
    root.append(&qr_row);

    root.append(&ascii_divider::divider("── FINGERPRINT · 完整指纹 ──"));
    let fp_box = gtk::Box::new(gtk::Orientation::Vertical, 0);
    fp_box.add_css_class("meshdrop-card");
    let fp = gtk::Label::new(Some(&view.fingerprint_full));
    fp.add_css_class("meshdrop-mono");
    fp.set_wrap(true);
    fp.set_xalign(0.0);
    fp.set_max_width_chars(48);
    fp_box.append(&fp);
    root.append(&fp_box);

    let btn_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    btn_row.set_halign(gtk::Align::End);
    btn_row.set_margin_top(10);
    let reject = gtk::Button::with_label("拒绝 · Reject");
    reject.add_css_class("destructive-action");
    let once = gtk::Button::with_label("允许一次 · Allow once");
    let trust = gtk::Button::with_label("允许并记住 · Trust");
    trust.add_css_class("suggested-action");
    btn_row.append(&reject);
    btn_row.append(&once);
    btn_row.append(&trust);
    root.append(&btn_row);

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .child(&root)
        .build();
    toolbar.set_content(Some(&scroll));
    win.set_content(Some(&toolbar));

    let pid = view.pairing_id;
    let h_for_buttons = handle.cloned();

    let win_c = win.clone();
    let h_c = h_for_buttons.clone();
    reject.connect_clicked(move |_| {
        if let (Some(h), Some(id)) = (&h_c, pid) {
            h.respond_pairing(id, PairingDecision::Reject);
        }
        win_c.close();
    });
    let win_c = win.clone();
    let h_c = h_for_buttons.clone();
    once.connect_clicked(move |_| {
        if let (Some(h), Some(id)) = (&h_c, pid) {
            h.respond_pairing(id, PairingDecision::AllowOnce);
        }
        win_c.close();
    });
    let win_c = win.clone();
    let h_c = h_for_buttons.clone();
    trust.connect_clicked(move |_| {
        if let (Some(h), Some(id)) = (&h_c, pid) {
            h.respond_pairing(id, PairingDecision::Trust);
        }
        win_c.close();
    });

    win.present();
    win
}

fn build_view(handle: Option<&Rc<AppHandle>>) -> PairingView {
    match handle.and_then(|h| h.pending_pairings().into_iter().next()) {
        Some(p) => PairingView {
            title: "等待配对 · Pairing".into(),
            sub: format!("{} 想要连接", p.peer.name),
            device_name: p.peer.name.clone(),
            initials: crate::view::initials_of(&p.peer.name),
            code: short_code(&p.peer.fingerprint),
            fingerprint_full: p.peer.human_fingerprint(),
            pairing_id: Some(p.id),
        },
        None => {
            let m = mock::pending_pairing();
            PairingView {
                title: "等待配对 · Pairing".into(),
                sub: format!("{} 想要连接", m.peer),
                device_name: m.device_name.to_string(),
                initials: "李".into(),
                code: "ZX-8K-L7".into(),
                fingerprint_full: m.fingerprint.to_string(),
                pairing_id: None,
            }
        }
    }
}

/// 取指纹前 6 位拼成 AB-CD-EF。仅用于显示，对端会用同样规则推同样码。
fn short_code(fp: &str) -> String {
    let cleaned: String = fp.chars().filter(|c| c.is_ascii_alphanumeric())
        .take(6).flat_map(char::to_uppercase).collect();
    if cleaned.len() >= 6 {
        format!("{}-{}-{}", &cleaned[0..2], &cleaned[2..4], &cleaned[4..6])
    } else {
        cleaned
    }
}

fn fake_qr(size: i32) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(size).content_height(size).build();
    area.set_draw_func(move |_, cr, w, h| {
        let (w, h) = (w as f64, h as f64);
        cr.set_source_rgb(1.0, 1.0, 1.0);
        cr.rectangle(0.0, 0.0, w, h);
        cr.fill().ok();
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.25);
        cr.set_line_width(1.0);
        cr.rectangle(0.5, 0.5, w - 1.0, h - 1.0);
        cr.stroke().ok();
        let n = 25;
        let pad = 10.0;
        let cell = (w - pad * 2.0) / n as f64;
        let mut seed: u32 = 0x9E37_79B9;
        cr.set_source_rgb(0.04, 0.04, 0.04);
        for y in 0..n {
            for x in 0..n {
                seed = seed.wrapping_mul(1103515245).wrapping_add(12345);
                let on = (seed >> 24) & 1 == 1;
                let in_finder = |fx: i32, fy: i32| {
                    let dx = x - fx; let dy = y - fy;
                    dx >= 0 && dx < 7 && dy >= 0 && dy < 7
                };
                let f = in_finder(0, 0) || in_finder(n - 7, 0) || in_finder(0, n - 7);
                let draw = if f {
                    let (fx, fy) = if in_finder(0, 0) { (0, 0) }
                        else if in_finder(n - 7, 0) { (n - 7, 0) }
                        else { (0, n - 7) };
                    let dx = x - fx; let dy = y - fy;
                    let outer = dx == 0 || dx == 6 || dy == 0 || dy == 6;
                    let inner = dx >= 2 && dx <= 4 && dy >= 2 && dy <= 4;
                    outer || inner
                } else { on };
                if draw {
                    cr.rectangle(pad + x as f64 * cell, pad + y as f64 * cell, cell, cell);
                    cr.fill().ok();
                }
            }
        }
    });
    area
}
