#!/bin/bash
# clean.sh — stop the portable Chrome (if running) and remove everything under
# ./downloads/ so download_chrome.sh can fetch a fresh copy. Only touches THIS
# folder's downloads/ — nothing system-wide.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"
bash stop.sh >/dev/null 2>&1 || true
rm -rf ./downloads
echo "Cleaned ./downloads. Run: bash download_chrome.sh  (or start.sh to fetch + run)."
