#!/usr/bin/env bash
# C5：把三轮 raw 屏录拼成 recv.mp4 / send.mp4，并把 send 副本拷到 mac 目录，反之亦然。
# 需要 ffmpeg。
set -euo pipefail

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "✗ 需要 ffmpeg；brew install ffmpeg" >&2
    exit 2
fi

MAC_DIR="apple/MeshDropMac/screenshots/conformance/C5-20260525"
AND_DIR="android/screenshots/conformance/C5-20260525"

concat() {
    local raw_glob="$1"
    local out="$2"
    local list
    list="$(mktemp)"
    for f in $raw_glob; do
        [[ -f "$f" ]] || continue
        echo "file '$(pwd)/$f'" >> "$list"
    done
    if [[ ! -s "$list" ]]; then
        echo "✗ 找不到 raw 段 ($raw_glob)" >&2
        rm "$list"
        return 1
    fi
    echo "▶ concat → $out"
    # 三段编码可能不同；重编码到 H.264 + AAC，统一容器
    ffmpeg -y -f concat -safe 0 -i "$list" -c:v libx264 -pix_fmt yuv420p -c:a aac -movflags +faststart "$out"
    rm "$list"
}

# mac 三段
concat "$MAC_DIR/raw/mac-round*.mov" "$MAC_DIR/recv.mp4"
# android 三段
concat "$AND_DIR/raw/android-round*.mp4" "$AND_DIR/send.mp4"

# 互拷副本（C5 要求 each dir 含 send + recv）
cp "$AND_DIR/send.mp4" "$MAC_DIR/send.mp4"
cp "$MAC_DIR/recv.mp4" "$AND_DIR/recv.mp4"

echo
echo "✓ done"
echo "  $MAC_DIR/{recv,send}.mp4"
echo "  $AND_DIR/{send,recv}.mp4"
