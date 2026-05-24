//! Settings 页：可见性 / 安全 / 行为 三组。

use crate::components::{ascii_divider, chip};
use crate::mock;
use adw::prelude::*;

pub fn build() -> gtk::Widget {
    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .hexpand(true)
        .build();
    let root = gtk::Box::new(gtk::Orientation::Vertical, 14);
    root.set_margin_top(18);
    root.set_margin_bottom(18);
    root.set_margin_start(20);
    root.set_margin_end(20);

    let title = gtk::Label::new(Some("设置 · Settings"));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    root.append(&title);

    // 本机摘要卡
    let me = mock::me();
    let card = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    card.add_css_class("meshdrop-card");
    card.append(&crate::components::avatar::avatar("我", "#DDF94B", 44,
                                                   crate::components::avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let nm = gtk::Label::new(Some(me.name));
    nm.add_css_class("meshdrop-card-title");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let fp_label = gtk::Label::new(Some(me.fingerprint_full));
    fp_label.add_css_class("meshdrop-mono");
    fp_label.add_css_class("meshdrop-muted");
    fp_label.set_halign(gtk::Align::Start);
    fp_label.set_wrap(true);
    fp_label.set_max_width_chars(48);
    col.append(&fp_label);
    let ip = gtk::Label::new(Some(&format!("{} · {}", me.os, me.ip)));
    ip.add_css_class("meshdrop-meta");
    ip.set_halign(gtk::Align::Start);
    col.append(&ip);
    card.append(&col);

    let about = chip::chip("Space Grotesk · Geist · Geist Mono", chip::Tone::Outline, true);
    about.set_valign(gtk::Align::Center);
    card.append(&about);
    root.append(&card);

    // ── 可见性
    root.append(&ascii_divider::divider("── VISIBILITY · 可见性 ──"));
    let g1 = adw::PreferencesGroup::new();
    g1.set_title("");
    let v1 = adw::ActionRow::builder()
        .title("对所有局域网设备可见 · Visible to LAN")
        .subtitle("广播 _meshdrop._tcp service，附近所有 MeshDrop 设备可看到")
        .build();
    let sw1 = gtk::Switch::new();
    sw1.set_active(true);
    sw1.set_valign(gtk::Align::Center);
    v1.add_suffix(&sw1);
    v1.set_activatable_widget(Some(&sw1));
    g1.add(&v1);

    let v2 = adw::ActionRow::builder()
        .title("仅对已配对设备可见 · Trusted only")
        .subtitle("陌生设备搜不到本机")
        .build();
    let sw2 = gtk::Switch::new();
    sw2.set_active(false);
    sw2.set_valign(gtk::Align::Center);
    v2.add_suffix(&sw2);
    g1.add(&v2);
    root.append(&g1);

    // ── 安全 / 加密
    root.append(&ascii_divider::divider("── SECURITY · 安全 · E2E ──"));
    let g2 = adw::PreferencesGroup::new();
    let e1 = adw::ActionRow::builder()
        .title("端到端加密 · X25519 + ChaCha20-Poly1305")
        .subtitle("所有传输强制走 E2E；指纹由会话密钥推导")
        .build();
    e1.add_suffix(&chip::chip("ENFORCED", chip::Tone::Ink, true));
    g2.add(&e1);

    let e2 = adw::ActionRow::builder()
        .title("私钥储存 · Linux Secret Service")
        .subtitle("通过 libsecret 同步到 GNOME Keyring / KWallet")
        .build();
    let sw3 = gtk::Switch::new();
    sw3.set_active(true);
    sw3.set_valign(gtk::Align::Center);
    e2.add_suffix(&sw3);
    g2.add(&e2);

    let e3 = adw::ActionRow::builder()
        .title("TOFU 信任策略")
        .subtitle("首次连接弹出配对确认，确认后写入信任库")
        .build();
    e3.add_suffix(&chip::chip("TOFU", chip::Tone::Outline, true));
    g2.add(&e3);
    root.append(&g2);

    // ── 行为
    root.append(&ascii_divider::divider("── BEHAVIOR · 行为 ──"));
    let g3 = adw::PreferencesGroup::new();
    let b1 = adw::ActionRow::builder()
        .title("自动接收文字便签 · Auto-accept notes")
        .subtitle("已信任设备发来的纯文本无需确认")
        .build();
    let sw4 = gtk::Switch::new();
    sw4.set_active(false);
    sw4.set_valign(gtk::Align::Center);
    b1.add_suffix(&sw4);
    g3.add(&b1);

    let b2 = adw::ActionRow::builder()
        .title("已信任设备自动接收文件 · Auto-accept files (trusted)")
        .subtitle("自动落到 ~/Downloads/MeshDrop/<对方名>/")
        .build();
    let sw5 = gtk::Switch::new();
    sw5.set_active(true);
    sw5.set_valign(gtk::Align::Center);
    b2.add_suffix(&sw5);
    g3.add(&b2);

    let b3 = adw::ActionRow::builder()
        .title("下载目录 · Download folder")
        .subtitle("~/Downloads/MeshDrop")
        .build();
    let choose = gtk::Button::with_label("选择…");
    choose.set_valign(gtk::Align::Center);
    b3.add_suffix(&choose);
    g3.add(&b3);
    root.append(&g3);

    // ── 外观
    root.append(&ascii_divider::divider("── APPEARANCE · 外观 ──"));
    let g4 = adw::PreferencesGroup::new();
    let t1 = adw::ActionRow::builder()
        .title("配色 · Color scheme")
        .subtitle("跟随系统 / 强制浅色 / 强制深色")
        .build();
    let drop = gtk::DropDown::from_strings(&["跟随系统 · Auto", "浅色 · Light", "深色 · Dark"]);
    drop.set_valign(gtk::Align::Center);
    t1.add_suffix(&drop);
    g4.add(&t1);
    root.append(&g4);

    scroll.set_child(Some(&root));
    scroll.upcast()
}
