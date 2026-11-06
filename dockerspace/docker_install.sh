#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# docker_install.sh — install Docker Engine on a fresh Debian / Ubuntu-based PC
#
# What for    Step 2 of a fresh PC (after the OS): Docker Engine + buildx + compose,
#             from Docker's own repository. Everything else in dockerspace/ needs it.
#
# Who         You, by hand, on the NEW PC:   bash dockerspace/docker_install.sh
#             (asks for your sudo password itself) · or install_required_utility.sh
#
# OS          ubuntu / based on Ubuntu (Linux Lite, Mint …) → Docker's ubuntu repo, Ubuntu's codename
#             debian / based on Debian                     → Docker's debian repo
#             anything else                                → docker.conf default + WARN
#
# Safe to repeat   Docker installed + running + you in the docker group → "nothing to do".
#                  Installed but stopped / you not in the group → only that is fixed.
#
# After       New in the docker group → log out and back in once.
#             Check any time:  bash dockerspace/docker_status.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/ccc/scripts/lib/create_logging_path.sh" ] && [ -z "${PCM_SUDO_DONE:-}" ]; then   # after the sudo restart the log already runs
    source "$_WS_ROOT/ccc/scripts/lib/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
source "$(dirname "$SCRIPT_PATH")/lib/docker_common.sh"

show_help() {
    echo -e "${BOLD}docker_install.sh${RESET} — install Docker Engine on a fresh Debian / Ubuntu-based PC"
    echo ""
    echo -e "${BOLD}Usage${RESET}"
    echo -e "  ${CYAN}bash dockerspace/docker_install.sh${RESET}          install (asks for sudo itself)"
    echo -e "  ${CYAN}bash dockerspace/docker_install.sh --help${RESET}   this help"
    echo ""
    echo -e "${BOLD}What it does${RESET}"
    echo "  1. Docker installed + running + you in the docker group → nothing to do"
    echo "  2. reads /etc/os-release → Docker's debian or ubuntu repository + codename"
    echo "     (unknown OS → dockerspace/docker.conf default + WARN)"
    echo "  3. Docker's key + repository → docker-ce, cli, containerd, buildx, compose"
    echo "  4. adds you to the docker group · enables + starts Docker"
    echo ""
    echo -e "${BOLD}After${RESET}"
    echo "  new in the docker group → log out and back in once"
    echo -e "  check: ${CYAN}bash dockerspace/docker_status.sh${RESET}"
}

case "${1:-}" in
    -h|--help) show_help; exit 0 ;;
esac

REAL_USER="${REAL_USER:-${SUDO_USER:-$USER}}"

# ── 1. Already done? (no sudo needed to find out) ────────────────────────────
if docker_installed && docker_running && user_in_docker_group "$REAL_USER"; then
    success "Docker already installed and running, '$REAL_USER' in the docker group — nothing to do."
    exit 0
fi

# ── Root: ask for sudo ourselves ──────────────────────────────────────────────
if [ "$EUID" -ne 0 ] && [ -z "${PCM_SUDO_DONE:-}" ]; then
    info "Installing Docker needs root — asking for your sudo password."
    exec sudo env PCM_SUDO_DONE=1 REAL_USER="$REAL_USER" PCM_ROOT="$PCM_ROOT" bash "$SCRIPT_PATH" "$@"
fi

# ── 2 + 3. Install (only when Docker is not there) ───────────────────────────
if docker_installed; then
    info "Docker already installed: $(docker --version)"
else
    detect_docker_repo
    info "Installing Docker Engine — Docker's ${BOLD}${REPO}${RESET} repository, release ${BOLD}${CODENAME}${RESET}"

    # old, unofficial packages would clash with Docker's own
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg

    KEYRING="$PCM_ROOT/etc/apt/keyrings/docker.gpg"
    install -m 0755 -d "$(dirname "$KEYRING")"
    curl -fsSL "https://download.docker.com/linux/${REPO}/gpg" | gpg --yes --dearmor -o "$KEYRING"
    chmod a+r "$KEYRING"

    mkdir -p "$PCM_ROOT/etc/apt/sources.list.d"
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${REPO} ${CODENAME} stable" \
        > "$PCM_ROOT/etc/apt/sources.list.d/docker.list"

    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    success "Docker installed: $(docker --version)"
fi

# ── 4. Group + service (each only when needed) ───────────────────────────────
NEW_IN_GROUP=""
if user_in_docker_group "$REAL_USER"; then
    info "'$REAL_USER' already in the docker group"
else
    usermod -aG docker "$REAL_USER"
    NEW_IN_GROUP=1
    success "'$REAL_USER' added to the docker group"
fi

if docker_running; then
    info "Docker already running"
else
    systemctl enable docker
    systemctl start docker
    success "Docker enabled and started"
fi

echo ""
success "Done."
if [ -n "$NEW_IN_GROUP" ]; then
    warn "Log out and back in once — then Docker works without sudo."
fi
echo -e "  Check: ${CYAN}bash dockerspace/docker_status.sh${RESET}"
