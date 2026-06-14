#!/bin/bash
# guake_for_terminal.sh — Install Guake drop-down terminal and enable autostart.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash guake_for_terminal.sh"
    exit 1
fi

echo "Installing Guake..."
apt-get update -qq
apt-get install -y guake -qq
echo "Done. Guake installed."

# ── Autostart on login ────────────────────────────────────────────────────────
AUTOSTART_DIR="/home/${SUDO_USER:-$USER}/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/guake.desktop" << 'EOF'
[Desktop Entry]
Name=Guake Terminal
Comment=Drop-down terminal
Exec=/usr/bin/guake
Terminal=false
Type=Application
Categories=System;TerminalEmulator;
X-GNOME-Autostart-enabled=true
EOF

echo "Autostart enabled — Guake will launch on every login."
echo "Start now: guake &"
