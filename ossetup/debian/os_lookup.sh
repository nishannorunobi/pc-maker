#!/bin/bash
# os_lookup.sh — Find an OS ISO in the current directory.
#                If not found, download it from the defined URL.
#                Outputs the ISO path for use by other scripts.
set -euo pipefail

# ── Variables — change these to target a different OS ─────────────────────────
ISO_NAME="linux-lite-7.8-64bit.iso"
ISO_URL="https://mirror.clarkson.edu/linux-lite/isos/7.8/linux-lite-7.8-64bit.iso"
#ISO_URL="https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-12.10.0-amd64-netinst.iso"
SEARCH_DIR="${ISO_SEARCH_DIR:-$(pwd)}"

# ─────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        OS ISO Lookup                 ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""
info "Looking for: $ISO_NAME"
info "Search dir : $SEARCH_DIR"
echo ""

# ── Search for ISO in current directory ───────────────────────────────────────
ISO_PATH=$(find "$SEARCH_DIR" -maxdepth 1 -type f -name "$ISO_NAME" 2>/dev/null | head -1)

if [ -n "$ISO_PATH" ]; then
    ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
    success "ISO found: $ISO_PATH  ($ISO_SIZE)"
else
    warn "ISO not found in $SEARCH_DIR"
    echo ""
    info "Downloading from:"
    info "  $ISO_URL"
    echo ""

    ISO_PATH="$SEARCH_DIR/$ISO_NAME"

    if command -v wget &>/dev/null; then
        wget --show-progress -q "$ISO_URL" -O "$ISO_PATH"
    elif command -v curl &>/dev/null; then
        curl -L --progress-bar "$ISO_URL" -o "$ISO_PATH"
    else
        error "wget or curl is required to download the ISO."
        error "Install with: sudo apt install wget"
        exit 1
    fi

    ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
    success "Downloaded: $ISO_PATH  ($ISO_SIZE)"
fi

# ── Export path for use by other scripts ──────────────────────────────────────
echo ""
echo -e "  ${BOLD}ISO_PATH${RESET}  =  $ISO_PATH"
echo ""

# Write to a temp env file so other scripts can source it
echo "ISO_PATH=\"$ISO_PATH\"" > /tmp/os_lookup_result.env
info "Path saved to /tmp/os_lookup_result.env"
info "Use in other scripts: source /tmp/os_lookup_result.env"
echo ""
