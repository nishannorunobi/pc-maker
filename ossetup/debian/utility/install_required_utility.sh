#!/bin/bash
# install_required_utility.sh — Install all required utilities in one shot.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$EUID" -ne 0 ]; then
    echo "Run as root: sudo bash install_required_utility.sh"
    exit 1
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

SCRIPTS=(
    "git_install.sh"
    "vim_install.sh"
    "xclip_for_copy.sh"
    "guake_for_terminal.sh"
    "chrome_install.sh"
    "vscode_install.sh"
    "docker_install.sh"
)

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║     Required Utility Installer       ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""
info "Installing ${#SCRIPTS[@]} utilities..."
echo ""

FAILED=()

for SCRIPT in "${SCRIPTS[@]}"; do
    SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT"

    if [ ! -f "$SCRIPT_PATH" ]; then
        warn "Script not found, skipping: $SCRIPT"
        FAILED+=("$SCRIPT (not found)")
        continue
    fi

    echo -e "${BOLD}── $SCRIPT ${RESET}"
    if bash "$SCRIPT_PATH"; then
        success "$SCRIPT done."
    else
        error "$SCRIPT failed."
        FAILED+=("$SCRIPT")
    fi
    echo ""
done

echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║             Summary                  ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

TOTAL=${#SCRIPTS[@]}
FAILED_COUNT=${#FAILED[@]}
PASSED=$((TOTAL - FAILED_COUNT))

success "Completed : $PASSED / $TOTAL"

if [ "$FAILED_COUNT" -gt 0 ]; then
    echo ""
    error "Failed ($FAILED_COUNT):"
    for F in "${FAILED[@]}"; do
        echo -e "  ${RED}✗${RESET}  $F"
    done
    echo ""
    exit 1
fi

echo ""
info "All utilities installed. Log out and back in for group changes (docker) to take effect."
echo ""
