#!/bin/bash
# git_install.sh — Install Git on Debian/Ubuntu.
set -euo pipefail

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
