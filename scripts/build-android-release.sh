#!/usr/bin/env bash
set -euo pipefail

project=${1:?android or wearos}
tag=${2:?release tag}
[[ "$project" == android || "$project" == wearos ]]
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-(alpha|beta|rc)\.[0-9]+)?$ ]]
: "${ANDROID_KEYSTORE:?Set the path to the release keystore}"
: "${ANDROID_KEY_ALIAS:?Set the release key alias}"
: "${ANDROID_STORE_PASSWORD:?Set the keystore password}"
: "${ANDROID_KEY_PASSWORD:?Set the key password}"
repo_root=$(pwd)
sdk_root=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
tools_dir="$sdk_root/build-tools/35.0.0"
test -x "$tools_dir/apksigner"
out="$repo_root/release-assets"
mkdir -p "$out"
if [[ "$project" == android && ! -f "$project/key.properties" ]]; then
  python3 - <<'PY'
import os
from pathlib import Path
mapping = {'storeFile': 'ANDROID_KEYSTORE', 'storePassword': 'ANDROID_STORE_PASSWORD',
           'keyAlias': 'ANDROID_KEY_ALIAS', 'keyPassword': 'ANDROID_KEY_PASSWORD'}
def escape(value):
    return ''.join('\\u%04x' % ord(c) if ord(c) > 127 else
                   {'\\': '\\\\', '\n': '\\n', '\r': '\\r', '\t': '\\t', ' ': '\\ ', '=': '\\=', ':': '\\:'}.get(c, c)
                   for c in value)
path = Path('android/key.properties')
with path.open('x') as stream:
    os.chmod(path, 0o600)
    stream.write(''.join(f'{key}={escape(os.environ[value])}\n' for key, value in mapping.items()))
PY
  trap 'rm -f android/key.properties' EXIT
fi
(
  cd "$project"
  ./gradlew :app:assembleRelease :app:bundleRelease :app:testReleaseUnitTest --no-daemon
)
apk=$(find "$project/app/build/outputs/apk/release" -name '*.apk' -type f)
test -f "$apk"
destination="$out/MeshDrop-$tag-$project.apk"
"$tools_dir/zipalign" -f -P 16 4 "$apk" "$destination"
"$tools_dir/apksigner" sign --v4-signing-enabled false --ks "$ANDROID_KEYSTORE" --ks-key-alias "$ANDROID_KEY_ALIAS" \
  --ks-pass env:ANDROID_STORE_PASSWORD --key-pass env:ANDROID_KEY_PASSWORD "$destination"
"$tools_dir/apksigner" verify --verbose --print-certs "$destination"
"$tools_dir/zipalign" -c -P 16 4 "$destination"
cp "$project/app/build/outputs/bundle/release/app-release.aab" "$out/MeshDrop-$tag-$project.aab"
jarsigner -keystore "$ANDROID_KEYSTORE" -storepass:env ANDROID_STORE_PASSWORD \
  -keypass:env ANDROID_KEY_PASSWORD "$out/MeshDrop-$tag-$project.aab" "$ANDROID_KEY_ALIAS"
jarsigner -verify "$out/MeshDrop-$tag-$project.aab"
