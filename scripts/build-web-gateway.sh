#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
web_root="$repo_root/web"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
node_binary="${NODE_BINARY:-$(command -v node || true)}"
if [[ -z "$node_binary" && -x "$HOME/.local/share/fnm/aliases/default/bin/node" ]]; then
  node_binary="$HOME/.local/share/fnm/aliases/default/bin/node"
fi
if [[ -z "$node_binary" || ! -f "$web_root/node_modules/vite/bin/vite.js" ]]; then
  echo "error: Web Gateway requires Node.js and web dependencies. Run npm ci in web/, and set NODE_BINARY if Node.js is not on PATH." >&2
  exit 1
fi

cd "$web_root"
"$node_binary" node_modules/typescript/bin/tsc --noEmit
"$node_binary" node_modules/vite/bin/vite.js build
destination="${TARGET_BUILD_DIR:?}/${UNLOCALIZED_RESOURCES_FOLDER_PATH:?}/web-fallback"
mkdir -p "$destination"
ditto dist "$destination"
