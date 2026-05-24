#!/usr/bin/env bash
# MeshDrop · Prompt 拼接脚本
#
# 用法：
#   ./feed.sh <platform>      → 输出 COMMON.md + 端 prompt + TESTING 拼好的完整 prompt
#   ./feed.sh                 → 列可用 platform
#   ./feed.sh -h | --help     → 帮助
#
# 例：
#   ./feed.sh macos | pbcopy
#   ./feed.sh ios > /tmp/p.md

set -euo pipefail
cd "$(dirname "$0")"

usage() {
  cat <<EOF
MeshDrop Prompt 拼接 · 用法

  ./feed.sh <platform>

可用 platform:
  macos          → 01-macos.md
  ios            → 02-ios-ipados.md
  android        → 03-android.md
  windows        → 04-windows.md
  linux-gui      → 05-linux-gui.md
  linux-tui      → 06-linux-tui.md

例:
  ./feed.sh macos | pbcopy
  ./feed.sh android > /tmp/android-prompt.md
EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

case "$1" in
  macos)      file="01-macos.md" ;;
  ios)        file="02-ios-ipados.md" ;;
  android)    file="03-android.md" ;;
  windows)    file="04-windows.md" ;;
  linux-gui)  file="05-linux-gui.md" ;;
  linux-tui)  file="06-linux-tui.md" ;;
  *)
    echo "未知 platform: $1" >&2
    echo >&2
    usage >&2
    exit 1
    ;;
esac

if [[ ! -f "$file" ]]; then
  echo "找不到 $file" >&2
  exit 2
fi

# 拼接：COMMON + 端 + TESTING
cat <<HEADER
# MeshDrop · $1 端 UI 完整开发 Prompt（自动拼接）

> 这份 prompt 由 prompts/feed.sh 拼接 COMMON.md + $file + TESTING_AND_ACCEPTANCE.md 生成。
> 复制整段给 AI，它将拥有从零做出 $1 端 UI 的全部信息。

---

HEADER

cat COMMON.md
echo
echo
cat "$file"
echo
echo
cat TESTING_AND_ACCEPTANCE.md
