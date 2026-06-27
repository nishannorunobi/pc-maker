#!/bin/bash
# stop.sh — stop the portable Firefox started from this folder. Matches it by its
# UNIQUE binary path, so your system Firefox (a different path) is never touched.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"
TARGET="$(pwd)/downloads/firefox/firefox"

if pkill -f "$TARGET" 2>/dev/null; then
    echo "Stopped portable Firefox ($TARGET)."
else
    echo "No portable Firefox running from here."
fi
rm -f ./downloads/firefox.pid 2>/dev/null || true
