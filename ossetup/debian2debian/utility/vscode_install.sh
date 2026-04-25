#!/bin/bash
# vscode_install.sh — Install Visual Studio Code on Debian/Ubuntu.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash vscode_install.sh"
    exit 1
fi

echo "Installing Visual Studio Code..."

apt-get update -qq
apt-get install -y wget gpg -qq

# ── Microsoft GPG key ─────────────────────────────────────────────────────────
wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
chmod a+r /etc/apt/keyrings/microsoft.gpg

# ── VS Code apt repository ────────────────────────────────────────────────────
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
    | tee /etc/apt/sources.list.d/vscode.list > /dev/null

# ── Install ───────────────────────────────────────────────────────────────────
apt-get update -qq
apt-get install -y code -qq

echo "Done. VS Code installed: $(code --version | head -1)"
echo "  Launch: code ."
