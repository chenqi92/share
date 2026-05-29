//! 主窗口 shell：左侧 sidebar（logo + 导航 + 设备列表） + 中央 Stack + 底部状态条。
//!
//! 数据源：当 `handle.is_some()` 时来自 ShareEngine（订阅 watch::Receiver）；
//! 当 `handle.is_none()` 时（screenshots / fallback）保留 mock 渲染。

use crate::components::{ascii_divider, chip, device_row, icon_btn, meshdrop_logo};
use crate::dialogs;
use crate::engine_bridge::{AppHandle, EngineStatus};
use crate::mock;
use crate::pages;
use crate::theme;
use crate::view::ViewDevice;
use adw::prelude::*;
use std::cell::RefCell;
use std::rc::Rc;

const PAGES: &[(&str, &str, &str)] = &[
    ("discovery", "附近 · Nearby",   "🛰"),
    ("chat",      "对话 · Chat",     "✱"),
    ("transfers", "传输 · Transfers", "↕"),
    ("clipboard", "剪贴板 · Clipboard", "📋"),
    ("history",   "历史 · History",  "◫"),
    ("trust",     "已配对 · Trusted", "◉"),
    ("settings",  "设置 · Settings", "⚙"),
    ("empty",     "空态 · States",   "○"),
];

pub struct Shell {
    pub window: adw::ApplicationWindow,
    pub stack: gtk::Stack,
}

pub fn build(app: &adw::Application, handle: Option<Rc<AppHandle>>) {
    let shell = build_shell(app, handle);
    shell.window.present();
}

pub fn build_shell(app: &adw::Application, handle: Option<Rc<AppHandle>>) -> Shell {
    theme::install();

    let window = adw::ApplicationWindow::builder()
        .application(app)
        .default_width(1280)
        .default_height(820)
        .title("MeshDrop")
        .icon_name("com.welape.meshdrop.linux")
        .build();

    let toolbar = adw::ToolbarView::new();

    // ── HeaderBar ──
    let header = adw::HeaderBar::new();

    let title_pack = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    title_pack.set_halign(gtk::Align::Center);
    title_pack.append(&meshdrop_logo::lockup(22, meshdrop_logo::LogoTone::Dark));

    // 状态 chip：根据 engine 状态显示
    let status_chip = chip::chip_with_dot("LIVE · LAN", chip::Tone::Mute, "#A8C800");
    title_pack.append(&status_chip);
    header.set_title_widget(Some(&title_pack));

    // 错误 banner（默认隐藏）—— 显示在 HeaderBar 下方
    let error_banner = adw::Banner::builder().build();
    error_banner.set_revealed(false);

    let pair_btn = icon_btn::icon_btn("配对", "弹出配对窗 · Pairing", icon_btn::IconBtnTone::Default);
    let offer_btn = icon_btn::icon_btn("接收", "弹出文件 offer · File offer", icon_btn::IconBtnTone::Default);
    let intro_btn = icon_btn::icon_btn("Onboarding", "首次教程", icon_btn::IconBtnTone::Default);
    let send_btn = icon_btn::icon_btn("发送 · Send", "选择文件 / 文字便签", icon_btn::IconBtnTone::Accent);
    header.pack_end(&send_btn);
    header.pack_end(&intro_btn);
    header.pack_end(&offer_btn);
    header.pack_end(&pair_btn);

    let theme_btn = icon_btn::icon_btn("☼", "切换浅 / 暗", icon_btn::IconBtnTone::Default);
    header.pack_start(&theme_btn);

    toolbar.add_top_bar(&header);
    toolbar.add_top_bar(&error_banner);

    // ── 主内容 ──
    let body = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    body.set_hexpand(true);
    body.set_vexpand(true);

    let sidebar = build_sidebar(handle.as_ref());
    body.append(&sidebar.root);

    let stack = gtk::Stack::builder()
        .transition_type(gtk::StackTransitionType::Crossfade)
        .transition_duration(140)
        .hexpand(true)
        .vexpand(true)
        .build();

    for (id, _, _) in PAGES {
        let widget = match *id {
            "discovery" => pages::discovery::build(handle.as_ref()),
            "chat"      => pages::chat::build(handle.as_ref()),
            "transfers" => pages::transfers::build(handle.as_ref()),
            "clipboard" => pages::clipboard::build(handle.as_ref()),
            "history"   => pages::history::build(handle.as_ref()),
            "trust"     => pages::trust::build(handle.as_ref()),
            "settings"  => pages::settings::build(handle.as_ref()),
            "empty"     => pages::empty::build(),
            _ => gtk::Box::new(gtk::Orientation::Vertical, 0).upcast(),
        };
        stack.add_named(&widget, Some(id));
    }
    stack.set_visible_child_name("discovery");

    let stack_rc = stack.clone();
    sidebar.connect_nav(move |id| {
        stack_rc.set_visible_child_name(id);
    });

    body.append(&stack);

    let statusbar = build_statusbar(handle.as_ref());
    let content_col = gtk::Box::new(gtk::Orientation::Vertical, 0);
    content_col.append(&body);
    content_col.append(&statusbar.root);

    toolbar.set_content(Some(&content_col));
    window.set_content(Some(&toolbar));

    // 顶栏按钮回调
    let win_for_pair = window.clone();
    let handle_for_pair = handle.clone();
    pair_btn.connect_clicked(move |_| {
        dialogs::pairing::present(&win_for_pair, handle_for_pair.as_ref());
    });
    let win_for_offer = window.clone();
    let handle_for_offer = handle.clone();
    offer_btn.connect_clicked(move |_| {
        dialogs::file_offer::present(&win_for_offer, handle_for_offer.as_ref());
    });
    let win_for_intro = window.clone();
    intro_btn.connect_clicked(move |_| { dialogs::onboarding::present(&win_for_intro); });

    let app_for_theme = app.clone();
    let cur = Rc::new(RefCell::new(theme::ColorMode::Auto));
    theme_btn.connect_clicked(move |btn| {
        let next = match *cur.borrow() {
            theme::ColorMode::Auto  => theme::ColorMode::Light,
            theme::ColorMode::Light => theme::ColorMode::Dark,
            theme::ColorMode::Dark  => theme::ColorMode::Auto,
        };
        *cur.borrow_mut() = next;
        theme::set_scheme(&app_for_theme, next);
        let glyph = match next {
            theme::ColorMode::Auto  => "☼",
            theme::ColorMode::Light => "☀",
            theme::ColorMode::Dark  => "☾",
        };
        btn.set_label(glyph);
    });

    let win_for_send = window.clone();
    let handle_for_send = handle.clone();
    send_btn.connect_clicked(move |_| {
        dialogs::file_offer::present(&win_for_send, handle_for_send.as_ref());
    });

    // 订阅 engine 事件：自动弹 pairing / offer 对话框，更新 banner
    if let Some(h) = handle.as_ref() {
        let win_auto = window.clone();
        let h_auto = h.clone();
        h.observe(h.engine.pending_pairings_rx(), move |list| {
            if list.is_empty() { return; }
            // 自动弹出第一条
            dialogs::pairing::present(&win_auto, Some(&h_auto));
        });

        let win_auto2 = window.clone();
        let h_auto2 = h.clone();
        h.observe(h.engine.pending_offers_rx(), move |list| {
            if list.is_empty() { return; }
            dialogs::file_offer::present(&win_auto2, Some(&h_auto2));
        });

        // 错误态：可在未来某接口暴露 lastError；当前先做空。
        let _ = error_banner.clone();
        let status_chip_c = status_chip.clone();
        match h.status.get() {
            EngineStatus::Starting => {
                status_chip_c.remove_css_class("meshdrop-chip-lime");
                error_banner.set_title("引擎启动中 · scanning LAN");
                error_banner.set_revealed(true);
            }
            EngineStatus::Running => { error_banner.set_revealed(false); }
            EngineStatus::Error => {
                error_banner.set_title("引擎出错 · 请查看终端日志");
                error_banner.set_revealed(true);
            }
        }
    } else {
        // 没有 handle —— banner 提示用户引擎未启动
        error_banner.set_title("引擎未启动 · UI 仅展示 mock 数据");
        error_banner.set_revealed(true);
    }

    Shell { window, stack }
}

struct Sidebar {
    root: gtk::Box,
    nav_buttons: Vec<(String, gtk::Button)>,
}

impl Sidebar {
    fn connect_nav<F: Fn(&str) + 'static>(&self, cb: F) {
        let cb = Rc::new(cb);
        let buttons: Vec<(String, gtk::Button)> = self.nav_buttons.clone();
        for (id, btn) in &self.nav_buttons {
            let id = id.clone();
            let cb = cb.clone();
            let all = buttons.clone();
            btn.connect_clicked(move |_| {
                for (_, b) in &all { b.remove_css_class("active"); }
                if let Some((_, b)) = all.iter().find(|(i, _)| i == &id) {
                    b.add_css_class("active");
                }
                cb(&id);
            });
        }
    }
}

fn build_sidebar(handle: Option<&Rc<AppHandle>>) -> Sidebar {
    let root = gtk::Box::new(gtk::Orientation::Vertical, 12);
    root.add_css_class("meshdrop-sidebar");
    root.set_size_request(260, -1);
    root.set_margin_top(16);
    root.set_margin_bottom(12);

    // search
    let search_pad = gtk::Box::new(gtk::Orientation::Vertical, 0);
    search_pad.set_margin_start(12);
    search_pad.set_margin_end(12);
    let search = gtk::Entry::builder()
        .placeholder_text("⌘K  搜索设备 / 文件 / 历史…")
        .build();
    search_pad.append(&search);
    root.append(&search_pad);

    // 一级导航
    let nav = gtk::Box::new(gtk::Orientation::Vertical, 2);
    nav.set_margin_start(8);
    nav.set_margin_end(8);

    let mut nav_buttons: Vec<(String, gtk::Button)> = Vec::new();
    for (id, label, glyph) in PAGES {
        let row = gtk::Button::new();
        row.add_css_class("meshdrop-nav-row");
        row.set_has_frame(false);
        if *id == "discovery" { row.add_css_class("active"); }

        let inner = gtk::Box::new(gtk::Orientation::Horizontal, 10);
        let g = gtk::Label::new(Some(glyph));
        g.add_css_class("meshdrop-mono");
        g.set_size_request(22, -1);
        inner.append(&g);
        let l = gtk::Label::new(Some(label));
        l.set_halign(gtk::Align::Start);
        l.set_hexpand(true);
        inner.append(&l);
        row.set_child(Some(&inner));
        nav.append(&row);
        nav_buttons.push(((*id).to_string(), row));
    }
    root.append(&nav);

    // ── 设备列表 ──
    let peer_divider = ascii_divider::build("── PEERS · 设备 · 0 ──");
    peer_divider.root.set_margin_start(14);
    peer_divider.root.set_margin_end(14);
    peer_divider.root.set_margin_top(6);
    root.append(&peer_divider.root);
    let peer_divider_label = peer_divider.label.clone();

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .build();
    let dev_list = gtk::Box::new(gtk::Orientation::Vertical, 4);
    dev_list.set_margin_start(8);
    dev_list.set_margin_end(8);
    scroll.set_child(Some(&dev_list));
    root.append(&scroll);

    // 注册设备列表订阅 / fallback 渲染
    let dev_list_for_obs = dev_list.clone();
    let divider_for_obs = peer_divider_label.clone();
    if let Some(h) = handle {
        h.observe(h.engine.devices_rx(), move |devs| {
            clear_box(&dev_list_for_obs);
            let views: Vec<ViewDevice> = devs.iter().enumerate()
                .map(|(i, d)| ViewDevice::from_device(d, i))
                .collect();
            for v in &views {
                let r = device_row::build(v, false);
                dev_list_for_obs.append(&r);
            }
            divider_for_obs.set_text(&format!("── PEERS · 设备 · {} ──", views.len()));
        });
    } else {
        for (i, d) in mock::devices().iter().enumerate() {
            let v = ViewDevice::from_mock(d);
            let r = device_row::build(&v, i == mock::CHAT_PEER_INDEX);
            dev_list.append(&r);
        }
        peer_divider_label.set_text(&format!("── PEERS · 设备 · {} ──", mock::devices().len()));
    }

    // 底部本机摘要
    let me_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    me_row.set_margin_start(14);
    me_row.set_margin_end(14);
    me_row.set_margin_top(6);
    me_row.append(&crate::components::avatar::avatar("我", "#DDF94B", 24,
                                                     crate::components::avatar::Ring::Lime));
    let me_col = gtk::Box::new(gtk::Orientation::Vertical, 0);
    let (me_name, me_fp) = if let Some(h) = handle {
        (h.engine.display_name.clone(), h.fingerprint())
    } else {
        let m = mock::me();
        (m.name.to_string(), m.fingerprint.to_string())
    };
    let nm = gtk::Label::new(Some(&format!("我 · {}", me_name)));
    nm.add_css_class("meshdrop-body");
    nm.set_halign(gtk::Align::Start);
    me_col.append(&nm);
    let fp = gtk::Label::new(Some(&me_fp));
    fp.add_css_class("meshdrop-meta");
    fp.set_halign(gtk::Align::Start);
    me_col.append(&fp);
    me_col.set_hexpand(true);
    me_row.append(&me_col);
    me_row.append(&chip::chip("E2E", chip::Tone::Lime, true));
    root.append(&me_row);

    Sidebar { root, nav_buttons }
}

pub fn clear_box(b: &gtk::Box) {
    while let Some(child) = b.first_child() {
        b.remove(&child);
    }
}

struct Statusbar { root: gtk::Box }

fn build_statusbar(handle: Option<&Rc<AppHandle>>) -> Statusbar {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 14);
    row.add_css_class("meshdrop-statusbar");

    let mk = |s: &str| {
        let l = gtk::Label::new(Some(s));
        l.add_css_class("meshdrop-meta");
        l.add_css_class("meshdrop-mono");
        l
    };

    let online_chip = chip::chip_with_dot("ONLINE", chip::Tone::Mute, "#A8C800");
    row.append(&online_chip);

    let mdns_label = mk("_meshdrop._tcp · 0 peers");
    row.append(&mdns_label);
    row.append(&sep());
    row.append(&mk("X25519 + ChaCha20-Poly1305"));
    row.append(&sep());

    let gateway_text = match handle {
        Some(h) => match h.gateway_port() {
            Some(p) => format!("Web Gateway · :{}", p),
            None => "Web Gateway · OFF".to_string(),
        },
        None => "Web Gateway · OFF".to_string(),
    };
    let gw = mk(&gateway_text);
    row.append(&gw);
    row.append(&sep());

    let trace_text = match handle.and_then(|h| h.self_ip.borrow().clone()) {
        Some(ip) => format!("LAN · {} · MTU 1500", ip),
        None => "LAN · 192.168.1.0/24 · MTU 1500".to_string(),
    };
    row.append(&mk(&trace_text));

    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    row.append(&sp);

    let build_id = gtk::Label::new(Some("meshdrop 0.2 · build 20260524"));
    build_id.add_css_class("meshdrop-meta");
    build_id.add_css_class("meshdrop-mono");
    row.append(&build_id);

    // 订阅 mDNS peers 数
    if let Some(h) = handle {
        let label_clone = mdns_label.clone();
        h.observe(h.engine.devices_rx(), move |devs| {
            label_clone.set_text(&format!("_meshdrop._tcp · {} peers", devs.len()));
        });
    }

    Statusbar { root: row }
}

fn sep() -> gtk::Label {
    let s = gtk::Label::new(Some("·"));
    s.add_css_class("meshdrop-meta");
    s
}
