//! 登录时启动（Linux XDG autostart）。
//!
//! 真正注册开机自启：写 / 删 `~/.config/autostart/meshdrop.desktop`。
//! 桌面环境登录时会扫描该目录并拉起其中的 .desktop。开关状态即"文件是否存在"，
//! 因此本身就是持久化的，无需另存配置。

use std::io;
use std::path::PathBuf;

const DESKTOP_FILE: &str = "meshdrop.desktop";

/// `~/.config/autostart/meshdrop.desktop` 的完整路径。
fn autostart_path() -> Option<PathBuf> {
    dirs::config_dir().map(|d| d.join("autostart").join(DESKTOP_FILE))
}

/// 当前是否已注册开机自启（autostart 目录里是否存在我们的 .desktop）。
pub fn is_enabled() -> bool {
    autostart_path().map(|p| p.exists()).unwrap_or(false)
}

/// 开 / 关开机自启。
/// - enable=true：写入 .desktop，Exec 指向当前可执行文件路径。
/// - enable=false：删除 .desktop（不存在视为成功）。
pub fn set_enabled(enable: bool) -> io::Result<()> {
    let Some(path) = autostart_path() else {
        return Err(io::Error::new(io::ErrorKind::NotFound, "no XDG config dir"));
    };
    if enable {
        if let Some(dir) = path.parent() {
            std::fs::create_dir_all(dir)?;
        }
        // Exec 用当前进程的可执行路径；拿不到则退化为命令名（依赖 PATH）。
        let exec = std::env::current_exe()
            .ok()
            .map(|p| p.display().to_string())
            .unwrap_or_else(|| "meshdrop".to_string());
        let content = format!(
            "[Desktop Entry]\n\
             Type=Application\n\
             Name=MeshDrop\n\
             Comment=MeshDrop LAN file sharing\n\
             Exec={exec}\n\
             X-GNOME-Autostart-enabled=true\n\
             Terminal=false\n"
        );
        std::fs::write(&path, content)?;
    } else {
        match std::fs::remove_file(&path) {
            Ok(()) => {}
            Err(e) if e.kind() == io::ErrorKind::NotFound => {}
            Err(e) => return Err(e),
        }
    }
    Ok(())
}
