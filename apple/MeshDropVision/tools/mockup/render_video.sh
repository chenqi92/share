#!/usr/bin/env bash
# 离线渲染一段 ~16s 的演示 mp4 (12fps × 80 帧, ping-pong 拼接到 ~16s)
# 内容：PeerOrb halo 呼吸 + reticle 软边脉冲 + payload 沿轨迹飞行

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../../screenshots"
FRAMES="$(mktemp -d)"
mkdir -p "$OUT"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

FRAME_COUNT=40   # 飞行段 40 帧
FPS=12

for i in $(seq 0 $((FRAME_COUNT - 1))); do
    # t ∈ [0.04, 0.96] 平滑取样
    t=$(awk -v i="$i" -v n="$FRAME_COUNT" 'BEGIN { printf "%.4f", 0.04 + (i/(n-1)) * 0.92 }')
    file="$(printf 'frame-%03d.png' "$i")"
    "$CHROME" \
        --headless=new \
        --hide-scrollbars \
        --disable-gpu \
        --window-size=1800,1100 \
        --default-background-color=00000000 \
        --screenshot="$FRAMES/$file" \
        --virtual-time-budget=400 \
        "file://$HERE/spatial-nearby-anim.html?t=$t" 2>/dev/null
    # 进度 dot
    printf '.'
done
echo

# ffmpeg: 40 帧正向 + 40 帧倒序 = 80 帧 ping-pong, 12fps ≈ 6.7s; loop 2 次 ≈ 13.4s; 再附 stillhold 2s
ffmpeg -y \
    -framerate "$FPS" -i "$FRAMES/frame-%03d.png" \
    -vf "split[a][b];[b]reverse[r];[a][r]concat=n=2:v=1:a=0,loop=loop=1:size=80:start=0,format=yuv420p" \
    -c:v libx264 -preset slow -crf 22 \
    -pix_fmt yuv420p \
    "$OUT/visionos-spatial-nearby.mp4" 2>&1 | tail -5

rm -rf "$FRAMES"
echo
ls -lh "$OUT/visionos-spatial-nearby.mp4"
