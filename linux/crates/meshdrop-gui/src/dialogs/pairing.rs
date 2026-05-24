//! Pairing 弹窗：QR + 6 字符代码 + 三步说明 + 指纹分组（4-4 · ...）。

use crate::components::{ascii_divider, avatar, chip};
use crate::mock;
use adw::prelude::*;

pub fn present(parent: &impl IsA<gtk::Window>) -> adw::Window {
    let p = mock::pending_pairing();

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

    let title = gtk::Label::new(Some("等待配对 · Pairing"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    root.append(&title);

    let sub = gtk::Label::new(Some(&format!("{} 想要连接", p.peer)));
    sub.add_css_class("meshdrop-section");
    sub.set_halign(gtk::Align::Start);
    root.append(&sub);

    // peer 卡片
    let card = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    card.add_css_class("meshdrop-card");
    card.append(&avatar::avatar("李", "#FFB4A1", 44, avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 1);
    let nm = gtk::Label::new(Some(p.device_name));
    nm.add_css_class("meshdrop-card-title");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let m = gtk::Label::new(Some(&format!("收到于 · {}", p.received_at)));
    m.add_css_class("meshdrop-meta");
    m.set_halign(gtk::Align::Start);
    col.append(&m);
    col.set_hexpand(true);
    card.append(&col);
    let chip_e2e = chip::chip("E2E · X25519", chip::Tone::Mute, true);
    chip_e2e.set_valign(gtk::Align::Center);
    card.append(&chip_e2e);
    root.append(&card);

    // QR + 6 字符代码
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
    let code = gtk::Label::new(Some("ZX-8K-L7"));
    code.add_css_class("meshdrop-display");
    code.add_css_class("meshdrop-mono");
    code.set_xalign(0.0);
    code.set_markup("<span font_family=\"Geist Mono\" font_weight=\"700\" size=\"32000\" letter_spacing=\"600\">ZX-8K-L7</span>");
    code_col.append(&code);
    let hint = gtk::Label::new(Some(
        "请让对方在 TA 的 MeshDrop 中输入同样的 6 字符 ——\n或扫码 / 直接对比指纹。"));
    hint.add_css_class("meshdrop-muted");
    hint.set_xalign(0.0);
    hint.set_wrap(true);
    code_col.append(&hint);

    qr_row.append(&code_col);
    root.append(&qr_row);

    // 指纹
    root.append(&ascii_divider::divider("── FINGERPRINT · 完整指纹（4-4 分组） ──"));
    let fp_box = gtk::Box::new(gtk::Orientation::Vertical, 0);
    fp_box.add_css_class("meshdrop-card");
    let fp = gtk::Label::new(Some(p.fingerprint));
    fp.add_css_class("meshdrop-mono");
    fp.set_wrap(true);
    fp.set_xalign(0.0);
    fp.set_max_width_chars(48);
    fp_box.append(&fp);
    root.append(&fp_box);

    // 三步说明
    root.append(&ascii_divider::divider("── 3 STEPS · 三步对齐 ──"));
    for (i, t) in [
        "1. 在对方设备的 MeshDrop 屏上找到本机的 6 字符代码",
        "2. 确保两侧显示的指纹一致（或对方扫此 QR）",
        "3. 点击下方「允许并记住」写入信任库 · TOFU",
    ].iter().enumerate() {
        let row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
        let n = gtk::Label::new(Some(&format!("{:02}", i + 1)));
        n.add_css_class("meshdrop-mono");
        n.add_css_class("meshdrop-muted");
        row.append(&n);
        let lb = gtk::Label::new(Some(t));
        lb.set_halign(gtk::Align::Start);
        row.append(&lb);
        root.append(&row);
    }

    // 按钮
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

    let win_c = win.clone();
    reject.connect_clicked(move |_| win_c.close());
    let win_c = win.clone();
    once.connect_clicked(move |_| win_c.close());
    let win_c = win.clone();
    trust.connect_clicked(move |_| win_c.close());

    win.present();
    win
}

fn fake_qr(size: i32) -> gtk::DrawingArea {
    let area = gtk::DrawingArea::builder().content_width(size).content_height(size).build();
    area.set_draw_func(move |_, cr, w, h| {
        let (w, h) = (w as f64, h as f64);
        // 边框白底
        cr.set_source_rgb(1.0, 1.0, 1.0);
        cr.rectangle(0.0, 0.0, w, h);
        cr.fill().ok();
        cr.set_source_rgba(0.04, 0.04, 0.04, 0.25);
        cr.set_line_width(1.0);
        cr.rectangle(0.5, 0.5, w - 1.0, h - 1.0);
        cr.stroke().ok();

        // 假 21x21 QR
        let n = 25;
        let pad = 10.0;
        let cell = (w - pad * 2.0) / n as f64;
        // 用伪随机种子绘制黑白
        let mut seed: u32 = 0x9E37_79B9;
        cr.set_source_rgb(0.04, 0.04, 0.04);
        for y in 0..n {
            for x in 0..n {
                seed = seed.wrapping_mul(1103515245).wrapping_add(12345);
                let on = (seed >> 24) & 1 == 1;
                // 强制三个 finder pattern
                let in_finder = |fx: i32, fy: i32| {
                    let dx = x - fx; let dy = y - fy;
                    dx >= 0 && dx < 7 && dy >= 0 && dy < 7
                };
                let f = in_finder(0, 0) || in_finder(n - 7, 0) || in_finder(0, n - 7);
                let draw = if f {
                    // 7x7 finder：外圈 + 中心 3x3
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

        // 中心 MeshDrop 标
        let cx = w / 2.0;
        let cy = h / 2.0;
        let r = 14.0;
        cr.set_source_rgb(1.0, 1.0, 1.0);
        cr.rectangle(cx - r, cy - r, r * 2.0, r * 2.0);
        cr.fill().ok();
        cr.set_source_rgb(0.04, 0.04, 0.04);
        cr.set_line_width(1.2);
        cr.arc(cx - 3.0, cy, 5.0, 0.0, std::f64::consts::TAU);
        cr.stroke().ok();
        cr.arc(cx + 3.0, cy, 5.0, 0.0, std::f64::consts::TAU);
        cr.stroke().ok();
        cr.set_source_rgb(221.0/255.0, 249.0/255.0, 75.0/255.0);
        cr.arc(cx, cy, 1.6, 0.0, std::f64::consts::TAU);
        cr.fill().ok();

    });
    area
}
