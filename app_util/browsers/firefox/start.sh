#!/bin/bash
# start.sh — run the portable Firefox from ./downloads/ (auto-downloads if missing).
# Uses a local profile under ./downloads/profile and --no-remote, so it runs
# independently and never touches your system Firefox / its profile.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"
BIN="$(pwd)/downloads/firefox/firefox"

if [ ! -x "$BIN" ]; then
    echo "Firefox not downloaded yet — running download_firefox.sh …"
    bash download_firefox.sh
fi

mkdir -p ./downloads/profile
echo "==> Launching portable Firefox …"
nohup "$BIN" --no-remote --profile "$(pwd)/downloads/profile" "$@" >/dev/null 2>&1 &
echo "$!" > ./downloads/firefox.pid
echo "    Started (pid $!). Profile: $(pwd)/downloads/profile"
echo "    Stop with: bash stop.sh"
