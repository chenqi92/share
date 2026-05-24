#!/usr/bin/env bash
# 用 Chrome headless 把 4 张 mockup 渲染成 1800x1100 PNG。
#
# 由于本地没有装 visionOS Simulator runtime（且 CI 通常也没有），
# 这套 HTML mockup 用与 SwiftUI 同 token 的样式离线渲染 4 张截图。
# 实际 visionOS App 看 Sources/。

set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/../../screenshots"
mkdir -p "$OUT"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
if [[ ! -x "$CHROME" ]]; then
    echo "未找到 Chrome,请安装 Google Chrome." >&2
    exit 1
fi

render() {
    local html="$1"
    local out="$2"
    "$CHROME" \
        --headless=new \
        --hide-scrollbars \
        --disable-gpu \
        --window-size=1800,1100 \
        --default-background-color=00000000 \
        --screenshot="$OUT/$out" \
        --virtual-time-budget=600 \
        "file://$HERE/$html" 2>/dev/null
    echo "✓ $out"
}

render spatial-nearby.html visionos-spatial-nearby-passthrough.png
render receive-card.html   visionos-receive-card-passthrough.png
render transfers.html      visionos-transfers-passthrough.png
render pairing.html        visionos-pairing-passthrough.png

echo
ls -lh "$OUT"
