#!/bin/bash
# vim_install.sh — Install Vim on Debian/Ubuntu.
set -euo pipefail

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
