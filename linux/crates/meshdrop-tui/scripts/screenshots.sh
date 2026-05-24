#!/usr/bin/env bash
# scripts/screenshots.sh — 批量出 MeshDrop TUI 的 8 张截图 + 1 段 asciinema cast。
#
# 两种模式：
#   --mode snapshot  （默认）  binary 自带 `snapshot` 子命令把 scene 渲染成 SVG，
#                              再用 rsvg-convert 转 PNG。沙箱 / SSH / CI 友好，
#                              不需要图形终端。
#   --mode terminal              真打开一个图形终端跑 binary 然后系统截图。
#                                需要 macOS screencapture 或 Linux 截图工具。
#
# 用法：
#   linux/crates/meshdrop-tui/scripts/screenshots.sh                   # snapshot 模式
#   linux/crates/meshdrop-tui/scripts/screenshots.sh --mode terminal   # 真终端模式
#   linux/crates/meshdrop-tui/scripts/screenshots.sh --only main       # 只跑某一张
#
# 依赖：
#   snapshot 模式： rsvg-convert（macOS：brew install librsvg / Linux：apt install librsvg2-bin）
#   terminal 模式：图形终端 + 截图工具（macOS screencapture / Linux grim/import/gnome-screenshot/maim）
#   可选：asciinema（录 cast）
#
# 输出：linux/crates/meshdrop-tui/docs/screenshots/{01..08}-*.png + scripts/out/demo.cast
set -euo pipefail

# ── 路径 ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LINUX_DIR="$(cd "$CRATE_DIR/../.." && pwd)"
DOCS_DIR="$CRATE_DIR/docs/screenshots"
OUT_DIR="$SCRIPT_DIR/out"
BIN="$LINUX_DIR/target/release/meshdrop-tui"

# ── 参数 ────────────────────────────────────────────────────────────
MODE="snapshot"
TERMINAL=""
ONLY=""
HOLD_SEC=2.5
COLS=140
ROWS=42
ZOOM=2

while [ $# -gt 0 ]; do
  case "$1" in
    --mode)      MODE="$2"; shift 2 ;;
    --terminal)  TERMINAL="$2"; shift 2 ;;
    --only)      ONLY="$2"; shift 2 ;;
    --hold)      HOLD_SEC="$2"; shift 2 ;;
    --cols)      COLS="$2"; shift 2 ;;
    --rows)      ROWS="$2"; shift 2 ;;
    --zoom)      ZOOM="$2"; shift 2 ;;
    -h|--help)
      sed -n '1,30p' "$0"
      exit 0
      ;;
    *) echo "未知参数：$1" >&2; exit 1 ;;
  esac
done

mkdir -p "$DOCS_DIR" "$OUT_DIR"

# ── 构建 ────────────────────────────────────────────────────────────
echo "[1/3] cargo build --release -p meshdrop-tui"
(cd "$LINUX_DIR" && cargo build --release -p meshdrop-tui --quiet)
[ -x "$BIN" ] || { echo "构建失败：找不到 $BIN" >&2; exit 1; }

# ── 检测平台 / 工具 ─────────────────────────────────────────────────
OS="$(uname -s)"
case "$OS" in
  Darwin) PLATFORM="macos" ;;
  Linux)  if [ -n "${WAYLAND_DISPLAY:-}" ]; then PLATFORM="wayland"; else PLATFORM="x11"; fi ;;
  *)      PLATFORM="unknown" ;;
esac

# ── snapshot 模式：8 个 scene → SVG → PNG ───────────────────────────
# 字段： 序号-名 | --scene 值        | --color 值
SNAPSHOT_SCENES=(
  "01-main-truecolor    | discovery          | truecolor"
  "02-main-256          | discovery          | 256"
  "03-pairing           | pairing            | truecolor"
  "04-file-offer        | offer              | truecolor"
  "05-search            | search:孟          | truecolor"
  "06-command           | command:f /tmp/demo.zip | truecolor"
  "07-help              | help               | truecolor"
)

run_snapshot_scenes() {
  command -v rsvg-convert >/dev/null \
    || { echo "缺 rsvg-convert（macOS: brew install librsvg / Linux: apt install librsvg2-bin）" >&2; exit 1; }
  echo "[2/3] snapshot 模式 · ${COLS}x${ROWS} · zoom=${ZOOM}x"
  for entry in "${SNAPSHOT_SCENES[@]}"; do
    IFS='|' read -r label scene color <<<"$entry"
    label="$(echo "$label" | xargs)"
    scene="$(echo "$scene" | xargs)"
    color="$(echo "$color" | xargs)"
    [ -n "$ONLY" ] && [[ "$label" != *"$ONLY"* ]] && continue

    local svg="$OUT_DIR/${label}.svg"
    local png="$DOCS_DIR/${label}.png"
    echo "  ▶ $label  (scene=$scene · color=$color)"
    "$BIN" snapshot --scene "$scene" --out "$svg" \
      --cols "$COLS" --rows "$ROWS" --color "$color" --chars full
    rsvg-convert --zoom "$ZOOM" -o "$png" "$svg"
  done

  # 第 8 张：list-devices --table 终端输出
  if [ -z "$ONLY" ] || [[ "08-list-devices-table" == *"$ONLY"* ]]; then
    local label="08-list-devices-table"
    local txt="$OUT_DIR/${label}.txt"
    local svg="$OUT_DIR/${label}.svg"
    local png="$DOCS_DIR/${label}.png"
    echo "  ▶ $label  (CLI table)"
    "$BIN" list-devices --table > "$txt" 2>&1 || true
    cli_table_to_svg "$txt" > "$svg"
    rsvg-convert --zoom "$ZOOM" -o "$png" "$svg"
  fi
}

# 把 CLI table 输出包成 SVG（同 mono 字体 + 暗底）
cli_table_to_svg() {
  local file="$1"
  python3 - "$file" <<'PY'
import sys, html
path = sys.argv[1]
lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
# 字号 / cell metrics 与 snapshot.rs 一致
cw, ch, fs = 9.0, 18.0, 14.0
cols = max((len(l) for l in lines), default=80) + 4
rows = len(lines) + 4
W, H = cols * cw, rows * ch
print(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.0f}" height="{H:.0f}" '
      f'viewBox="0 0 {W:.0f} {H:.0f}" font-family="\'Geist Mono\',\'SF Mono\',\'Menlo\',monospace" font-size="{fs:.1f}">')
print(f'<rect width="{W:.0f}" height="{H:.0f}" fill="#0E0C09"/>')
# header 高亮
fg_default = "#E8E3D6"
fg_muted = "#88847B"
fg_lime = "#DDF94B"
for i, line in enumerate(lines):
    y = (i + 2) * ch + fs * 0.95
    color = fg_default
    weight = "400"
    if i == 0:
        color = fg_lime
        weight = "700"
    elif "──" in line:
        color = fg_muted
    elif "（mock" in line:
        color = fg_muted
    print(f'<text x="{cw*2:.1f}" y="{y:.1f}" fill="{color}" font-weight="{weight}" xml:space="preserve">{html.escape(line)}</text>')
print('</svg>')
PY
}

# ── terminal 模式（原版）：跑图形终端 + 系统截图 ────────────────────
detect_terminal() {
  if [ -n "$TERMINAL" ]; then echo "$TERMINAL"; return; fi
  case "$PLATFORM" in
    macos)
      [ -d "/Applications/iTerm.app" ] && { echo iterm; return; }
      for t in wezterm kitty alacritty; do command -v "$t" >/dev/null && { echo "$t"; return; }; done
      echo terminal ;;
    *)
      for t in kitty alacritty wezterm gnome-terminal xterm; do
        command -v "$t" >/dev/null && { echo "$t"; return; }
      done
      echo "" ;;
  esac
}
SHOT_TOOL=""
detect_shot_tool() {
  case "$PLATFORM" in
    macos)   command -v screencapture >/dev/null && SHOT_TOOL="screencapture" ;;
    wayland) command -v grim >/dev/null && SHOT_TOOL="grim" ;;
    x11)
      if command -v import >/dev/null;            then SHOT_TOOL="import"
      elif command -v gnome-screenshot >/dev/null;  then SHOT_TOOL="gnome-screenshot"
      elif command -v maim >/dev/null;              then SHOT_TOOL="maim"
      fi ;;
  esac
}

launch_and_shot() {
  local out="$1" demo="$2" env_extra="$3"
  local cmd=("$BIN")
  [ -n "$demo" ] && cmd+=(--demo "$demo")
  local pid=""
  case "$TERM_NAME" in
    kitty)
      kitty --title "meshdrop-shot" -o initial_window_width=${COLS}c \
            -o initial_window_height=${ROWS}c \
            -d "$LINUX_DIR" -- sh -c "$env_extra exec ${cmd[*]@Q}" &
      pid=$!
      ;;
    alacritty)
      alacritty --title meshdrop-shot \
                -o window.dimensions.columns=$COLS \
                -o window.dimensions.lines=$ROWS \
                -e sh -c "$env_extra exec ${cmd[*]@Q}" &
      pid=$!
      ;;
    wezterm)
      wezterm start --always-new-process --cwd "$LINUX_DIR" -- \
        sh -c "$env_extra exec ${cmd[*]@Q}" &
      pid=$!
      ;;
    gnome-terminal)
      gnome-terminal --title=meshdrop-shot --geometry=${COLS}x${ROWS} \
        -- sh -c "$env_extra exec ${cmd[*]@Q}; sleep 0.5" &
      pid=$!
      ;;
    xterm)
      xterm -T meshdrop-shot -geometry ${COLS}x${ROWS} \
        -e sh -c "$env_extra exec ${cmd[*]@Q}; sleep 0.5" &
      pid=$!
      ;;
    iterm|terminal)
      local app=iTerm; [ "$TERM_NAME" = "terminal" ] && app=Terminal
      osascript <<APPLE
tell application "$app"
  do script "$env_extra exec ${cmd[*]@Q}"
end tell
APPLE
      ;;
    *) echo "未支持的终端：$TERM_NAME" >&2; return 1 ;;
  esac
  sleep "$HOLD_SEC"
  case "$SHOT_TOOL" in
    screencapture) screencapture -x -o -t png "$out" ;;
    grim)          grim "$out" ;;
    import)        import -window root "$out" ;;
    gnome-screenshot) gnome-screenshot --window --file="$out" ;;
    maim)          maim --select=false "$out" ;;
  esac
  [ -n "$pid" ] && { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
  sleep 0.3
}

run_terminal_mode() {
  TERM_NAME="$(detect_terminal)"
  detect_shot_tool
  [ -z "$TERM_NAME" ] && { echo "找不到图形终端，加 --terminal kitty/alacritty/..." >&2; exit 1; }
  [ -z "$SHOT_TOOL" ] && { echo "找不到截图工具" >&2; exit 1; }
  echo "[2/3] terminal 模式 · $TERM_NAME · $SHOT_TOOL"

  local SCENES=(
    "01-main-truecolor    |                            | MESHDROP_COLOR=truecolor"
    "02-main-256          |                            | MESHDROP_COLOR=256"
    "03-pairing           | pairing                    | "
    "04-file-offer        | offer                      | "
    "05-search            | search:孟                  | "
    "06-command           | command:f /tmp/demo.zip    | "
    "07-help              | help                       | "
  )
  for entry in "${SCENES[@]}"; do
    IFS='|' read -r label demo env_extra <<<"$entry"
    label="$(echo "$label" | xargs)"
    demo="$(echo "$demo" | xargs)"
    env_extra="$(echo "$env_extra" | xargs)"
    [ -n "$ONLY" ] && [[ "$label" != *"$ONLY"* ]] && continue
    local out="$DOCS_DIR/${label}.png"
    echo "  ▶ $label  (demo=${demo:-—})"
    launch_and_shot "$out" "$demo" "$env_extra"
  done

  # 第 8 张：CLI 表输出（不开终端，直接捕获到 .txt）
  "$BIN" list-devices --table > "$DOCS_DIR/08-list-devices-table.txt"
}

# ── 主分发 ──────────────────────────────────────────────────────────
case "$MODE" in
  snapshot) run_snapshot_scenes ;;
  terminal) run_terminal_mode ;;
  *) echo "未知 --mode：$MODE（取值 snapshot / terminal）" >&2; exit 1 ;;
esac

# ── asciinema cast ──────────────────────────────────────────────────
if command -v asciinema >/dev/null; then
  CAST="$OUT_DIR/demo.cast"
  echo "[+] 录 asciinema cast → $CAST（10s）"
  (
    cd "$LINUX_DIR"
    if command -v gtimeout >/dev/null; then
      asciinema rec -q --overwrite -t "MeshDrop TUI demo" -c "gtimeout 10 $BIN" "$CAST"
    elif command -v timeout >/dev/null; then
      asciinema rec -q --overwrite -t "MeshDrop TUI demo" -c "timeout 10 $BIN" "$CAST"
    else
      echo "（无 timeout 命令；进入 TUI 后按 q 退出）"
      asciinema rec -q --overwrite -t "MeshDrop TUI demo" -c "$BIN" "$CAST"
    fi
  ) || echo "  asciinema 失败（可手动跑：asciinema rec demo.cast -c $BIN）"
else
  echo "[+] 未装 asciinema，跳过 cast 录制"
fi

echo ""
echo "[3/3] 完成。截图：$DOCS_DIR"
ls -la "$DOCS_DIR" 2>/dev/null || true
