//! Onboarding：4 步介绍（发现 / 拖即发 / E2E / 状态栏）。

use crate::components::{chip, meshdrop_logo};
use adw::prelude::*;

const STEPS: &[(&str, &str, &str)] = &[
    ("●", "雷达式发现 · Radar discovery",
     "MeshDrop 在你的局域网里广播一条 _meshdrop._tcp 服务，所有跑着 MeshDrop 的设备都会在数秒内出现在「附近」雷达上。"),
    ("◐", "拖即发送 · Drag to send",
     "Files、剪贴板、文字便签都能直接拖到目标设备的卡片里。释放时高亮 lime 边框，1 秒内对方屏上出现接收 sheet。"),
    // v0.1 局域网为明文 TCP，尚未上 TLS / E2E；不把未实现的加密当已具备能力宣传。
    ("◉", "TOFU 信任 · Ed25519 指纹",
     "首次连接弹出配对，确认对方 Ed25519 指纹（SHA-256）后写入本机信任库；之后无需再次确认。v0.1 局域网传输为明文 TCP，TLS 1.3 mTLS 规划中。"),
    ("◓", "状态条 · trace",
     "顶栏状态条会显示 mDNS 注册情况、传输层现状、剪贴板同步条数和当前局域网摘要——一眼判断「这次为什么发不出去」。"),
];

pub fn present(parent: &impl IsA<gtk::Window>) -> adw::Window {
    let win = adw::Window::builder()
        .transient_for(parent)
        .modal(true)
        .title("欢迎 · Welcome")
        .default_width(560)
        .default_height(560)
        .build();

    let toolbar = adw::ToolbarView::new();
    toolbar.add_top_bar(&adw::HeaderBar::new());

    let root = gtk::Box::new(gtk::Orientation::Vertical, 18);
    root.set_margin_top(20);
    root.set_margin_bottom(20);
    root.set_margin_start(28);
    root.set_margin_end(28);

    // logo + 标题
    let head = gtk::Box::new(gtk::Orientation::Vertical, 8);
    head.set_halign(gtk::Align::Center);
    head.append(&meshdrop_logo::lockup(42, meshdrop_logo::LogoTone::Dark));
    let sub = gtk::Label::new(Some("一个内网，任何设备，谁都能 ping 到。"));
    sub.add_css_class("meshdrop-muted");
    sub.set_halign(gtk::Align::Center);
    head.append(&sub);
    let sub_en = gtk::Label::new(Some("An intranet drop · radar discovery · drag-to-send · TOFU trust"));
    sub_en.add_css_class("meshdrop-meta");
    sub_en.set_halign(gtk::Align::Center);
    head.append(&sub_en);
    root.append(&head);

    // 4 步
    let steps_box = gtk::Box::new(gtk::Orientation::Vertical, 12);
    for (glyph, title, body) in STEPS {
        steps_box.append(&step_row(glyph, title, body));
    }
    root.append(&steps_box);

    // 底部按钮
    let btn_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    btn_row.set_halign(gtk::Align::Center);
    btn_row.set_margin_top(12);
    let skip = gtk::Button::with_label("跳过 · Skip");
    let start = gtk::Button::with_label("开始 · Get started");
    start.add_css_class("suggested-action");
    btn_row.append(&skip);
    btn_row.append(&start);
    root.append(&btn_row);

    // 这是单页一次性概览（非分页向导）；用中性标签而非误导的 “STEP 1 of 4”。
    let pager = chip::chip(&format!("{} 步概览 · OVERVIEW", STEPS.len()), chip::Tone::Outline, true);
    pager.set_halign(gtk::Align::Center);
    root.append(&pager);

    toolbar.set_content(Some(&root));
    win.set_content(Some(&toolbar));
    let win_c = win.clone();
    skip.connect_clicked(move |_| win_c.close());
    let win_c = win.clone();
    start.connect_clicked(move |_| win_c.close());
    win.present();
    win
}

fn step_row(glyph: &str, title: &str, body: &str) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 14);
    row.add_css_class("meshdrop-card");
    let g = gtk::Label::new(Some(glyph));
    g.add_css_class("meshdrop-display");
    g.set_size_request(36, 36);
    row.append(&g);
    let col = gtk::Box::new(gtk::Orientation::Vertical, 4);
    col.set_hexpand(true);
    let t = gtk::Label::new(Some(title));
    t.add_css_class("meshdrop-card-title");
    t.set_halign(gtk::Align::Start);
    col.append(&t);
    let b = gtk::Label::new(Some(body));
    b.add_css_class("meshdrop-muted");
    b.set_halign(gtk::Align::Start);
    b.set_wrap(true);
    b.set_max_width_chars(50);
    b.set_xalign(0.0);
    col.append(&b);
    row.append(&col);
    row
}
