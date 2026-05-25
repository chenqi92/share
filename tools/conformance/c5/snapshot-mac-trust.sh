#!/usr/bin/env bash
# C5 step 6 后：把 mac 当前 trusted 库快照存到 evidence 目录。
set -euo pipefail

OUT="${1:-apple/MeshDropMac/screenshots/conformance/C5-20260525/trust.json.snapshot}"
STORE="$HOME/Library/Application Support/MeshDrop/trust.json"

if [[ ! -f "$STORE" ]]; then
    echo "✗ trust.json 不存在；先跑「允许并记住」让 mac 写入" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUT")"
# 美化输出便于人工核对
python3 -m json.tool "$STORE" > "$OUT"
echo "✓ wrote snapshot → $OUT"
echo
echo "应包含 1 条记录：fingerprint + name + firstSeen + lastSeen"
