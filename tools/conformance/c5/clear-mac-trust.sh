#!/usr/bin/env bash
# C5 step 0：清空 mac trusted 库。
#
# 当前 v0.1 实装把 trusted store 落在
#   ~/Library/Application Support/MeshDrop/trust.json
# （详见 apple/Sources/MeshDropKit/TrustStore.swift::storeURL）
#
# v1.0 切到 Keychain 后此脚本失效，需改用 `security delete-generic-password`。
set -euo pipefail

STORE="$HOME/Library/Application Support/MeshDrop/trust.json"
BACKUP_DIR="$HOME/.meshdrop-c5-backups"
mkdir -p "$BACKUP_DIR"

if [[ -f "$STORE" ]]; then
    ts="$(date +%Y%m%d-%H%M%S)"
    cp "$STORE" "$BACKUP_DIR/trust-$ts.json"
    rm "$STORE"
    echo "✓ cleared $STORE (backup at $BACKUP_DIR/trust-$ts.json)"
else
    echo "✓ already empty: $STORE not present"
fi

echo
echo "下一步：先**完全退出**正在运行的 MeshDropMac.app，再重启它。"
echo "TrustStore.swift 把记录缓存在 actor 内存里，必须重启进程才能让"
echo "清空生效。"
