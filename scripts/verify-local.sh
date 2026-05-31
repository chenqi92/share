#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run() {
  local name="$1"
  shift
  echo
  echo "==> ${name}"
  (cd "$ROOT" && "$@")
}

run_in() {
  local name="$1"
  local dir="$2"
  shift 2
  echo
  echo "==> ${name}"
  (cd "$ROOT/$dir" && "$@")
}

if [[ "${SKIP_WEB:-0}" != "1" ]]; then
  run_in "web build" "web" npm run build
fi

if [[ "${SKIP_ANDROID:-0}" != "1" ]]; then
  run_in "android assemble" "android" ./gradlew :app:assembleDebug
  run_in "android unit + screenshot tests" "android" ./gradlew :app:testDebugUnitTest
fi

if [[ "${SKIP_WEAROS:-0}" != "1" ]]; then
  run_in "wearos assemble" "wearos" ./gradlew :app:assembleDebug
  run_in "wearos unit tests" "wearos" ./gradlew :app:testDebugUnitTest
fi

if [[ "${SKIP_LINUX:-0}" != "1" ]]; then
  run_in "linux core tests" "linux" cargo test -p meshdrop-core
  run_in "linux tui tests" "linux" cargo test -p meshdrop-tui
  run_in "linux gui check" "linux" cargo check -p meshdrop-gui
fi

if [[ "${SKIP_APPLE:-0}" != "1" ]]; then
  run_in "apple MeshDropKit tests" "apple" swift test
fi

if [[ "${SKIP_WINDOWS:-0}" != "1" ]]; then
  case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      if command -v dotnet >/dev/null 2>&1; then
        run_in "windows build" "windows" dotnet build MeshDrop.sln -c Debug -p:Platform=x64
      else
        echo
        echo "==> windows build"
        echo "skip: dotnet not found"
      fi
      ;;
    *)
      echo
      echo "==> windows build"
      echo "skip: WinUI build requires Windows"
      ;;
  esac
fi

echo
echo "All available local checks completed."
