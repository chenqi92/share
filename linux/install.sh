#!/usr/bin/env bash
# MeshDrop Linux 安装脚本。
# 在目标机上跑：编译 release 二进制并安装：
#   - GUI 二进制装成 `meshdrop`     （crate meshdrop-gui · bin meshdrop · GTK4/libadwaita）
#   - TUI 二进制装成 `meshdrop-tui` （crate meshdrop-tui · ratatui · 零系统依赖 · 提供 daemon 子命令）
# 可选注册 systemd 接收守护（守护跑 TUI 二进制的 `daemon` 子命令）。
#
#   curl -fsSL <raw>/linux/install.sh | bash           # 装 meshdrop + meshdrop-tui
#   curl -fsSL <raw>/linux/install.sh | bash -s -- -d  # 同时启用后台接收守护
#   TUI_ONLY=1 bash linux/install.sh                   # 无 GTK4 时只装 TUI（不装 GUI / 不装 .desktop）
#
# 或在已 clone 的源码目录里：  bash linux/install.sh [-d]
set -euo pipefail

WITH_DAEMON=0
[[ "${1:-}" == "-d" || "${1:-}" == "--daemon" ]] && WITH_DAEMON=1

GUI_BIN=meshdrop          # crate meshdrop-gui 产出的二进制名（meshdrop-gui/Cargo.toml [[bin]] name = "meshdrop"）
TUI_BIN=meshdrop-tui      # crate meshdrop-tui 产出的二进制名，提供 daemon 子命令
PREFIX=${PREFIX:-/usr/local/bin}
DATADIR=${DATADIR:-/usr/local/share}
TUI_ONLY=${TUI_ONLY:-0}   # =1 跳过 GUI（无 GTK4 开发/服务器场景）
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

sudo_cmd=""; [[ -w "$PREFIX" ]] || sudo_cmd=sudo

echo "[1/5] 检查 Rust 工具链 (需 >= 1.80)…"
if ! command -v cargo >/dev/null 2>&1 || ! cargo --version | awk '{print $2}' | awk -F. '{exit !($1>1 || ($1==1 && $2>=80))}'; then
  echo "  Rust 缺失或过旧，安装 rustup stable…"
  curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
fi
echo "  rustc: $(rustc --version)"

# ── 决定是否编 GUI（GUI 需要 GTK4 / libadwaita 的开发库）──────────────
BUILD_GUI=1
if [[ "$TUI_ONLY" == "1" ]]; then
  BUILD_GUI=0
  echo "  TUI_ONLY=1 → 跳过 GUI，只装 TUI。"
elif ! command -v pkg-config >/dev/null 2>&1 \
  || ! pkg-config --exists gtk4 libadwaita-1 2>/dev/null; then
  BUILD_GUI=0
  echo "  未检测到 GTK4 / libadwaita 开发库 → 跳过 GUI（仅装 TUI）。"
  echo "  如需 GUI，请先安装系统依赖后重跑（详见 linux/README.md）："
  echo "    Ubuntu: sudo apt install libgtk-4-dev libadwaita-1-dev"
  echo "    Fedora: sudo dnf install gtk4-devel libadwaita-devel"
  echo "    Arch:   sudo pacman -S gtk4 libadwaita"
fi

echo "[2/5] 编译 release 二进制…"
if [[ $BUILD_GUI -eq 1 ]]; then
  echo "  编译 meshdrop-gui + meshdrop-tui…"
  # GUI 链接 GTK4，缺依赖时可能编译失败；失败则降级为仅 TUI，保证 daemon 路径可用。
  if ( cd "$HERE" && cargo build --release -p meshdrop-gui -p meshdrop-tui ); then
    :
  else
    echo "  GUI 编译失败（多半缺 GTK4/libadwaita）→ 降级仅编 TUI。"
    BUILD_GUI=0
    ( cd "$HERE" && cargo build --release -p meshdrop-tui )
  fi
else
  echo "  编译 meshdrop-tui…"
  ( cd "$HERE" && cargo build --release -p meshdrop-tui )
fi

echo "[3/5] 安装 TUI 到 $PREFIX/$TUI_BIN …"
$sudo_cmd install -Dm755 "$HERE/target/release/$TUI_BIN" "$PREFIX/$TUI_BIN"
echo "  已安装：$(command -v $TUI_BIN)"

if [[ $BUILD_GUI -eq 1 ]]; then
  echo "[4/5] 安装 GUI 到 $PREFIX/$GUI_BIN + 桌面集成…"
  $sudo_cmd install -Dm755 "$HERE/target/release/$GUI_BIN" "$PREFIX/$GUI_BIN"
  # .desktop（Exec=meshdrop → GUI 二进制）
  if [[ -f "$HERE/data/meshdrop.desktop" ]]; then
    $sudo_cmd install -Dm644 "$HERE/data/meshdrop.desktop" \
      "$DATADIR/applications/meshdrop.desktop"
  fi
  # 图标
  for size in 48 64 128 256 512; do
    icon="$HERE/data/icons/hicolor/${size}x${size}/apps/com.welape.meshdrop.linux.png"
    [[ -f "$icon" ]] && $sudo_cmd install -Dm644 "$icon" \
      "/usr/share/icons/hicolor/${size}x${size}/apps/com.welape.meshdrop.linux.png"
  done
  command -v gtk-update-icon-cache >/dev/null 2>&1 \
    && $sudo_cmd gtk-update-icon-cache /usr/share/icons/hicolor >/dev/null 2>&1 || true
  echo "  已安装：$(command -v $GUI_BIN)（.desktop Exec=meshdrop 指向 GUI）"
else
  echo "[4/5] 跳过 GUI 安装（未编 GUI）。.desktop 不安装以免 Exec=meshdrop 指向不存在的命令。"
fi

if [[ $WITH_DAEMON -eq 1 ]]; then
  echo "[5/5] 注册 systemd 后台接收守护 (meshdrop.service)…"
  # 守护用 TUI 二进制：daemon 子命令仅在 meshdrop-tui 里实现（GUI 二进制无此子命令）。
  $sudo_cmd tee /etc/systemd/system/meshdrop.service >/dev/null <<EOF
[Unit]
Description=MeshDrop LAN drop receive daemon
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$PREFIX/$TUI_BIN daemon --auto-accept-trusted --log-file /var/log/meshdrop.log
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  $sudo_cmd systemctl daemon-reload
  $sudo_cmd systemctl enable --now meshdrop
  echo "  守护已启用：systemctl status meshdrop"
else
  echo "[5/5] 跳过守护（加 -d 可启用）。"
fi

echo ""
echo "完成。用法："
if [[ $BUILD_GUI -eq 1 ]]; then
  echo "  meshdrop                     # GTK4 GUI（也可从应用菜单 MeshDrop 启动）"
fi
echo "  meshdrop-tui                 # 全屏交互式 TUI（先 systemctl stop meshdrop 避免抢端口）"
echo "  meshdrop-tui list-devices    # 列出附近设备"
echo "  meshdrop-tui send <id> 文本  # 发文本"
