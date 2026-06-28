#!/bin/bash
# start.sh — run the portable Chrome from ./downloads/ (auto-downloads if missing).
# Uses a local profile under ./downloads/profile via --user-data-dir, so it runs
# independently and never touches your system Chrome / its profile.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"
BIN="$(pwd)/downloads/chrome-linux64/chrome"

if [ ! -x "$BIN" ]; then
    echo "Chrome not downloaded yet — running download_chrome.sh …"
    bash download_chrome.sh
fi

mkdir -p ./downloads/profile
echo "==> Launching portable Chrome …"
nohup "$BIN" --user-data-dir="$(pwd)/downloads/profile" "$@" >/dev/null 2>&1 &
echo "$!" > ./downloads/chrome.pid
echo "    Started (pid $!). Profile: $(pwd)/downloads/profile"
echo "    Stop with: bash stop.sh"
