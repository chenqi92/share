#!/usr/bin/env bash
set -euo pipefail

: "${MACOS_CERTIFICATE_P12:?Configure the Developer ID certificate secret}"
: "${MACOS_CERTIFICATE_PASSWORD:?Configure the P12 password secret}"
: "${MACOS_PROVISION_PROFILE:?Configure the Developer ID provisioning profile secret}"
: "${APPLE_NOTARY_KEY:?Configure the notarization API key secret}"
: "${APPLE_NOTARY_KEY_ID:?Configure the notarization API key ID}"
: "${APPLE_NOTARY_ISSUER_ID:?Configure the notarization issuer ID}"
umask 077
signing_dir="$RUNNER_TEMP/meshdrop-signing"
mkdir -p "$signing_dir" "$HOME/Library/MobileDevice/Provisioning Profiles"
printf '%s' "$MACOS_CERTIFICATE_P12" | base64 --decode > "$signing_dir/developer-id.p12"
printf '%s' "$MACOS_PROVISION_PROFILE" | base64 --decode > "$signing_dir/profile.provisionprofile"
printf '%s' "$APPLE_NOTARY_KEY" > "$signing_dir/notary.p8"
security cms -D -i "$signing_dir/profile.provisionprofile" > "$signing_dir/profile.plist"
profile_uuid=$(/usr/libexec/PlistBuddy -c 'Print UUID' "$signing_dir/profile.plist")
cp "$signing_dir/profile.provisionprofile" "$HOME/Library/MobileDevice/Provisioning Profiles/$profile_uuid.provisionprofile"
keychain_password=$(openssl rand -hex 24)
echo "::add-mask::$keychain_password"
keychain="$signing_dir/build.keychain-db"
security create-keychain -p "$keychain_password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$keychain_password" "$keychain"
security import "$signing_dir/developer-id.p12" -P "$MACOS_CERTIFICATE_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security -t cert -f pkcs12 -k "$keychain"
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "$keychain_password" "$keychain" > /dev/null
security list-keychains -d user -s "$keychain" "$HOME/Library/Keychains/login.keychain-db"
xcrun notarytool store-credentials meshdrop-release --key "$signing_dir/notary.p8" \
  --key-id "$APPLE_NOTARY_KEY_ID" --issuer "$APPLE_NOTARY_ISSUER_ID" --keychain "$keychain"
{
  echo "MACOS_PROFILE_UUID=$profile_uuid"
  echo 'MACOS_SIGN_IDENTITY=Developer ID Application'
  echo 'MACOS_NOTARY_PROFILE=meshdrop-release'
  echo "MACOS_SIGN_KEYCHAIN=$keychain"
} >> "$GITHUB_ENV"
