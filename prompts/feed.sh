#!/usr/bin/env bash
# MeshDrop · Prompt 拼接脚本
#
# 用法：
#   ./feed.sh <platform>             → UI 轮：COMMON + 端 prompt + TESTING
#   ./feed.sh backend-<platform>     → backend 轮：B-COMMON + companion-bridges + B-prompt + B-TESTING
#   ./feed.sh                        → 列可用 platform
#   ./feed.sh -h | --help            → 帮助

set -euo pipefail
cd "$(dirname "$0")"

usage() {
  cat <<EOF
MeshDrop Prompt 拼接 · 用法

  ./feed.sh <platform>
  ./feed.sh backend-<platform>

UI 轮可用 platform:
  macos          → 01-macos.md
  ios            → 02-ios-ipados.md
  android        → 03-android.md
  windows        → 04-windows.md
  linux-gui      → 05-linux-gui.md
  linux-tui      → 06-linux-tui.md
  tvos           → 07-tvos.md
  visionos       → 08-visionos.md
  watch          → 09-watch.md
  web            → 10-web.md

Backend 接入轮：
  backend-macos       → B01-macos.md
  backend-ios         → B02-ios.md
  backend-android     → B03-android.md
  backend-windows     → B04-windows.md
  backend-linux-gui   → B05-linux-gui.md
  backend-linux-tui   → B06-linux-tui.md
  backend-tvos        → B07-tvos.md
  backend-visionos    → B08-visionos.md
  backend-watch       → B09-watch.md
  backend-wearos      → B10-wearos.md
  backend-web         → B11-web.md

例:
  ./feed.sh macos | pbcopy
  ./feed.sh backend-ios > /tmp/p.md
EOF
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

mode="ui"
plat="$1"

if [[ "$plat" == backend-* ]]; then
  mode="backend"
  plat="${plat#backend-}"
fi

if [[ "$mode" == "ui" ]]; then
  case "$plat" in
    macos)      file="01-macos.md" ;;
    ios)        file="02-ios-ipados.md" ;;
    android)    file="03-android.md" ;;
    windows)    file="04-windows.md" ;;
    linux-gui)  file="05-linux-gui.md" ;;
    linux-tui)  file="06-linux-tui.md" ;;
    tvos)       file="07-tvos.md" ;;
    visionos)   file="08-visionos.md" ;;
    watch)      file="09-watch.md" ;;
    web)        file="10-web.md" ;;
    *)
      echo "未知 UI platform: $plat" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
else
  case "$plat" in
    macos)      file="B01-macos.md" ;;
    ios)        file="B02-ios.md" ;;
    android)    file="B03-android.md" ;;
    windows)    file="B04-windows.md" ;;
    linux-gui)  file="B05-linux-gui.md" ;;
    linux-tui)  file="B06-linux-tui.md" ;;
    tvos)       file="B07-tvos.md" ;;
    visionos)   file="B08-visionos.md" ;;
    watch)      file="B09-watch.md" ;;
    wearos)     file="B10-wearos.md" ;;
    web)        file="B11-web.md" ;;
    *)
      echo "未知 backend platform: $plat" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
fi

if [[ ! -f "$file" ]]; then
  echo "找不到 $file" >&2
  exit 2
fi

if [[ "$mode" == "ui" ]]; then
  cat <<HEADER
# MeshDrop · $plat 端 UI 完整开发 Prompt（自动拼接）

> 这份 prompt 由 prompts/feed.sh 拼接 COMMON.md + $file + TESTING_AND_ACCEPTANCE.md 生成。
> 复制整段给 AI，它将拥有从零做出 $plat 端 UI 的全部信息。

---

HEADER
  cat COMMON.md
  echo
  echo
  cat "$file"
  echo
  echo
  cat TESTING_AND_ACCEPTANCE.md
else
  cat <<HEADER
# MeshDrop · $plat 端 Backend 接入完整 Prompt（自动拼接）

> 这份 prompt 由 prompts/feed.sh 拼接生成：
>   B-COMMON.md + ../protocol/companion-bridges.md + $file + B-TESTING.md
> 复制整段给 AI，它将拥有把 $plat 端 UI 接入真实 backend 的全部信息。

---

HEADER
  cat B-COMMON.md
  echo
  echo
  echo "---"
  echo
  echo "# 附录：Companion 桥接协议（protocol/companion-bridges.md）"
  echo
  cat ../protocol/companion-bridges.md
  echo
  echo
  echo "---"
  echo
  cat "$file"
  echo
  echo
  cat B-TESTING.md
fi
