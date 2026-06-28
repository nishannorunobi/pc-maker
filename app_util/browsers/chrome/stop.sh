#!/bin/bash
# stop.sh — stop the portable Chrome started from this folder. Matches it by its
# UNIQUE binary path, so your system Chrome (a different path) is never touched.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"
TARGET="$(pwd)/downloads/chrome-linux64/chrome"

if pkill -f "$TARGET" 2>/dev/null; then
    echo "Stopped portable Chrome ($TARGET)."
else
    echo "No portable Chrome running from here."
fi
rm -f ./downloads/chrome.pid 2>/dev/null || true
