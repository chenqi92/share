//! Settings 页：可见性 / 安全 / 行为 / Web Gateway / 外观。

use crate::components::{ascii_divider, chip};
use crate::engine_bridge::AppHandle;
use crate::mock;
use adw::prelude::*;
use std::rc::Rc;

pub fn build(handle: Option<&Rc<AppHandle>>) -> gtk::Widget {
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
    let card = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    card.add_css_class("meshdrop-card");
    card.append(&crate::components::avatar::avatar("我", "#DDF94B", 44,
                                                   crate::components::avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let (name, fp_full, ip_line) = match handle {
        Some(h) => (
            h.engine.display_name.clone(),
            h.fingerprint(),
            format!("Linux · {} · 端口 {}",
                h.self_ip.borrow().clone().unwrap_or_else(|| "—".into()),
                h.engine.listen_port),
        ),
        None => {
            let m = mock::me();
            (m.name.to_string(), m.fingerprint_full.to_string(),
             format!("{} · {}", m.os, m.ip))
        }
    };
    let nm = gtk::Label::new(Some(&name));
    nm.add_css_class("meshdrop-card-title");
    nm.set_halign(gtk::Align::Start);
    col.append(&nm);
    let fp_label = gtk::Label::new(Some(&fp_full));
    fp_label.add_css_class("meshdrop-mono");
    fp_label.add_css_class("meshdrop-muted");
    fp_label.set_halign(gtk::Align::Start);
    fp_label.set_wrap(true);
    fp_label.set_max_width_chars(48);
    col.append(&fp_label);
    let ip = gtk::Label::new(Some(&ip_line));
    ip.add_css_class("meshdrop-meta");
    ip.set_halign(gtk::Align::Start);
    col.append(&ip);
    card.append(&col);
    let about = chip::chip("Space Grotesk · Geist · Geist Mono", chip::Tone::Outline, true);
    about.set_valign(gtk::Align::Center);
    card.append(&about);
    root.append(&card);

    // ── Web Gateway
    root.append(&ascii_divider::divider("── WEB GATEWAY · 浏览器接入 ──"));
    let gw_group = adw::PreferencesGroup::new();

    let (gw_status_text, gw_status_sub) = match handle {
        Some(h) => match h.gateway_port() {
            Some(p) => (
                format!("已启动 · 监听 :{}", p),
                "https://meshdrop.local:7384  ·  自签证书：~/.config/meshdrop/cert.pem".to_string(),
            ),
            None => (
                "未启动".to_string(),
                "端口被占或缺权限 —— 详见终端日志".to_string(),
            ),
        },
        None => ("未启动 · 仅 mock".into(), "运行真 engine 后会自动监听 :7384".into()),
    };

    let gw_row = adw::ActionRow::builder()
        .title(&gw_status_text)
        .subtitle(&gw_status_sub)
        .build();
    let online = match handle.and_then(|h| h.gateway_port()) {
        Some(_) => chip::chip("LIVE", chip::Tone::Lime, true),
        None => chip::chip("OFF", chip::Tone::Outline, true),
    };
    gw_row.add_suffix(&online);
    gw_group.add(&gw_row);

    let code_str = handle.and_then(|h| h.pairing_code()).unwrap_or_else(|| "—".into());
    let code_row = adw::ActionRow::builder()
        .title("浏览器邀请码 · Pairing code")
        .subtitle("浏览器首次访问时输入。仅本机会话有效。")
        .build();
    let code_label = gtk::Label::new(Some(&code_str));
    code_label.add_css_class("meshdrop-mono");
    code_label.set_markup(&format!(
        "<span font_family=\"Geist Mono\" font_weight=\"700\" size=\"18000\" letter_spacing=\"600\">{}</span>",
        glib::markup_escape_text(&code_str)));
    code_label.set_valign(gtk::Align::Center);
    code_row.add_suffix(&code_label);
    gw_group.add(&code_row);

    let cert_row = adw::ActionRow::builder()
        .title("自签证书路径 · Cert path")
        .subtitle("CN=meshdrop.local。首次浏览器访问需要手动信任。")
        .build();
    let cert_chip = chip::chip("~/.config/meshdrop/", chip::Tone::Outline, true);
    cert_chip.set_valign(gtk::Align::Center);
    cert_row.add_suffix(&cert_chip);
    gw_group.add(&cert_row);

    root.append(&gw_group);

    // ── 可见性
    root.append(&ascii_divider::divider("── VISIBILITY · 可见性 ──"));
    let g1 = adw::PreferencesGroup::new();
    let v1 = adw::ActionRow::builder()
        .title("对所有局域网设备可见 · Visible to LAN")
        .subtitle("广播 _meshdrop._tcp service")
        .build();
    let sw1 = gtk::Switch::new();
    sw1.set_active(true);
    sw1.set_valign(gtk::Align::Center);
    v1.add_suffix(&sw1);
    v1.set_activatable_widget(Some(&sw1));
    g1.add(&v1);
    root.append(&g1);

    // ── 安全
    root.append(&ascii_divider::divider("── SECURITY · 安全 · E2E ──"));
    let g2 = adw::PreferencesGroup::new();
    let e1 = adw::ActionRow::builder()
        .title("端到端加密 · X25519 + ChaCha20-Poly1305")
        .subtitle("所有传输强制走 E2E；指纹由会话密钥推导")
        .build();
    e1.add_suffix(&chip::chip("ENFORCED", chip::Tone::Ink, true));
    g2.add(&e1);

    let e2 = adw::ActionRow::builder()
        .title("私钥储存 · ~/.local/share/meshdrop/ed25519.bin")
        .subtitle("骨架阶段裸文件；v1.0 切到 libsecret")
        .build();
    e2.add_suffix(&chip::chip("PLAIN", chip::Tone::Outline, true));
    g2.add(&e2);

    let e3 = adw::ActionRow::builder()
        .title("TOFU 信任策略")
        .subtitle("首次连接弹出配对确认，确认后写入 ~/.local/share/meshdrop/trust.json")
        .build();
    e3.add_suffix(&chip::chip("TOFU", chip::Tone::Outline, true));
    g2.add(&e3);

    // 已信任设备自动接收（真实设置，持久化到配置文件）
    let aa_row = adw::ActionRow::builder()
        .title("已信任设备自动接收 · Auto-accept from trusted")
        .subtitle("来自已配对设备的文件 offer 自动接受，无需手动确认")
        .build();
    let aa_sw = gtk::Switch::new();
    aa_sw.set_valign(gtk::Align::Center);
    if let Some(h) = handle {
        aa_sw.set_active(h.engine.auto_accept_from_trusted());
        let h_c = h.clone();
        aa_sw.connect_active_notify(move |s| h_c.engine.set_auto_accept(s.is_active()));
    }
    aa_row.add_suffix(&aa_sw);
    aa_row.set_activatable_widget(Some(&aa_sw));
    g2.add(&aa_row);

    // 重置身份（security.md §设备身份）
    let e4 = adw::ActionRow::builder()
        .title("重置身份 · Reset identity")
        .subtitle("删除当前 ID 与 Ed25519 密钥；对端会把本机视为新设备需重新配对")
        .build();
    let reset_btn = gtk::Button::with_label("重置…");
    reset_btn.add_css_class("destructive-action");
    reset_btn.set_valign(gtk::Align::Center);
    let window = root.root().and_then(|r| r.downcast::<gtk::Window>().ok());
    reset_btn.connect_clicked(move |_| {
        let dialog = adw::MessageDialog::new(
            window.as_ref(),
            Some("重置身份"),
            Some("将删除当前 ID 与 Ed25519 私钥，所有已配对的对端会把本机视为新设备需要重新配对。重置后需要重启 app 让新身份生效。"),
        );
        dialog.add_response("cancel", "取消");
        dialog.add_response("reset", "重置");
        dialog.set_response_appearance("reset", adw::ResponseAppearance::Destructive);
        dialog.set_default_response(Some("cancel"));
        dialog.set_close_response("cancel");
        dialog.connect_response(None, |dlg, resp| {
            if resp == "reset" {
                match meshdrop_core::Identity::reset_storage() {
                    Ok(()) => {
                        let done = adw::MessageDialog::new(
                            None::<&gtk::Window>,
                            Some("已重置"),
                            Some("身份已删除，请重启 MeshDrop 让新身份生效。"),
                        );
                        done.add_response("ok", "好");
                        done.set_default_response(Some("ok"));
                        done.present();
                    }
                    Err(e) => {
                        let err = adw::MessageDialog::new(
                            None::<&gtk::Window>,
                            Some("重置失败"),
                            Some(&format!("{}", e)),
                        );
                        err.add_response("ok", "好");
                        err.present();
                    }
                }
            }
            dlg.close();
        });
        dialog.present();
    });
    e4.add_suffix(&reset_btn);
    g2.add(&e4);
    root.append(&g2);

    // ── 行为
    root.append(&ascii_divider::divider("── BEHAVIOR · 行为 ──"));
    let g3 = adw::PreferencesGroup::new();
    let b3 = adw::ActionRow::builder()
        .title("下载目录 · Download folder")
        .subtitle("~/Downloads/MeshDrop/<对方名>/")
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
