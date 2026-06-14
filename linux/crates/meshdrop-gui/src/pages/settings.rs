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

    let title = gtk::Label::new(Some(&*t!("settings.title")));
    title.add_css_class("meshdrop-hero");
    title.set_halign(gtk::Align::Start);
    root.append(&title);

    // 本机摘要卡
    let card = gtk::Box::new(gtk::Orientation::Horizontal, 12);
    card.add_css_class("meshdrop-card");
    card.append(&crate::components::avatar::avatar(&t!("common.me"), "#DDF94B", 44,
                                                   crate::components::avatar::Ring::Lime));
    let col = gtk::Box::new(gtk::Orientation::Vertical, 2);
    col.set_hexpand(true);
    let (name, fp_full, ip_line) = match handle {
        Some(h) => (
            h.engine.display_name.clone(),
            h.fingerprint(),
            t!("settings.device_line",
                ip = h.self_ip.borrow().clone().unwrap_or_else(|| "—".into()),
                port = h.engine.listen_port).to_string(),
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
    root.append(&ascii_divider::divider(&t!("settings.gateway_divider")));
    let gw_group = adw::PreferencesGroup::new();

    let (gw_status_text, gw_status_sub) = match handle {
        Some(h) => match h.gateway_port() {
            Some(p) => (
                t!("settings.gateway_running", port = p).to_string(),
                t!("settings.gateway_running_sub").to_string(),
            ),
            None => (
                t!("settings.gateway_stopped").to_string(),
                t!("settings.gateway_stopped_sub").to_string(),
            ),
        },
        None => (t!("settings.gateway_mock").to_string(), t!("settings.gateway_mock_sub").to_string()),
    };

    let gw_row = adw::ActionRow::builder()
        .title(&gw_status_text)
        .subtitle(&gw_status_sub)
        .build();
    let online = match handle.and_then(|h| h.gateway_port()) {
        Some(_) => chip::chip(&t!("settings.gateway_live"), chip::Tone::Lime, true),
        None => chip::chip(&t!("settings.gateway_off"), chip::Tone::Outline, true),
    };
    gw_row.add_suffix(&online);
    gw_group.add(&gw_row);

    let code_str = handle.and_then(|h| h.pairing_code()).unwrap_or_else(|| "—".into());
    let code_row = adw::ActionRow::builder()
        .title(t!("settings.code_title").as_ref())
        .subtitle(t!("settings.code_sub").as_ref())
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
        .title(t!("settings.cert_title").as_ref())
        .subtitle(t!("settings.cert_sub").as_ref())
        .build();
    let cert_chip = chip::chip("~/.config/meshdrop/", chip::Tone::Outline, true);
    cert_chip.set_valign(gtk::Align::Center);
    cert_row.add_suffix(&cert_chip);
    gw_group.add(&cert_row);

    root.append(&gw_group);

    // ── 可见性
    root.append(&ascii_divider::divider(&t!("settings.visibility_divider")));
    let g1 = adw::PreferencesGroup::new();
    let v1 = adw::ActionRow::builder()
        .title(t!("settings.visible_lan_title").as_ref())
        .subtitle(t!("settings.visible_lan_sub").as_ref())
        .build();
    let sw1 = gtk::Switch::new();
    sw1.set_valign(gtk::Align::Center);
    // 接 engine：开=广告 mDNS，关=停止广告（已建连不强断）。状态由 core 持久化。
    if let Some(h) = handle {
        sw1.set_active(h.visible_on_lan());
        let h_c = h.clone();
        sw1.connect_active_notify(move |s| h_c.set_visible_on_lan(s.is_active()));
    } else {
        sw1.set_active(true);
    }
    v1.add_suffix(&sw1);
    v1.set_activatable_widget(Some(&sw1));
    g1.add(&v1);
    root.append(&g1);

    // ── 安全
    root.append(&ascii_divider::divider(&t!("settings.security_divider")));
    let g2 = adw::PreferencesGroup::new();
    // v0.1 LAN 传输为明文 TCP，尚未上 TLS / 应用层 E2E；文案如实标注，chip 用 PLANNED。
    let e1 = adw::ActionRow::builder()
        .title(t!("settings.tls_title").as_ref())
        .subtitle(t!("settings.tls_sub").as_ref())
        .build();
    e1.add_suffix(&chip::chip(&t!("settings.tls_chip"), chip::Tone::Outline, true));
    g2.add(&e1);

    // 身份 / 指纹用 Ed25519 + SHA-256（非 X25519/ChaCha20），这是已实现的能力。
    let e_id = adw::ActionRow::builder()
        .title(t!("settings.identity_title").as_ref())
        .subtitle(t!("settings.identity_sub").as_ref())
        .build();
    e_id.add_suffix(&chip::chip(&t!("settings.identity_chip"), chip::Tone::Lime, true));
    g2.add(&e_id);

    let e2 = adw::ActionRow::builder()
        .title(t!("settings.key_title").as_ref())
        .subtitle(t!("settings.key_sub").as_ref())
        .build();
    e2.add_suffix(&chip::chip(&t!("settings.key_chip"), chip::Tone::Outline, true));
    g2.add(&e2);

    // 陌生设备首次配对要求确认（TOFU）：真开关但锁定常开——关闭语义即自动信任
    // 陌生设备，危险。开关 active+sensitive(false) 表达"已生效且不可关"。
    let e3 = adw::ActionRow::builder()
        .title(t!("settings.tofu_title").as_ref())
        .subtitle(t!("settings.tofu_sub").as_ref())
        .build();
    let tofu_sw = gtk::Switch::new();
    tofu_sw.set_active(true);
    tofu_sw.set_sensitive(false);
    tofu_sw.set_valign(gtk::Align::Center);
    e3.add_suffix(&tofu_sw);
    g2.add(&e3);

    // 仅显示已配对设备 / trusted-only（默认关，持久化）
    let to_row = adw::ActionRow::builder()
        .title(t!("settings.trusted_only_title").as_ref())
        .subtitle(t!("settings.trusted_only_sub").as_ref())
        .build();
    let to_sw = gtk::Switch::new();
    to_sw.set_valign(gtk::Align::Center);
    if let Some(h) = handle {
        to_sw.set_active(h.trusted_only());
        let h_c = h.clone();
        to_sw.connect_active_notify(move |s| h_c.set_trusted_only(s.is_active()));
    }
    to_row.add_suffix(&to_sw);
    to_row.set_activatable_widget(Some(&to_sw));
    g2.add(&to_row);

    // 接收前必须验证对方指纹（默认开 · 更安全，持久化）
    let vb_row = adw::ActionRow::builder()
        .title(t!("settings.verify_title").as_ref())
        .subtitle(t!("settings.verify_sub").as_ref())
        .build();
    let vb_sw = gtk::Switch::new();
    vb_sw.set_valign(gtk::Align::Center);
    if let Some(h) = handle {
        vb_sw.set_active(h.verify_before_receive());
        let h_c = h.clone();
        vb_sw.connect_active_notify(move |s| h_c.set_verify_before_receive(s.is_active()));
    } else {
        vb_sw.set_active(true);
    }
    vb_row.add_suffix(&vb_sw);
    vb_row.set_activatable_widget(Some(&vb_sw));
    g2.add(&vb_row);

    // 已信任设备自动接收（真实设置，持久化到配置文件）
    let aa_row = adw::ActionRow::builder()
        .title(t!("settings.auto_accept_title").as_ref())
        .subtitle(t!("settings.auto_accept_sub").as_ref())
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

    // 陌生设备自动接受（危险 · 默认关，持久化）
    let as_row = adw::ActionRow::builder()
        .title(t!("settings.auto_accept_stranger_title").as_ref())
        .subtitle(t!("settings.auto_accept_stranger_sub").as_ref())
        .build();
    let as_sw = gtk::Switch::new();
    as_sw.set_valign(gtk::Align::Center);
    if let Some(h) = handle {
        as_sw.set_active(h.auto_accept_stranger());
        let h_c = h.clone();
        as_sw.connect_active_notify(move |s| h_c.set_auto_accept_stranger(s.is_active()));
    }
    as_row.add_suffix(&as_sw);
    as_row.set_activatable_widget(Some(&as_sw));
    g2.add(&as_row);

    // 重置身份（security.md §设备身份）
    let e4 = adw::ActionRow::builder()
        .title(t!("settings.reset_title").as_ref())
        .subtitle(t!("settings.reset_sub").as_ref())
        .build();
    let reset_btn = gtk::Button::with_label(&t!("common.reset"));
    reset_btn.add_css_class("destructive-action");
    reset_btn.set_valign(gtk::Align::Center);
    let window = root.root().and_then(|r| r.downcast::<gtk::Window>().ok());
    reset_btn.connect_clicked(move |_| {
        let dialog = adw::MessageDialog::new(
            window.as_ref(),
            Some(&*t!("settings.reset_dialog_title")),
            Some(&*t!("settings.reset_dialog_body")),
        );
        dialog.add_response("cancel", &t!("common.cancel"));
        dialog.add_response("reset", &t!("settings.reset_confirm"));
        dialog.set_response_appearance("reset", adw::ResponseAppearance::Destructive);
        dialog.set_default_response(Some("cancel"));
        dialog.set_close_response("cancel");
        dialog.connect_response(None, |dlg, resp| {
            if resp == "reset" {
                match meshdrop_core::Identity::reset_storage() {
                    Ok(()) => {
                        let done = adw::MessageDialog::new(
                            None::<&gtk::Window>,
                            Some(&*t!("settings.reset_done_title")),
                            Some(&*t!("settings.reset_done_body")),
                        );
                        done.add_response("ok", &t!("common.ok"));
                        done.set_default_response(Some("ok"));
                        done.present();
                    }
                    Err(e) => {
                        let err = adw::MessageDialog::new(
                            None::<&gtk::Window>,
                            Some(&*t!("settings.reset_fail_title")),
                            Some(&format!("{}", e)),
                        );
                        err.add_response("ok", &t!("common.ok"));
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
    root.append(&ascii_divider::divider(&t!("settings.behavior_divider")));
    let g3 = adw::PreferencesGroup::new();

    // 下载目录：接 engine.set_save_dir。副标题随当前覆盖目录更新；choose 弹原生
    // 文件夹选择器，选中后下发 core 并持久化。
    let dl_sub = match handle.and_then(|h| h.save_dir()) {
        Some(dir) => t!("settings.download_custom_sub", dir = dir.display().to_string()).to_string(),
        None => t!("settings.download_sub").to_string(),
    };
    let b3 = adw::ActionRow::builder()
        .title(t!("settings.download_title").as_ref())
        .subtitle(&dl_sub)
        .build();
    let choose = gtk::Button::with_label(&t!("common.choose"));
    choose.set_valign(gtk::Align::Center);
    if let Some(h) = handle {
        let h_c = h.clone();
        let row_c = b3.clone();
        choose.connect_clicked(move |btn| {
            let window = btn.root().and_then(|r| r.downcast::<gtk::Window>().ok());
            // GTK 4.10+ 推荐的 FileDialog（异步回调），替代已弃用的 FileChooserDialog。
            let dialog = gtk::FileDialog::builder()
                .title(&*t!("settings.download_choose_title"))
                .modal(true)
                .build();
            let h_inner = h_c.clone();
            let row_inner = row_c.clone();
            dialog.select_folder(
                window.as_ref(),
                gtk::gio::Cancellable::NONE,
                move |res| {
                    if let Ok(folder) = res {
                        if let Some(path) = folder.path() {
                            h_inner.set_save_dir(Some(path.clone()));
                            row_inner.set_subtitle(&t!(
                                "settings.download_custom_sub",
                                dir = path.display().to_string()
                            ));
                        }
                    }
                },
            );
        });
    } else {
        choose.set_sensitive(false);
        choose.set_tooltip_text(Some(t!("settings.download_disabled_tip").as_ref()));
    }
    b3.add_suffix(&choose);
    // 恢复默认按钮：清掉覆盖，回到 ~/Downloads/MeshDrop/<peer>。
    if let Some(h) = handle {
        let reset = gtk::Button::with_label(&t!("settings.download_reset"));
        reset.set_valign(gtk::Align::Center);
        let h_c = h.clone();
        let row_c = b3.clone();
        reset.connect_clicked(move |_| {
            h_c.set_save_dir(None);
            row_c.set_subtitle(&t!("settings.download_sub"));
        });
        b3.add_suffix(&reset);
    }
    g3.add(&b3);

    // 跨设备剪贴板同步（默认关，持久化）
    let clip_row = adw::ActionRow::builder()
        .title(t!("settings.clipboard_sync_title").as_ref())
        .subtitle(t!("settings.clipboard_sync_sub").as_ref())
        .build();
    let clip_sw = gtk::Switch::new();
    clip_sw.set_valign(gtk::Align::Center);
    if let Some(h) = handle {
        clip_sw.set_active(h.clipboard_sync());
        let h_c = h.clone();
        clip_sw.connect_active_notify(move |s| h_c.set_clipboard_sync(s.is_active()));
    }
    clip_row.add_suffix(&clip_sw);
    clip_row.set_activatable_widget(Some(&clip_sw));
    g3.add(&clip_row);

    // 登录时启动（写 ~/.config/autostart/meshdrop.desktop，状态即文件存在性）
    let login_row = adw::ActionRow::builder()
        .title(t!("settings.launch_login_title").as_ref())
        .subtitle(t!("settings.launch_login_sub").as_ref())
        .build();
    let login_sw = gtk::Switch::new();
    login_sw.set_valign(gtk::Align::Center);
    login_sw.set_active(meshdrop_core::autostart::is_enabled());
    login_sw.connect_active_notify(|s| {
        if let Err(e) = meshdrop_core::autostart::set_enabled(s.is_active()) {
            log::warn!("autostart 设置失败: {}", e);
        }
    });
    login_row.add_suffix(&login_sw);
    login_row.set_activatable_widget(Some(&login_sw));
    g3.add(&login_row);

    root.append(&g3);

    // ── 外观
    root.append(&ascii_divider::divider(&t!("settings.appearance_divider")));
    let g4 = adw::PreferencesGroup::new();
    let t1 = adw::ActionRow::builder()
        .title(t!("settings.color_title").as_ref())
        .subtitle(t!("settings.color_sub").as_ref())
        .build();
    let drop = gtk::DropDown::from_strings(&[
        t!("settings.color_auto").as_ref(),
        t!("settings.color_light").as_ref(),
        t!("settings.color_dark").as_ref(),
    ]);
    drop.set_valign(gtk::Align::Center);
    // 接 theme::set_scheme：从 widget 所属窗口拿到 adw::Application 再切换配色。
    let drop_root = root.clone();
    drop.connect_selected_notify(move |d| {
        let mode = match d.selected() {
            1 => crate::theme::ColorMode::Light,
            2 => crate::theme::ColorMode::Dark,
            _ => crate::theme::ColorMode::Auto,
        };
        if let Some(app) = drop_root.root()
            .and_then(|r| r.downcast::<gtk::Window>().ok())
            .and_then(|w| w.application())
            .and_then(|a| a.downcast::<adw::Application>().ok())
        {
            crate::theme::set_scheme(&app, mode);
        }
    });
    t1.add_suffix(&drop);
    g4.add(&t1);
    root.append(&g4);

    scroll.set_child(Some(&root));
    scroll.upcast()
}
