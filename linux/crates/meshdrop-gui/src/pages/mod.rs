//! 全部页面。每张页面返回一个 `gtk::Widget`，由 ui::shell 的 Stack 持有。

pub mod discovery;
pub mod chat;
pub mod transfers;
pub mod history;
pub mod trust;
pub mod settings;
pub mod empty;
