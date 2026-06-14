//! 聊天气泡。in / out 两侧。
//! incoming：白底 / dark 半透明灰
//! outgoing：light 黑底 / **dark lime 底**（一定注意暗模式 lime）。

use crate::components::file_chip;
use crate::mock::{ChatBody, ChatMsg, Dir};
use adw::prelude::*;

/// 借用型气泡内容。real 路径直接用 &str 构造，避免把每条历史 Box::leak 成 'static。
pub enum BubbleBody<'a> {
    Text(&'a str),
    File { name: &'a str, size: &'a str, ext: &'a str },
    Image { caption: &'a str },
}

pub struct BubbleView<'a> {
    pub side: Dir,
    pub time: &'a str,
    pub body: BubbleBody<'a>,
    pub delivered: bool,
}

impl<'a> BubbleView<'a> {
    /// 从 mock::ChatMsg（'static 字段）借用，供截图 / mock 路径复用。
    pub fn from_mock(msg: &'a ChatMsg) -> Self {
        let body = match &msg.body {
            ChatBody::Text(t) => BubbleBody::Text(t),
            ChatBody::File { name, size, ext } => BubbleBody::File { name, size, ext },
            ChatBody::Image { caption } => BubbleBody::Image { caption },
        };
        BubbleView { side: msg.side, time: msg.time, body, delivered: msg.delivered }
    }
}

/// mock 路径入口（保持旧签名，内部转 BubbleView）。
pub fn bubble(msg: &ChatMsg) -> gtk::Box {
    bubble_view(&BubbleView::from_mock(msg))
}

/// 借用型渲染入口：real 路径用 &str 直接构造 BubbleView，无内存泄漏。
pub fn bubble_view(msg: &BubbleView) -> gtk::Box {
    let outer = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    let group = gtk::Box::new(gtk::Orientation::Vertical, 4);
    group.set_hexpand(false);

    match msg.side {
        Dir::Out => outer.set_halign(gtk::Align::End),
        Dir::In  => outer.set_halign(gtk::Align::Start),
    }

    let body_box = gtk::Box::new(gtk::Orientation::Vertical, 6);
    match msg.side {
        Dir::Out => body_box.add_css_class("meshdrop-bubble-out"),
        Dir::In  => body_box.add_css_class("meshdrop-bubble-in"),
    }
    body_box.set_size_request(180, -1);
    if let Some(w) = max_bubble_width(&msg.body) { body_box.set_size_request(w, -1); }

    match &msg.body {
        BubbleBody::Text(t) => {
            let lb = gtk::Label::new(Some(*t));
            lb.set_wrap(true);
            lb.set_wrap_mode(gtk::pango::WrapMode::WordChar);
            lb.set_xalign(0.0);
            lb.set_halign(gtk::Align::Start);
            lb.set_max_width_chars(36);
            body_box.append(&lb);
        }
        BubbleBody::File { name, size, ext } => {
            body_box.append(&file_chip::chip(name, size, ext, None));
        }
        BubbleBody::Image { caption } => {
            let img = crate::components::photo::photo(220, 130, 180.0);
            body_box.append(&img);
            let lb = gtk::Label::new(Some(*caption));
            lb.set_xalign(0.0);
            lb.set_wrap(true);
            body_box.append(&lb);
        }
    }
    group.append(&body_box);

    let time_row = gtk::Box::new(gtk::Orientation::Horizontal, 4);
    match msg.side {
        Dir::Out => time_row.set_halign(gtk::Align::End),
        Dir::In  => time_row.set_halign(gtk::Align::Start),
    }
    let t = gtk::Label::new(Some(msg.time));
    t.add_css_class("meshdrop-bubble-time");
    time_row.append(&t);
    if msg.delivered && matches!(msg.side, Dir::Out) {
        let ok = gtk::Label::new(Some("· 已送达"));
        ok.add_css_class("meshdrop-bubble-time");
        ok.add_css_class("meshdrop-bubble-delivered");
        time_row.append(&ok);
    }
    group.append(&time_row);

    outer.append(&group);
    outer
}

fn max_bubble_width(body: &BubbleBody) -> Option<i32> {
    match body {
        BubbleBody::Text(s) => {
            let len = s.chars().count();
            if len < 12 { Some(140) }
            else if len < 24 { Some(220) }
            else { Some(320) }
        }
        BubbleBody::File { .. } => Some(280),
        BubbleBody::Image { .. } => Some(240),
    }
}
