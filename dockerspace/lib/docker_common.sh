#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# docker_common.sh — the shared functions of dockerspace/ (sourced, never run)
#
# What for    One place for what docker_install.sh and docker_status.sh both need:
#             colours · reading docker.conf · which Docker repository fits this OS ·
#             is Docker installed / running / is the user in the docker group
#
# Who         Sourced by the scripts in dockerspace/. Nobody runs it by hand.
#
# Test seam   PCM_ROOT (default empty) is put in front of every system path
#             ($PCM_ROOT/etc/os-release …) so tests use a temp folder, never /etc.
# ─────────────────────────────────────────────────────────────────────────────

DOCKERSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PCM_ROOT="${PCM_ROOT:-}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── docker.conf: the defaults for an OS this script does not know ─────────────
# Missing file or missing line → the same values from here + WARN, never a stop.
load_docker_conf() {
    DEFAULT_REPO="ubuntu"; DEFAULT_CODENAME="noble"
    local conf="$DOCKERSPACE_DIR/docker.conf"
    if [ -f "$conf" ]; then
        # shellcheck disable=SC1090
        source "$conf"
    else
        warn "docker.conf missing — using defaults: ${DEFAULT_REPO} ${DEFAULT_CODENAME}"
    fi
    DEFAULT_REPO="${DEFAULT_REPO:-ubuntu}"; DEFAULT_CODENAME="${DEFAULT_CODENAME:-noble}"
}

# ── Which Docker repository fits this OS → sets REPO (debian|ubuntu) + CODENAME ─
#   ubuntu, or any OS that names its Ubuntu base (Linux Lite, Mint …) → ubuntu + UBUNTU_CODENAME
#   debian, or an OS "like debian"                                    → debian + VERSION_CODENAME
#   anything else / no codename                                       → docker.conf default + WARN
detect_docker_repo() {
    load_docker_conf
    local file="$PCM_ROOT/etc/os-release"
    local ID="" ID_LIKE="" VERSION_CODENAME="" UBUNTU_CODENAME="" PRETTY_NAME=""
    if [ -f "$file" ]; then
        # shellcheck disable=SC1090
        source "$file"
    else
        warn "$file not found"
    fi
    REPO=""; CODENAME=""
    if [ "$ID" = "ubuntu" ] || [ -n "$UBUNTU_CODENAME" ] || [[ " $ID_LIKE " == *" ubuntu "* ]]; then
        REPO="ubuntu"; CODENAME="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    elif [ "$ID" = "debian" ] || [[ " $ID_LIKE " == *" debian "* ]]; then
        REPO="debian"; CODENAME="$VERSION_CODENAME"
    fi
    if [ -z "$REPO" ] || [ -z "$CODENAME" ]; then
        warn "OS '${PRETTY_NAME:-${ID:-unknown}}' not recognised — using the default: ${DEFAULT_REPO} ${DEFAULT_CODENAME} (dockerspace/docker.conf)"
        REPO="$DEFAULT_REPO"; CODENAME="$DEFAULT_CODENAME"
    fi
}

# ── Docker's state ────────────────────────────────────────────────────────────
docker_installed() { command -v docker >/dev/null 2>&1 && docker --version >/dev/null 2>&1; }
docker_running()   { systemctl is-active --quiet docker 2>/dev/null; }

# user in the docker group in the group file (takes effect at the next login)
user_in_docker_group()    { getent group docker 2>/dev/null | cut -d: -f4 | tr ',' '\n' | grep -qx "$1"; }
# the group already works in THIS login (no log out + in needed)
session_has_docker_group() { id -nG 2>/dev/null | tr ' ' '\n' | grep -qx docker; }
