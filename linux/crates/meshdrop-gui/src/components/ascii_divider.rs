//! ASCII divider：两条 hr + 中间 mono uppercase label。
//! 例：── TODAY · 今天 · 5 件 ──

use adw::prelude::*;

pub fn divider(label: &str) -> gtk::Box {
    let row = gtk::Box::new(gtk::Orientation::Horizontal, 10);
    row.set_valign(gtk::Align::Center);

    let l_line = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    l_line.add_css_class("meshdrop-divider-line");
    l_line.set_hexpand(true);
    l_line.set_valign(gtk::Align::Center);

    let r_line = gtk::Box::new(gtk::Orientation::Horizontal, 0);
    r_line.add_css_class("meshdrop-divider-line");
    r_line.set_hexpand(true);
    r_line.set_valign(gtk::Align::Center);

    let lb = gtk::Label::new(Some(label));
    lb.add_css_class("meshdrop-ascii-divider");

    row.append(&l_line);
    row.append(&lb);
    row.append(&r_line);
    row
}
