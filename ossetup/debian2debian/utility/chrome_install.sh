#!/bin/bash
# chrome_install.sh — Install Google Chrome on Debian/Ubuntu.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash chrome_install.sh"
    exit 1
fi

echo "Installing Google Chrome..."

apt-get update -qq
apt-get install -y wget -qq

TMP_DEB="/tmp/google-chrome-stable.deb"

wget -q "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
    -O "$TMP_DEB"

apt-get install -y "$TMP_DEB" -qq

rm -f "$TMP_DEB"

echo "Done. Chrome installed: $(google-chrome --version)"
echo "  Launch: google-chrome &"
