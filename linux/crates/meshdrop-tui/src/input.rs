//! 按键状态机。从 crossterm KeyEvent 翻译成业务意图。

use crossterm::event::{KeyCode, KeyEvent, KeyModifiers};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Focus {
    Devices,
    History,
    Transfers,
}

impl Focus {
    pub fn next(self) -> Self {
        match self {
            Focus::Devices => Focus::History,
            Focus::History => Focus::Transfers,
            Focus::Transfers => Focus::Devices,
        }
    }
}

impl Page {
    /// 页签顺序（与顶部 tab 渲染、F1..F6 / 数字键 1..6 一一对应）。
    const ORDER: [Page; 6] = [
        Page::Discovery,
        Page::Transfers,
        Page::History,
        Page::Trust,
        Page::Clipboard,
        Page::Settings,
    ];

    fn index(self) -> usize {
        Self::ORDER.iter().position(|p| *p == self).unwrap_or(0)
    }

    /// 循环切到下一页（用于 `]` / Tab-less 终端的可靠备用切页）。
    pub fn next(self) -> Self {
        Self::ORDER[(self.index() + 1) % Self::ORDER.len()]
    }

    /// 循环切到上一页（`[`）。
    pub fn prev(self) -> Self {
        Self::ORDER[(self.index() + Self::ORDER.len() - 1) % Self::ORDER.len()]
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Page {
    Discovery,
    Transfers,
    History,
    Trust,
    Clipboard,
    Settings,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mode {
    Normal,
    InputText,
    Command,
    Search,
    Help,
    Pairing,
    FileOffer,
}

/// 一次按键产生的意图。
#[derive(Clone, Debug)]
pub enum Action {
    Quit,
    None,
    MoveUp,
    MoveDown,
    NextFocus,
    PrevFocus,
    SwitchPage(Page),
    NextPage,
    PrevPage,

    EnterInputText,
    EnterCommand,
    EnterSearch,

    PushChar(char),
    PopChar,
    Submit,
    Cancel,

    OpenHelp,
    DemoPairing,
    DemoOffer,

    Accept,
    Reject,
    Trust,

    DeleteSelected,
    ClearHistory,
    CancelTransfer,
    RetryTransfer,
}

pub fn translate(mode: Mode, key: KeyEvent) -> Action {
    // Ctrl-C 永远退出（即便在输入模式）
    if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
        return Action::Quit;
    }
    match mode {
        Mode::Normal => translate_normal(key),
        Mode::Help => match key.code {
            KeyCode::Char('q') | KeyCode::Esc | KeyCode::Char('?') => Action::Cancel,
            _ => Action::Cancel,
        },
        Mode::Pairing => match key.code {
            KeyCode::Char('a') => Action::Accept,
            KeyCode::Char('t') => Action::Trust,
            KeyCode::Char('r') => Action::Reject,
            KeyCode::Esc => Action::Cancel,
            _ => Action::None,
        },
        Mode::FileOffer => match key.code {
            KeyCode::Char('a') => Action::Accept,
            KeyCode::Char('t') => Action::Trust,
            KeyCode::Char('r') => Action::Reject,
            KeyCode::Esc => Action::Cancel,
            _ => Action::None,
        },
        Mode::InputText | Mode::Command | Mode::Search => translate_input(key),
    }
}

fn translate_normal(key: KeyEvent) -> Action {
    match key.code {
        KeyCode::Char('q') | KeyCode::Esc => Action::Quit,
        KeyCode::Up | KeyCode::Char('k') => Action::MoveUp,
        KeyCode::Down | KeyCode::Char('j') => Action::MoveDown,
        // Tab/Shift+Tab 循环切页：多数终端/SSH 不拦截，是 F1..F6 之外最可靠的切页途径。
        KeyCode::Tab => Action::NextPage,
        KeyCode::BackTab => Action::PrevPage,
        // ]/[ 也循环切页，照顾 Tab 被外层(tmux/复用器)占用的场景。
        KeyCode::Char(']') => Action::NextPage,
        KeyCode::Char('[') => Action::PrevPage,
        // 焦点在设备列表↔历史↔传输间切换（删历史/取消传输需要它），移到 h/l。
        KeyCode::Char('l') => Action::NextFocus,
        KeyCode::Char('h') => Action::PrevFocus,
        KeyCode::F(1) => Action::SwitchPage(Page::Discovery),
        KeyCode::F(2) => Action::SwitchPage(Page::Transfers),
        KeyCode::F(3) => Action::SwitchPage(Page::History),
        KeyCode::F(4) => Action::SwitchPage(Page::Trust),
        KeyCode::F(5) => Action::SwitchPage(Page::Clipboard),
        KeyCode::F(6) => Action::SwitchPage(Page::Settings),
        // 数字键 1..6 直达对应页：终端绝不拦截裸数字，是最稳的备用切页键。
        KeyCode::Char('1') => Action::SwitchPage(Page::Discovery),
        KeyCode::Char('2') => Action::SwitchPage(Page::Transfers),
        KeyCode::Char('3') => Action::SwitchPage(Page::History),
        KeyCode::Char('4') => Action::SwitchPage(Page::Trust),
        KeyCode::Char('5') => Action::SwitchPage(Page::Clipboard),
        KeyCode::Char('6') => Action::SwitchPage(Page::Settings),
        KeyCode::Enter | KeyCode::Char('i') => Action::EnterInputText,
        KeyCode::Char(':') => Action::EnterCommand,
        KeyCode::Char('/') => Action::EnterSearch,
        KeyCode::Char('?') => Action::OpenHelp,
        KeyCode::Char('p') => Action::DemoPairing,
        KeyCode::Char('o') => Action::DemoOffer,
        KeyCode::Char('d') => Action::DeleteSelected,
        KeyCode::Char('c') => Action::ClearHistory,
        KeyCode::Char('x') => Action::CancelTransfer,
        KeyCode::Char('R') => Action::RetryTransfer,
        _ => Action::None,
    }
}

fn translate_input(key: KeyEvent) -> Action {
    match key.code {
        KeyCode::Esc => Action::Cancel,
        KeyCode::Enter => Action::Submit,
        KeyCode::Backspace => Action::PopChar,
        KeyCode::Char(c)
            if !key.modifiers.contains(KeyModifiers::CONTROL)
                && !key.modifiers.contains(KeyModifiers::ALT) =>
        {
            Action::PushChar(c)
        }
        _ => Action::None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn key(c: KeyCode) -> KeyEvent {
        KeyEvent::new(c, KeyModifiers::NONE)
    }

    #[test]
    fn digit_keys_jump_to_pages_in_normal_mode() {
        // 裸数字键不会被任何终端拦截，是 F1..F6 之外最可靠的切页途径。
        for (ch, page) in [
            ('1', Page::Discovery),
            ('2', Page::Transfers),
            ('3', Page::History),
            ('4', Page::Trust),
            ('5', Page::Clipboard),
            ('6', Page::Settings),
        ] {
            match translate(Mode::Normal, key(KeyCode::Char(ch))) {
                Action::SwitchPage(p) => assert_eq!(p, page, "数字 {ch} 应切到 {page:?}"),
                other => panic!("数字 {ch} 期望 SwitchPage，实际 {other:?}"),
            }
        }
    }

    #[test]
    fn tab_and_brackets_cycle_pages() {
        assert!(matches!(translate(Mode::Normal, key(KeyCode::Tab)), Action::NextPage));
        assert!(matches!(translate(Mode::Normal, key(KeyCode::BackTab)), Action::PrevPage));
        assert!(matches!(translate(Mode::Normal, key(KeyCode::Char(']'))), Action::NextPage));
        assert!(matches!(translate(Mode::Normal, key(KeyCode::Char('['))), Action::PrevPage));
    }

    #[test]
    fn page_cycle_wraps_around() {
        assert_eq!(Page::Discovery.prev(), Page::Settings);
        assert_eq!(Page::Settings.next(), Page::Discovery);
        // 数字键 1..6 的顺序必须与循环顺序一致。
        assert_eq!(Page::Discovery.next(), Page::Transfers);
        assert_eq!(Page::Transfers.next(), Page::History);
    }

    #[test]
    fn arrows_and_jk_move_selection() {
        assert!(matches!(translate(Mode::Normal, key(KeyCode::Up)), Action::MoveUp));
        assert!(matches!(translate(Mode::Normal, key(KeyCode::Char('k'))), Action::MoveUp));
        assert!(matches!(translate(Mode::Normal, key(KeyCode::Down)), Action::MoveDown));
        assert!(matches!(translate(Mode::Normal, key(KeyCode::Char('j'))), Action::MoveDown));
    }

    #[test]
    fn f_keys_still_switch_pages() {
        // 回归保护：补了备用键后 F1..F6 不能丢。
        assert!(matches!(
            translate(Mode::Normal, key(KeyCode::F(1))),
            Action::SwitchPage(Page::Discovery)
        ));
        assert!(matches!(
            translate(Mode::Normal, key(KeyCode::F(6))),
            Action::SwitchPage(Page::Settings)
        ));
    }

    #[test]
    fn input_mode_swallows_navigation_as_text() {
        // 进入输入模式后数字/字母都当文本，切页键此时不应生效（符合预期）。
        assert!(matches!(
            translate(Mode::InputText, key(KeyCode::Char('2'))),
            Action::PushChar('2')
        ));
        // Esc 能从输入模式逃出（避免用户卡在「只能发文本」）。
        assert!(matches!(translate(Mode::InputText, key(KeyCode::Esc)), Action::Cancel));
    }
}
