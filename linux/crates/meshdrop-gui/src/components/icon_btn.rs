//! 圆/胶囊小按钮。size 32 默认，accent=true 时 lime 底 + ink 字。

use adw::prelude::*;

#[derive(Copy, Clone)]
pub enum IconBtnTone { Default, Accent, Danger }

pub fn icon_btn(symbol: &str, tooltip: &str, tone: IconBtnTone) -> gtk::Button {
    let b = gtk::Button::with_label(symbol);
    b.set_tooltip_text(Some(tooltip));
    b.add_css_class("meshdrop-iconbtn");
    match tone {
        IconBtnTone::Accent => b.add_css_class("accent"),
        IconBtnTone::Danger => b.add_css_class("danger"),
        IconBtnTone::Default => {}
    }
    b
}
