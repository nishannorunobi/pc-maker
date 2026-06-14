#!/bin/bash
# git_install.sh — Install Git on Debian/Ubuntu.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash git_install.sh"
    exit 1
fi

echo "Installing Git..."
apt-get update -qq
apt-get install -y git -qq
echo "Done. Git installed: $(git --version)"
echo ""
echo "  Configure identity:"
echo "    git config --global user.name  \"Your Name\""
echo "    git config --global user.email \"you@example.com\""
