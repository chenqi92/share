#!/usr/bin/env bash
# MeshDrop Linux 安装脚本（TUI / headless）。
# 在目标机上跑：编译 release 二进制，装成 `meshdrop` 命令，可选注册 systemd 接收守护。
#
#   curl -fsSL <raw>/linux/install.sh | bash           # 仅装 meshdrop 命令
#   curl -fsSL <raw>/linux/install.sh | bash -s -- -d  # 同时装并启用后台接收守护
#
# 或在已 clone 的源码目录里：  bash linux/install.sh [-d]
set -euo pipefail

WITH_DAEMON=0
[[ "${1:-}" == "-d" || "${1:-}" == "--daemon" ]] && WITH_DAEMON=1

BIN_NAME=meshdrop
PREFIX=${PREFIX:-/usr/local/bin}
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

echo "[1/4] 检查 Rust 工具链 (需 >= 1.80)…"
if ! command -v cargo >/dev/null 2>&1 || ! cargo --version | awk '{print $2}' | awk -F. '{exit !($1>1 || ($1==1 && $2>=80))}'; then
  echo "  Rust 缺失或过旧，安装 rustup stable…"
  curl -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
  # shellcheck disable=SC1090
  source "$HOME/.cargo/env"
fi
echo "  rustc: $(rustc --version)"

echo "[2/4] 编译 meshdrop-tui (release)…"
( cd "$HERE" && cargo build --release -p meshdrop-tui )

echo "[3/4] 安装到 $PREFIX/$BIN_NAME …"
sudo_cmd=""; [[ -w "$PREFIX" ]] || sudo_cmd=sudo
$sudo_cmd install -m755 "$HERE/target/release/meshdrop-tui" "$PREFIX/$BIN_NAME"
# 兼容旧名
$sudo_cmd ln -sf "$PREFIX/$BIN_NAME" "$PREFIX/meshdrop-tui"
echo "  已安装：$(command -v $BIN_NAME)"

if [[ $WITH_DAEMON -eq 1 ]]; then
  echo "[4/4] 注册 systemd 后台接收守护 (meshdrop.service)…"
  $sudo_cmd tee /etc/systemd/system/meshdrop.service >/dev/null <<EOF
[Unit]
Description=MeshDrop LAN drop receive daemon
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=$PREFIX/$BIN_NAME daemon --auto-accept-trusted --log-file /var/log/meshdrop.log
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
  $sudo_cmd systemctl daemon-reload
  $sudo_cmd systemctl enable --now meshdrop
  echo "  守护已启用：systemctl status meshdrop"
else
  echo "[4/4] 跳过守护（加 -d 可启用）。"
fi

echo ""
echo "完成。用法："
echo "  meshdrop                 # 全屏交互式 TUI（先 systemctl stop meshdrop 避免抢端口）"
echo "  meshdrop list-devices    # 列出附近设备"
echo "  meshdrop send <id> 文本  # 发文本"
