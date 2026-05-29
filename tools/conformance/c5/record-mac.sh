#!/usr/bin/env bash
# C5 mac 端屏录：调 macOS 内置 screencapture -v。
# 跑前 Ctrl+C 用来停止录制（screencapture 自身的 SIGINT 行为）。
#
# 用法：
#   bash tools/conformance/c5/record-mac.sh round1
#   ... 跑完轮 1 后 Ctrl+C
#   bash tools/conformance/c5/record-mac.sh round2
#   ...
# 三轮全部录完后，运行 concat-rounds.sh 拼成 recv.mp4
set -euo pipefail

DIR="apple/MeshDropMac/screenshots/conformance/C5-20260525"
mkdir -p "$DIR/raw"
LABEL="${1:?usage: record-mac.sh <round1|round2|round3>}"
OUT="$DIR/raw/mac-$LABEL.mov"

if [[ -f "$OUT" ]]; then
    echo "✗ $OUT 已存在；先 rm 或换 label" >&2
    exit 1
fi

echo "▶ 录制中 → $OUT"
echo "  Ctrl+C 停止"
# -v: video; -V <seconds> 也行；-x 静音
screencapture -v -x "$OUT"
echo "✓ saved $OUT"
