#!/usr/bin/env bash
# C5 android 端屏录：用 adb screenrecord（最长 3min；C5 一轮通常 30-60s）。
#
# 用法：
#   bash tools/conformance/c5/record-android.sh round1
#   ... 在 android 设备上完成轮 1 操作
#   Ctrl+C 停止
#
# 注意：screenrecord 没法录系统 UI 旋转、不录音；够 C5 用。
set -euo pipefail

DIR="android/screenshots/conformance/C5-20260525"
mkdir -p "$DIR/raw"
LABEL="${1:?usage: record-android.sh <round1|round2|round3>}"
DEVICE_OUT="/sdcard/c5-$LABEL.mp4"
LOCAL_OUT="$DIR/raw/android-$LABEL.mp4"

if [[ -f "$LOCAL_OUT" ]]; then
    echo "✗ $LOCAL_OUT 已存在" >&2
    exit 1
fi

if ! adb get-state >/dev/null 2>&1; then
    echo "✗ 没检测到 adb 设备；先连真机或启 emulator" >&2
    exit 2
fi

echo "▶ 在 device 上录制 → $DEVICE_OUT"
echo "  Ctrl+C 停止；之后会自动 pull 到 $LOCAL_OUT"

trap 'echo "▶ stopping screenrecord..."; adb shell pkill -SIGINT screenrecord || true; sleep 2' INT
adb shell screenrecord --time-limit 180 "$DEVICE_OUT" || true
trap - INT

# 等 1s 让 device 写完
sleep 1
adb pull "$DEVICE_OUT" "$LOCAL_OUT"
adb shell rm "$DEVICE_OUT"
echo "✓ saved $LOCAL_OUT"
