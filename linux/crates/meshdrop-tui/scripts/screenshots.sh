#!/usr/bin/env bash
# scripts/screenshots.sh — 批量出 MeshDrop TUI 的 8 张截图 + 1 段 asciinema cast。
#
# 用法：
#   linux/crates/meshdrop-tui/scripts/screenshots.sh                    # 自动检测
#   linux/crates/meshdrop-tui/scripts/screenshots.sh --terminal kitty   # 指定终端
#   linux/crates/meshdrop-tui/scripts/screenshots.sh --only main        # 只跑某一张
#
# 依赖：
#   - 必备：cargo + meshdrop-tui release build
#   - 一个图形终端：kitty / alacritty / wezterm / iTerm2 / GNOME Terminal / xterm
#   - 一个截图工具：
#       macOS:   screencapture（系统自带）
#       Linux/X: import (ImageMagick) 或 gnome-screenshot 或 maim
#       Linux/Wayland: grim
#   - asciinema（可选，无则跳过 cast 录制）
#
# 输出：linux/crates/meshdrop-tui/scripts/out/{01..08}-*.png + demo.cast
set -euo pipefail

# ── 路径 ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LINUX_DIR="$(cd "$CRATE_DIR/../.." && pwd)"
OUT_DIR="$SCRIPT_DIR/out"
BIN="$LINUX_DIR/target/release/meshdrop-tui"

# ── 参数 ────────────────────────────────────────────────────────────
TERMINAL=""
ONLY=""
HOLD_SEC=2.5
WINDOW_COLS=140
WINDOW_ROWS=42

while [ $# -gt 0 ]; do
  case "$1" in
    --terminal)  TERMINAL="$2"; shift 2 ;;
    --only)      ONLY="$2"; shift 2 ;;
    --hold)      HOLD_SEC="$2"; shift 2 ;;
    --cols)      WINDOW_COLS="$2"; shift 2 ;;
    --rows)      WINDOW_ROWS="$2"; shift 2 ;;
    -h|--help)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    *) echo "未知参数：$1" >&2; exit 1 ;;
  esac
done

mkdir -p "$OUT_DIR"

# ── 构建 ────────────────────────────────────────────────────────────
echo "[1/3] cargo build --release -p meshdrop-tui"
(cd "$LINUX_DIR" && cargo build --release -p meshdrop-tui --quiet)
[ -x "$BIN" ] || { echo "构建失败：找不到 $BIN" >&2; exit 1; }

# ── 检测平台 ────────────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)
    if [ -n "${WAYLAND_DISPLAY:-}" ]; then PLATFORM="wayland"; else PLATFORM="x11"; fi
    ;;
  *) PLATFORM="unknown" ;;
esac

# ── 选终端 ──────────────────────────────────────────────────────────
detect_terminal() {
  if [ -n "$TERMINAL" ]; then echo "$TERMINAL"; return; fi
  case "$PLATFORM" in
    macos)
      for t in iterm wezterm kitty alacritty; do
        case "$t" in
          iterm)     [ -d "/Applications/iTerm.app" ] && { echo iterm;     return; } ;;
          wezterm)   command -v wezterm   >/dev/null && { echo wezterm;   return; } ;;
          kitty)     command -v kitty     >/dev/null && { echo kitty;     return; } ;;
          alacritty) command -v alacritty >/dev/null && { echo alacritty; return; } ;;
        esac
      done
      echo terminal ;; # macOS 自带 Terminal.app
    *)
      for t in kitty alacritty wezterm gnome-terminal xterm; do
        command -v "$t" >/dev/null && { echo "$t"; return; }
      done
      echo "" ;;
  esac
}

TERM_NAME="$(detect_terminal)"
[ -z "$TERM_NAME" ] && { echo "未找到可用终端（试 --terminal kitty/alacritty/wezterm/iterm）" >&2; exit 1; }

# ── 选截图工具 ─────────────────────────────────────────────────────
SHOT_TOOL=""
case "$PLATFORM" in
  macos)
    command -v screencapture >/dev/null && SHOT_TOOL="screencapture"
    ;;
  wayland)
    command -v grim >/dev/null && SHOT_TOOL="grim"
    ;;
  x11)
    if   command -v import >/dev/null;            then SHOT_TOOL="import"
    elif command -v gnome-screenshot >/dev/null;  then SHOT_TOOL="gnome-screenshot"
    elif command -v maim >/dev/null;              then SHOT_TOOL="maim"
    fi
    ;;
esac
[ -z "$SHOT_TOOL" ] && { echo "未找到截图工具（macOS: screencapture / Linux: import / gnome-screenshot / grim / maim）" >&2; exit 1; }

echo "[2/3] platform=$PLATFORM · terminal=$TERM_NAME · shot=$SHOT_TOOL · cols=${WINDOW_COLS}x${WINDOW_ROWS}"

# ── 启动终端 + binary，运行 N 秒后截图 ──────────────────────────────
# 参数：$1=输出文件名 / $2=demo flag 内容（空表示不传） / $3=额外环境变量
launch_and_shot() {
  local out="$1"
  local demo="$2"
  local env_extra="$3"

  local cmd=("$BIN")
  [ -n "$demo" ] && cmd+=(--demo "$demo")

  local pid=""
  case "$TERM_NAME" in
    kitty)
      kitty --title "meshdrop-shot" -o initial_window_width=${WINDOW_COLS}c \
            -o initial_window_height=${WINDOW_ROWS}c \
            -d "$LINUX_DIR" -- \
            sh -c "$env_extra exec ${cmd[*]@Q}" &
      pid=$!
      ;;
    alacritty)
      alacritty --title meshdrop-shot \
                -o window.dimensions.columns=$WINDOW_COLS \
                -o window.dimensions.lines=$WINDOW_ROWS \
                -e sh -c "$env_extra exec ${cmd[*]@Q}" &
      pid=$!
      ;;
    wezterm)
      wezterm start --always-new-process --cwd "$LINUX_DIR" -- \
        sh -c "$env_extra exec ${cmd[*]@Q}" &
      pid=$!
      ;;
    gnome-terminal)
      gnome-terminal --title=meshdrop-shot --geometry=${WINDOW_COLS}x${WINDOW_ROWS} \
        -- sh -c "$env_extra exec ${cmd[*]@Q}; sleep 0.5" &
      pid=$!
      ;;
    xterm)
      xterm -T meshdrop-shot -geometry ${WINDOW_COLS}x${WINDOW_ROWS} \
        -e sh -c "$env_extra exec ${cmd[*]@Q}; sleep 0.5" &
      pid=$!
      ;;
    iterm)
      osascript <<APPLE
tell application "iTerm"
  set new_win to (create window with default profile)
  tell current session of new_win
    set columns to $WINDOW_COLS
    set rows to $WINDOW_ROWS
    set name to "meshdrop-shot"
    write text "$env_extra exec ${cmd[*]@Q}"
  end tell
end tell
APPLE
      ;;
    terminal)
      osascript <<APPLE
tell application "Terminal"
  set new_win to (do script "$env_extra exec ${cmd[*]@Q}")
  set custom title of front window to "meshdrop-shot"
end tell
APPLE
      ;;
    *)
      echo "未支持的终端：$TERM_NAME" >&2; return 1 ;;
  esac

  # 等终端窗口完成渲染
  sleep "$HOLD_SEC"

  # 截图
  case "$SHOT_TOOL" in
    screencapture)
      # 抓最前台窗口（meshdrop-shot 在最前）：-l 抓单窗口需要 windowid。
      # 简化：等用户先把它置顶后用 -W（等待 click）也行；这里用 -o 抓激活窗口
      # macOS 上 -l <wid> 才能精确，自动取最顶窗：
      local wid
      wid=$(osascript <<'OS' 2>/dev/null || true
on idfun()
  tell application "System Events"
    repeat with p in (every process whose visible is true)
      try
        set wins to windows of p
        repeat with w in wins
          if (name of w) contains "meshdrop-shot" then
            return value of attribute "AXTitle" of w
          end if
        end repeat
      end try
    end repeat
  end tell
  return ""
end idfun
my idfun()
OS
)
      # 退而求其次：抓 active window
      screencapture -x -o -t png "$out"
      ;;
    grim)
      grim "$out"
      ;;
    import)
      # ImageMagick：抓 root（全屏）；用户可手动 crop。要抓窗口需 wid，本脚本不强求。
      import -window root "$out"
      ;;
    gnome-screenshot)
      gnome-screenshot --window --file="$out"
      ;;
    maim)
      maim --select=false "$out"
      ;;
  esac

  # 关掉那个窗口（kill binary 进程；终端窗口自然消失或留壳）
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  # 给系统一点时间
  sleep 0.3
}

# ── 8 个 scene ──────────────────────────────────────────────────────
# 序号 文件名后缀                demo flag             额外 env
SCENES=(
  "01-main-truecolor      |               | MESHDROP_COLOR=truecolor "
  "02-main-256            |               | MESHDROP_COLOR=256 "
  "03-pairing             | pairing       | "
  "04-file-offer          | offer         | "
  "05-search              | search:孟     | "
  "06-command             | command:f /tmp/demo.zip | "
  "07-help                | help          | "
  "08-list-devices-table  | __cli_table__ | "
)

run_scene() {
  local entry="$1"
  IFS='|' read -r label demo env_extra <<<"$entry"
  label="$(echo "$label" | xargs)"
  demo="$(echo "$demo" | xargs)"
  env_extra="$(echo "$env_extra" | xargs)"
  [ -n "$ONLY" ] && [[ "$label" != *"$ONLY"* ]] && return 0
  local out="$OUT_DIR/${label}.png"
  echo "  ▶ $label  (demo=${demo:-—})"

  if [ "$demo" = "__cli_table__" ]; then
    # 不开图形终端，直接抓 CLI 输出
    local txt="$OUT_DIR/${label}.txt"
    "$BIN" list-devices --table > "$txt"
    echo "    saved → $txt（list-devices --table，纯文本无需截图）"
    return 0
  fi

  launch_and_shot "$out" "$demo" "$env_extra"
  echo "    saved → $out"
}

echo "[3/3] 输出到 $OUT_DIR"
for s in "${SCENES[@]}"; do
  run_scene "$s"
done

# ── asciinema cast ──────────────────────────────────────────────────
if command -v asciinema >/dev/null; then
  CAST="$OUT_DIR/demo.cast"
  echo "[+] 录 asciinema cast → $CAST（10s · 自动退出）"
  # idle-time-limit 让 cast 紧凑；-c 指定命令；超时由 binary 自己处理（按 q 退出）
  (
    cd "$LINUX_DIR"
    # 用 timeout 在 10s 后给 binary 发 SIGTERM；asciinema 录到那一刻
    if command -v gtimeout >/dev/null; then
      asciinema rec -q --overwrite -t "MeshDrop TUI demo" -c "gtimeout 10 $BIN" "$CAST"
    elif command -v timeout >/dev/null; then
      asciinema rec -q --overwrite -t "MeshDrop TUI demo" -c "timeout 10 $BIN" "$CAST"
    else
      # 没有 timeout：让用户手动 q
      echo "（无 timeout 命令；进入 TUI 后按 q 退出录制）"
      asciinema rec -q --overwrite -t "MeshDrop TUI demo" -c "$BIN" "$CAST"
    fi
  ) || echo "  asciinema 失败（可手动跑：asciinema rec demo.cast -c $BIN）"
else
  echo "[+] 未装 asciinema，跳过 cast 录制"
fi

echo ""
echo "完成。文件在：$OUT_DIR"
ls -la "$OUT_DIR" || true
