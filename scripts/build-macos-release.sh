#!/usr/bin/env bash
set -euo pipefail
tag=${1:?release tag}
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?$ ]]
: "${MACOS_SIGN_IDENTITY:?Set the Developer ID identity}"
: "${MACOS_PROFILE_UUID:?Set the Developer ID profile UUID}"
: "${MACOS_NOTARY_PROFILE:?Set the notarytool keychain profile}"
root=$(pwd)
derived="$root/build/release-macos"
mkdir -p release-assets
xcodegen generate --spec apple/MeshDropMac/project.yml
xcodebuild -project apple/MeshDropMac/MeshDropMac.xcodeproj -scheme MeshDropMac \
  -configuration Release -destination 'generic/platform=macOS' -derivedDataPath "$derived" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
app="$derived/Build/Products/Release/MeshDrop.app"
profile="$HOME/Library/MobileDevice/Provisioning Profiles/$MACOS_PROFILE_UUID.provisionprofile"
security cms -D -i "$profile" > "$derived/profile.plist"
python3 - "$derived/profile.plist" "$derived/entitlements.plist" <<'PY'
import plistlib, sys
from pathlib import Path
profile = plistlib.loads(Path(sys.argv[1]).read_bytes())
team = profile['TeamIdentifier'][0]
identifier = team + '.com.welape.landrop'
if profile['Entitlements'].get('com.apple.application-identifier') != identifier:
    raise SystemExit('Developer ID profile does not match the MeshDrop application')
source = Path('apple/MeshDropMac/MeshDrop.entitlements').read_text()
entitlements = plistlib.loads(source.replace('$(AppIdentifierPrefix)', team + '.').encode())
entitlements['com.apple.application-identifier'] = identifier
entitlements['com.apple.developer.team-identifier'] = team
Path(sys.argv[2]).write_bytes(plistlib.dumps(entitlements))
PY
cp "$profile" "$app/Contents/embedded.provisionprofile"
while IFS= read -r -d '' bundle; do
  codesign --force --timestamp --sign "$MACOS_SIGN_IDENTITY" "$bundle"
done < <(find "$app/Contents" -depth -name '*.bundle' -type d -print0)
codesign --force --timestamp --options runtime --sign "$MACOS_SIGN_IDENTITY" \
  --entitlements "$derived/entitlements.plist" "$app"
lipo -verify_arch arm64 x86_64 "$app/Contents/MacOS/MeshDrop"
codesign --verify --deep --strict "$app"
archive="$root/release-assets/MeshDrop-$tag-macos-universal.zip"
ditto -c -k --keepParent "$app" "$archive"
keychain_args=()
if [[ -n "${MACOS_SIGN_KEYCHAIN:-}" ]]; then
  keychain_args=(--keychain "$MACOS_SIGN_KEYCHAIN")
fi
xcrun notarytool submit "$archive" --keychain-profile "$MACOS_NOTARY_PROFILE" "${keychain_args[@]}" --wait --timeout 15m
xcrun stapler staple "$app"
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --keepParent "$app" "$archive"
