#!/bin/bash
# vim_install.sh — Install Vim on Debian/Ubuntu.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash vim_install.sh"
    exit 1
fi

echo "Installing Vim..."
apt-get update -qq
apt-get install -y vim -qq
echo "Done. Vim installed: $(vim --version | head -1)"
echo ""
echo "  Quick reference:"
echo "    i         — insert mode"
echo "    Esc       — normal mode"
echo "    :w        — save"
echo "    :q        — quit"
echo "    :wq       — save and quit"
echo "    :q!       — quit without saving"
