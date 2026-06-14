#!/usr/bin/env bash
# 批量截图脚本：iPhone 17 Pro + iPad Pro 13-inch (M5)
# 用法：./_capture.sh

set -euo pipefail

PHONE=9264128B-FA3D-40EB-BDD7-5AB62831A239
PAD=41074A56-CF9B-468E-A47B-A0F23EFF5001
BUNDLE=com.welape.meshdrop
OUT="$(cd "$(dirname "$0")" && pwd)"

snap() {
    local device=$1 route=$2 mode=$3 name=$4
    xcrun simctl ui "$device" appearance "$mode" >/dev/null
    xcrun simctl terminate "$device" "$BUNDLE" 2>/dev/null || true
    sleep 0.6
    SIMCTL_CHILD_MESHDROP_PREVIEW_ROUTE="$route" \
        xcrun simctl launch "$device" "$BUNDLE" >/dev/null
    sleep 2.4
    xcrun simctl io "$device" screenshot "$OUT/$name.png" >/dev/null
    echo "  ✓ $name"
}

echo "==> iPhone 17 Pro (Light)"
snap $PHONE discover    light ios-phone-discovery-light
snap $PHONE chats       light ios-phone-chat-light
snap $PHONE transfers   light ios-phone-transfers-light
snap $PHONE me          light ios-phone-history-light    # entry from Me Tab
snap $PHONE history     light ios-phone-history-detail-light
snap $PHONE settings    light ios-phone-settings-light
snap $PHONE trust       light ios-phone-trust-light
snap $PHONE pairing     light ios-phone-pairing-light
snap $PHONE onboarding  light ios-phone-onboarding-light
snap $PHONE receive     light ios-phone-receive-light

echo "==> iPhone 17 Pro (Dark)"
snap $PHONE discover    dark ios-phone-discovery-dark
snap $PHONE chats       dark ios-phone-chat-dark
snap $PHONE transfers   dark ios-phone-transfers-dark
snap $PHONE me          dark ios-phone-history-dark
snap $PHONE history     dark ios-phone-history-detail-dark
snap $PHONE settings    dark ios-phone-settings-dark
snap $PHONE trust       dark ios-phone-trust-dark
snap $PHONE pairing     dark ios-phone-pairing-dark
snap $PHONE onboarding  dark ios-phone-onboarding-dark
snap $PHONE receive     dark ios-phone-receive-dark

echo "==> iPad Pro 13\" M5 (Light)"
snap $PAD discover    light ios-pad-split-light
snap $PAD chats       light ios-pad-chat-light
snap $PAD transfers   light ios-pad-transfers-light
snap $PAD history     light ios-pad-history-light
snap $PAD settings    light ios-pad-settings-light

echo "==> iPad Pro 13\" M5 (Dark)"
snap $PAD discover    dark ios-pad-split-dark
snap $PAD chats       dark ios-pad-chat-dark
snap $PAD transfers   dark ios-pad-transfers-dark
snap $PAD history     dark ios-pad-history-dark
snap $PAD settings    dark ios-pad-settings-dark

echo "==> Share Extension"
snap $PHONE share-ext light ios-share-ext-light
snap $PHONE share-ext dark  ios-share-ext-dark

echo "==> Live Activity"
snap $PHONE live-activity light ios-live-activity-lock
snap $PHONE live-activity dark  ios-live-activity-island

echo ""
echo "DONE."
