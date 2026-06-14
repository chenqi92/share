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
        KeyCode::Tab => Action::NextFocus,
        KeyCode::BackTab => Action::PrevFocus,
        KeyCode::F(1) => Action::SwitchPage(Page::Discovery),
        KeyCode::F(2) => Action::SwitchPage(Page::Transfers),
        KeyCode::F(3) => Action::SwitchPage(Page::History),
        KeyCode::F(4) => Action::SwitchPage(Page::Trust),
        KeyCode::F(5) => Action::SwitchPage(Page::Clipboard),
        KeyCode::F(6) => Action::SwitchPage(Page::Settings),
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
