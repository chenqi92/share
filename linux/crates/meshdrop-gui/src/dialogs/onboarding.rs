//! Onboarding：4 步介绍（发现 / 拖即发 / E2E / 状态栏）。

use crate::components::{chip, meshdrop_logo};
use adw::prelude::*;

const STEPS: &[(&str, &str, &str)] = &[
    ("●", "雷达式发现 · Radar discovery",
     "MeshDrop 在你的局域网里广播一条 _meshdrop._tcp 服务，所有跑着 MeshDrop 的设备都会在数秒内出现在「附近」雷达上。"),
    ("◐", "拖即发送 · Drag to send",
     "Files、剪贴板、文字便签都能直接拖到目标设备的卡片里。释放时高亮 lime 边框，1 秒内对方屏上出现接收 sheet。"),
    ("◉", "端到端加密 · X25519 + ChaCha20",
     "所有传输都强制端对端加密。首次连接弹出 TOFU 配对，确认指纹后写入本机信任库；之后无需再次确认。"),
    ("◓", "状态条 · trace",
     "顶栏状态条会显示 mDNS 注册情况、加密套件、剪贴板同步条数和当前局域网摘要——一眼判断「这次为什么发不出去」。"),
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
    let sub_en = gtk::Label::new(Some("An intranet drop · radar discovery · drag-to-send · E2E encryption"));
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

    let pager = chip::chip("STEP 1 of 4", chip::Tone::Outline, true);
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
