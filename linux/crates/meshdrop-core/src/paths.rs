//! 统一的状态目录常量。身份 / 信任库 / 自动接收 / 上传等都落在同一个
//! `<XDG_DATA_HOME>/MeshDrop` 目录下，避免清理 / 迁移时遗漏散落子目录。
//!
//! 历史上信任库曾写在小写 `meshdrop`，本模块在解析时一并迁移遗留目录里的
//! `trust.json` 到统一目录。

use std::path::PathBuf;

/// 统一状态目录名（与 identity 的存储目录一致）。
pub const STATE_DIR_NAME: &str = "MeshDrop";
/// 早期信任库使用过的小写遗留目录名。
pub const LEGACY_STATE_DIR_NAME: &str = "meshdrop";

/// `<XDG_DATA_HOME>/MeshDrop` —— 统一状态根目录。
pub fn state_dir() -> Option<PathBuf> {
    dirs::data_local_dir().map(|d| d.join(STATE_DIR_NAME))
}

/// 旧的小写状态目录（仅用于一次性迁移）。
pub fn legacy_state_dir() -> Option<PathBuf> {
    dirs::data_local_dir().map(|d| d.join(LEGACY_STATE_DIR_NAME))
}
