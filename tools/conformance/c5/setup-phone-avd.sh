#!/usr/bin/env bash
# C5 helper: 创建一个 phone AVD（Pixel 7, android-33, x86_64 image with Google APIs）
# 给 C5 / C2 这类 android → mac 跨端 conformance 用。
#
# 用法：
#   bash tools/conformance/c5/setup-phone-avd.sh [AVD_NAME]
# 默认 AVD_NAME=meshdrop-phone
set -euo pipefail

ANDROID_SDK="${ANDROID_SDK_ROOT:-/opt/homebrew/share/android-commandlinetools}"
SDK_MGR="$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"
AVD_MGR="$ANDROID_SDK/cmdline-tools/latest/bin/avdmanager"
EMU="$ANDROID_SDK/emulator/emulator"
AVD_NAME="${1:-meshdrop-phone}"
API=33
ABI=x86_64
IMG="system-images;android-${API};google_apis;${ABI}"

if [[ ! -x "$SDK_MGR" ]]; then
    echo "✗ sdkmanager not found at $SDK_MGR — adjust ANDROID_SDK_ROOT" >&2
    exit 2
fi

echo "▶ ensuring system image: $IMG"
yes | "$SDK_MGR" --licenses >/dev/null 2>&1 || true
"$SDK_MGR" --install "$IMG" "platform-tools" "emulator"

if "$AVD_MGR" list avd | grep -q "Name: $AVD_NAME\$"; then
    echo "✓ AVD $AVD_NAME already exists"
else
    echo "▶ creating AVD $AVD_NAME"
    echo no | "$AVD_MGR" create avd \
        --name "$AVD_NAME" \
        --package "$IMG" \
        --device "pixel_7"
fi

cat <<EOF

──────────────────────────────────────────
✓ AVD ready: $AVD_NAME
启动（关键：-dns-server 用宿主 DNS；不加 -no-window 以便看到 UI）：
  "$EMU" -avd $AVD_NAME -dns-server 8.8.8.8,1.1.1.1

⚠ 关于 mDNS：Android emulator 默认 NAT 网络不直接转发 host mDNS。
  C5 测试如果走 emulator，可能看不到 mac 设备。两个候选方案：
  1) 用真机 + USB tether 或同一 Wi-Fi（最稳）
  2) emulator 启动加 -net-tap（macOS 上需特殊权限），或在 mac 上用
     dns-sd 验证 emulator 端 mDNS 广告是否可见

  本 conformance run 推荐用真机。
──────────────────────────────────────────
EOF
