#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NVMRC_PATH="$ROOT_DIR/.nvmrc"

if [[ $# -eq 0 ]]; then
  echo "[easychat] missing command"
  exit 1
fi

if [[ ! -f "$NVMRC_PATH" ]]; then
  exec "$@"
fi

required_version="$(tr -d '[:space:]' < "$NVMRC_PATH")"
required_version="${required_version#v}"

current_node_path="$(command -v node || true)"
current_version=""
if [[ -n "$current_node_path" ]]; then
  current_version="$(node -p "process.versions.node" 2>/dev/null || true)"
fi

if [[ "$current_version" == "$required_version" ]]; then
  exec "$@"
fi

nvm_node_bin="$HOME/.nvm/versions/node/v$required_version/bin"
if [[ -x "$nvm_node_bin/node" && -x "$nvm_node_bin/npm" ]]; then
  export PATH="$nvm_node_bin:$PATH"
  hash -r
  exec "$@"
fi

echo "[easychat] Node.js v$required_version is required by .nvmrc"
if [[ -n "$current_version" ]]; then
  echo "[easychat] current node: v$current_version ($current_node_path)"
else
  echo "[easychat] current node: not found"
fi
if [[ -f "$HOME/.npmrc" ]] && grep -Eq '(^|[[:space:]])prefix=' "$HOME/.npmrc"; then
  echo "[easychat] ~/.npmrc contains a prefix setting; nvm may require clearing it before switching versions"
fi
echo "[easychat] install/switch to Node.js v$required_version, or place it under ~/.nvm/versions/node/v$required_version"
exit 1
