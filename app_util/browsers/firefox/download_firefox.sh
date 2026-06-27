#!/bin/bash
# download_firefox.sh — download the latest Firefox (Linux 64-bit) into ./downloads/.
# Mirrors the grafana "download_binary.sh" pattern. ./downloads/ is gitignored;
# clean.sh wipes it so this can run fresh. FORCE=1 re-downloads even if present.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"

URL="https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US"

if [ -x ./downloads/firefox/firefox ] && [ "${FORCE:-0}" != "1" ]; then
    echo "Firefox already downloaded ($(pwd)/downloads/firefox/firefox). FORCE=1 to re-download."
    exit 0
fi

echo "==> Downloading Firefox (linux64) into ./downloads/ …"
rm -rf downloads
mkdir -p downloads
wget --tries=5 --retry-connrefused --retry-on-host-error --waitretry=5 --timeout=30 \
     -O ./downloads/firefox.tar.xz "$URL"

echo "==> Extracting …"
tar -xf ./downloads/firefox.tar.xz -C ./downloads    # creates ./downloads/firefox/
rm -f ./downloads/firefox.tar.xz

echo "==> Done: $(./downloads/firefox/firefox --version 2>/dev/null || echo 'Firefox ready')"
echo "    Binary: $(pwd)/downloads/firefox/firefox  —  run it with start.sh"
