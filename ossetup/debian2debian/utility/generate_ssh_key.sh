#!/bin/bash
# generate_ssh_key.sh — Generate an SSH key pair and display the public key.
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║         SSH Key Generator            ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── Step 1: Email / comment ───────────────────────────────────────────────────
read -rp "  Enter your email (used as key comment): " KEY_EMAIL
if [ -z "$KEY_EMAIL" ]; then
    warn "No email entered — using 'user@localhost'"
    KEY_EMAIL="user@localhost"
fi

# ── Step 2: Key type ──────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Key type:${RESET}"
echo "  1) Ed25519  — recommended (modern, fast, secure)"
echo "  2) RSA 4096 — widely compatible (older servers)"
echo ""
read -rp "  Choose [1-2] (default: 1): " KEY_CHOICE
KEY_CHOICE="${KEY_CHOICE:-1}"

case "$KEY_CHOICE" in
    1) KEY_TYPE="ed25519"; KEY_ARGS="-t ed25519" ;;
    2) KEY_TYPE="rsa";     KEY_ARGS="-t rsa -b 4096" ;;
    *)
        warn "Invalid choice — defaulting to Ed25519"
        KEY_TYPE="ed25519"; KEY_ARGS="-t ed25519" ;;
esac

# ── Step 3: Key file path ─────────────────────────────────────────────────────
echo ""
DEFAULT_KEY="$HOME/.ssh/id_${KEY_TYPE}"
read -rp "  Key file path (default: $DEFAULT_KEY): " KEY_PATH
KEY_PATH="${KEY_PATH:-$DEFAULT_KEY}"

# ── Step 4: Check if key already exists ──────────────────────────────────────
if [ -f "$KEY_PATH" ]; then
    echo ""
    warn "Key already exists: $KEY_PATH"
    read -rp "  Overwrite? [y/N]: " OVERWRITE
    if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
        info "Cancelled. Existing key was not changed."
        exit 0
    fi
fi

# ── Step 5: Generate ──────────────────────────────────────────────────────────
echo ""
info "Generating $KEY_TYPE key..."
mkdir -p "$(dirname "$KEY_PATH")"
chmod 700 "$(dirname "$KEY_PATH")"

ssh-keygen $KEY_ARGS -C "$KEY_EMAIL" -f "$KEY_PATH"

chmod 600 "$KEY_PATH"
chmod 644 "$KEY_PATH.pub"

# ── Step 6: Show public key ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║           Your Public Key            ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""
cat "$KEY_PATH.pub"
echo ""

# ── Step 7: Copy to clipboard if xclip available ─────────────────────────────
if command -v xclip &>/dev/null; then
    xclip -selection clipboard < "$KEY_PATH.pub"
    success "Public key copied to clipboard."
else
    warn "xclip not found — copy the key above manually."
    info "Install xclip: sudo apt install xclip"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
success "SSH key generated!"
echo ""
printf "  ${BOLD}%-18s${RESET} %s\n" "Private key:"  "$KEY_PATH"
printf "  ${BOLD}%-18s${RESET} %s\n" "Public key:"   "$KEY_PATH.pub"
printf "  ${BOLD}%-18s${RESET} %s\n" "Type:"         "$KEY_TYPE"
printf "  ${BOLD}%-18s${RESET} %s\n" "Comment:"      "$KEY_EMAIL"
echo ""
echo -e "  ${BOLD}Add to GitHub/GitLab:${RESET}"
echo "    Settings → SSH Keys → paste the public key above"
echo ""
echo -e "  ${BOLD}Add to a remote server:${RESET}"
echo "    ssh-copy-id -i $KEY_PATH.pub user@server"
echo ""
