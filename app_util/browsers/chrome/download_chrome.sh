#!/bin/bash
# download_chrome.sh — download the latest Chrome (Linux 64-bit) into ./downloads/.
# Mirrors firefox/download_firefox.sh. Uses Google's "Chrome for Testing" portable
# zip (the only officially-supported standalone Chrome build for Linux).
# ./downloads/ is gitignored; clean.sh wipes it. FORCE=1 re-downloads even if present.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

cd "$(dirname "$0")"

if [ -x ./downloads/chrome-linux64/chrome ] && [ "${FORCE:-0}" != "1" ]; then
    echo "Chrome already downloaded ($(pwd)/downloads/chrome-linux64/chrome). FORCE=1 to re-download."
    exit 0
fi

echo "==> Resolving latest stable Chrome (linux64) download URL …"
VERSIONS_JSON="https://googlechromelabs.github.io/chrome-for-testing/last-known-good-versions-with-downloads.json"
URL="$(wget -qO- "$VERSIONS_JSON" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for d in data["channels"]["Stable"]["downloads"]["chrome"]:
    if d["platform"] == "linux64":
        print(d["url"]); break
')"
if [ -z "$URL" ]; then
    echo "ERROR: could not resolve Chrome linux64 download URL." >&2
    exit 1
fi

echo "==> Downloading Chrome (linux64) into ./downloads/ …"
rm -rf downloads
mkdir -p downloads
wget --tries=5 --retry-connrefused --retry-on-host-error --waitretry=5 --timeout=30 \
     -O ./downloads/chrome.zip "$URL"

echo "==> Extracting …"
unzip -q ./downloads/chrome.zip -d ./downloads    # creates ./downloads/chrome-linux64/
rm -f ./downloads/chrome.zip

echo "==> Done: $(./downloads/chrome-linux64/chrome --version 2>/dev/null || echo 'Chrome ready')"
echo "    Binary: $(pwd)/downloads/chrome-linux64/chrome  —  run it with start.sh"
