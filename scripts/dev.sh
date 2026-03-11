#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PAIRING_DIR="$ROOT_DIR/pairing_service"
WEB_DIR="$ROOT_DIR/web"
PAIRING_PORT="${PORT:-8787}"
WEB_PORT="${WEB_PORT:-5173}"

pairing_pid=""
web_pid=""

find_listener_pid() {
  local port="$1"
  lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | head -n 1
}

cleanup() {
  if [[ -n "$web_pid" ]] && kill -0 "$web_pid" 2>/dev/null; then
    kill "$web_pid" 2>/dev/null || true
  fi
  if [[ -n "$pairing_pid" ]] && kill -0 "$pairing_pid" 2>/dev/null; then
    kill "$pairing_pid" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

existing_pairing_pid="$(find_listener_pid "$PAIRING_PORT" || true)"
if [[ -n "$existing_pairing_pid" ]]; then
  echo "[easychat] pairing_service already running on port $PAIRING_PORT (pid $existing_pairing_pid)"
  echo "[easychat] stop it first, or reuse the existing service and run: npm run dev:web"
  exit 1
fi

existing_web_pid="$(find_listener_pid "$WEB_PORT" || true)"
if [[ -n "$existing_web_pid" ]]; then
  echo "[easychat] web dev server already running on port $WEB_PORT (pid $existing_web_pid)"
  echo "[easychat] open the existing page, or stop it first and rerun npm run dev"
  exit 1
fi

echo "[easychat] starting pairing_service"
(
  cd "$PAIRING_DIR"
  node server.js
) &
pairing_pid=$!

echo "[easychat] starting web"
(
  cd "$WEB_DIR"
  npm run dev -- --host 0.0.0.0
) &
web_pid=$!

wait "$pairing_pid" "$web_pid"
