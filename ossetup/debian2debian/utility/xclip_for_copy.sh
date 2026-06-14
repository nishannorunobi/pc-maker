#!/bin/bash
# xclip_for_copy.sh — Install xclip to copy command output to clipboard.
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash xclip_for_copy.sh"
    exit 1
fi

echo "Installing xclip..."
apt-get update -qq
apt-get install -y xclip -qq
echo "Done. Usage:  command | xclip -selection clipboard"
