//! Onboarding：4 步介绍（发现 / 拖即发 / E2E / 状态栏）。

use crate::components::{chip, meshdrop_logo};
use adw::prelude::*;

// 文案不在此放字面量，改运行时按 i18n key 取（见 STEP_KEYS / onboarding.step*_title/_body）。
const STEP_GLYPHS: &[&str] = &["●", "◐", "◉", "◓"];
const STEP_KEYS: &[(&str, &str)] = &[
    ("onboarding.step1_title", "onboarding.step1_body"),
    ("onboarding.step2_title", "onboarding.step2_body"),
    ("onboarding.step3_title", "onboarding.step3_body"),
    ("onboarding.step4_title", "onboarding.step4_body"),
];

pub fn present(parent: &impl IsA<gtk::Window>) -> adw::Window {
    let win = adw::Window::builder()
        .transient_for(parent)
        .modal(true)
        .title(t!("onboarding.window_title").as_ref())
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
    let sub = gtk::Label::new(Some(&*t!("app.tagline")));
    sub.add_css_class("meshdrop-muted");
    sub.set_halign(gtk::Align::Center);
    head.append(&sub);
    let sub_en = gtk::Label::new(Some(&*t!("app.tagline_en")));
    sub_en.add_css_class("meshdrop-meta");
    sub_en.set_halign(gtk::Align::Center);
    head.append(&sub_en);
    root.append(&head);

    // 4 步
    let steps_box = gtk::Box::new(gtk::Orientation::Vertical, 12);
    for (i, (title_key, body_key)) in STEP_KEYS.iter().enumerate() {
        let glyph = STEP_GLYPHS.get(i).copied().unwrap_or("●");
        steps_box.append(&step_row(glyph, &t!(*title_key), &t!(*body_key)));
    }
    root.append(&steps_box);

    // 底部按钮
    let btn_row = gtk::Box::new(gtk::Orientation::Horizontal, 8);
    btn_row.set_halign(gtk::Align::Center);
    btn_row.set_margin_top(12);
    let skip = gtk::Button::with_label(&t!("onboarding.skip"));
    let start = gtk::Button::with_label(&t!("onboarding.start"));
    start.add_css_class("suggested-action");
    btn_row.append(&skip);
    btn_row.append(&start);
    root.append(&btn_row);

    // 这是单页一次性概览（非分页向导）；用中性标签而非误导的 “STEP 1 of 4”。
    let pager = chip::chip(&t!("onboarding.overview", count = STEP_KEYS.len()), chip::Tone::Outline, true);
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
