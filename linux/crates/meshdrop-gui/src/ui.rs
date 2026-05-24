//! 主窗口 shell：左侧 sidebar（logo + 导航 + 设备列表） + 中央 Stack + 底部状态条。
//!
//! 全部 mock 驱动；点 sidebar 切换 Stack；右上工具栏可触发 Pairing / Onboarding / FileOffer 弹窗。

use crate::components::{ascii_divider, chip, device_row, icon_btn, meshdrop_logo};
use crate::dialogs;
use crate::mock;
use crate::pages;
use crate::theme;
use adw::prelude::*;
use std::cell::RefCell;
use std::rc::Rc;

const PAGES: &[(&str, &str, &str)] = &[
    ("discovery", "附近 · Nearby",   "🛰"),
    ("chat",      "对话 · Chat",     "✱"),
    ("transfers", "传输 · Transfers", "↕"),
    ("history",   "历史 · History",  "◫"),
    ("trust",     "已配对 · Trusted", "◉"),
    ("settings",  "设置 · Settings", "⚙"),
    ("empty",     "空态 · States",   "○"),
];

pub fn build(app: &adw::Application) {
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
    header.set_show_title(false);

    let title_pack = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    title_pack.append(&meshdrop_logo::lockup(22, meshdrop_logo::LogoTone::Dark));
    title_pack.append(&chip::chip_with_dot("LIVE · LAN", chip::Tone::Mute, "#A8C800"));
    header.set_title_widget(Some(&title_pack));

    // 右侧动作
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

    // ── 主内容：sidebar + stack ──
    let body = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    body.set_hexpand(true);
    body.set_vexpand(true);

    let sidebar = build_sidebar();
    body.append(&sidebar.root);

    let stack = gtk::Stack::builder()
        .transition_type(gtk::StackTransitionType::Crossfade)
        .transition_duration(140)
        .hexpand(true)
        .vexpand(true)
        .build();

    for (id, _, _) in PAGES {
        let widget = match *id {
            "discovery" => pages::discovery::build(),
            "chat"      => pages::chat::build(),
            "transfers" => pages::transfers::build(),
            "history"   => pages::history::build(),
            "trust"     => pages::trust::build(),
            "settings"  => pages::settings::build(),
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

    let content_col = gtk::Box::new(gtk::Orientation::Vertical, 0);
    content_col.append(&body);
    content_col.append(&build_statusbar());

    toolbar.set_content(Some(&content_col));
    window.set_content(Some(&toolbar));

    // 顶栏按钮回调
    let win_for_pair = window.clone();
    pair_btn.connect_clicked(move |_| dialogs::pairing::present(&win_for_pair));
    let win_for_offer = window.clone();
    offer_btn.connect_clicked(move |_| dialogs::file_offer::present(&win_for_offer));
    let win_for_intro = window.clone();
    intro_btn.connect_clicked(move |_| dialogs::onboarding::present(&win_for_intro));

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
    send_btn.connect_clicked(move |_| dialogs::file_offer::present(&win_for_send));

    window.present();
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

fn build_sidebar() -> Sidebar {
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
        if *id == "chat" {
            inner.append(&chip::chip("6", chip::Tone::Ink, true));
        }
        if *id == "transfers" {
            inner.append(&chip::chip("3", chip::Tone::Flame, true));
        }
        row.set_child(Some(&inner));
        nav.append(&row);
        nav_buttons.push(((*id).to_string(), row));
    }
    root.append(&nav);

    // ── 设备列表（sidebar 半部分）──
    let div = ascii_divider::divider("── PEERS · 设备 · 5 ──");
    div.set_margin_start(14);
    div.set_margin_end(14);
    div.set_margin_top(6);
    root.append(&div);

    let scroll = gtk::ScrolledWindow::builder()
        .hscrollbar_policy(gtk::PolicyType::Never)
        .vexpand(true)
        .build();
    let dev_list = gtk::Box::new(gtk::Orientation::Vertical, 4);
    dev_list.set_margin_start(8);
    dev_list.set_margin_end(8);
    for (i, d) in mock::devices().iter().enumerate() {
        let r = device_row::build(d, i == mock::CHAT_PEER_INDEX);
        dev_list.append(&r);
    }
    scroll.set_child(Some(&dev_list));
    root.append(&scroll);

    // 底部本机摘要
    let me_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    me_row.set_margin_start(14);
    me_row.set_margin_end(14);
    me_row.set_margin_top(6);
    me_row.append(&crate::components::avatar::avatar("我", "#DDF94B", 24,
                                                     crate::components::avatar::Ring::Lime));
    let me_col = gtk::Box::new(gtk::Orientation::Vertical, 0);
    let me = mock::me();
    let nm = gtk::Label::new(Some("我 · welape-arch"));
    nm.add_css_class("meshdrop-body");
    nm.set_halign(gtk::Align::Start);
    me_col.append(&nm);
    let fp = gtk::Label::new(Some(me.fingerprint));
    fp.add_css_class("meshdrop-meta");
    fp.set_halign(gtk::Align::Start);
    me_col.append(&fp);
    me_col.set_hexpand(true);
    me_row.append(&me_col);
    me_row.append(&chip::chip("E2E", chip::Tone::Lime, true));
    root.append(&me_row);

    Sidebar { root, nav_buttons }
}

fn build_statusbar() -> gtk::Box {
    let st = mock::shell_status();
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 14);
    row.add_css_class("meshdrop-statusbar");

    let mk = |s: &str| {
        let l = gtk::Label::new(Some(s));
        l.add_css_class("meshdrop-meta");
        l.add_css_class("meshdrop-mono");
        l
    };

    row.append(&chip::chip_with_dot("ONLINE", chip::Tone::Mute, "#A8C800"));
    row.append(&mk(st.mdns));
    row.append(&sep());
    row.append(&mk(st.e2e));
    row.append(&sep());
    row.append(&mk(st.clip));
    row.append(&sep());
    row.append(&mk(st.trace));

    let sp = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    sp.set_hexpand(true);
    row.append(&sp);

    let build_id = gtk::Label::new(Some("meshdrop 0.2 · build 20260524"));
    build_id.add_css_class("meshdrop-meta");
    build_id.add_css_class("meshdrop-mono");
    row.append(&build_id);

    row
}

fn sep() -> gtk::Label {
    let s = gtk::Label::new(Some("·"));
    s.add_css_class("meshdrop-meta");
    s
}
