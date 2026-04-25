#!/bin/bash
# xclip_for_copy.sh — Install xclip to copy command output to clipboard.
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash xclip_for_copy.sh"
    exit 1
fi

echo "Installing xclip..."
apt-get update -qq
apt-get install -y xclip -qq
echo "Done. Usage:  command | xclip -selection clipboard"
