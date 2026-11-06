#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# docker_status.sh — is Docker ready on this PC? (looks only, changes nothing)
#
# What for    One look at Docker on a fresh PC:
#             1. installed?   2. running?   3. you in the docker group (or log out + in)?
#             4. the tool images of dockerspace/<tool>/tool.conf — here or not
#             Every missing thing says which script fixes it.
#
# Who         You, by hand, any time:   bash dockerspace/docker_status.sh
#             No sudo. Always exit 0 (it reports, it never fails).
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/ccc/scripts/lib/create_logging_path.sh" ]; then
    source "$_WS_ROOT/ccc/scripts/lib/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/docker_common.sh"

case "${1:-}" in
    -h|--help)
        echo -e "${BOLD}docker_status.sh${RESET} — is Docker ready on this PC? (looks only, changes nothing)"
        echo ""
        echo -e "${BOLD}Usage${RESET}"
        echo -e "  ${CYAN}bash dockerspace/docker_status.sh${RESET}"
        echo ""
        echo -e "${BOLD}Shows${RESET}"
        echo "  installed · running · you in the docker group · tool images (dockerspace/<tool>/tool.conf)"
        echo "  each missing thing → the script that fixes it"
        exit 0 ;;
esac

ME="${REAL_USER:-$USER}"
FIX="bash dockerspace/docker_install.sh"
row() { printf "  ${BOLD}%-15s${RESET} %b\n" "$1" "$2"; }

echo ""
echo -e "${BOLD}Docker on this PC${RESET}"
echo -e "${CYAN}$(printf '─%.0s' {1..50})${RESET}"

if docker_installed; then
    row "installed" "${GREEN}yes${RESET} — $(docker --version)"
else
    row "installed" "${RED}no${RESET}  → $FIX"
    echo ""; exit 0
fi

if docker_running; then
    row "running" "${GREEN}yes${RESET}"
else
    row "running" "${RED}no${RESET}  → $FIX"
fi

GROUP_OK=""
if session_has_docker_group; then
    row "group" "${GREEN}yes${RESET} — '$ME' can use Docker without sudo"; GROUP_OK=1
elif user_in_docker_group "$ME"; then
    row "group" "${YELLOW}pending${RESET} — '$ME' was added; log out and back in once"
else
    row "group" "${RED}no${RESET}  → $FIX"
fi

# ── tool images: one per tool.conf — dockerspace/<tool>/ or <tool>/<version>/ (a new tool = a new folder) ─
shopt -s nullglob
CONFS=("$DOCKERSPACE_DIR"/*/tool.conf "$DOCKERSPACE_DIR"/*/*/tool.conf)
if [ ${#CONFS[@]} -eq 0 ]; then
    row "tools" "none yet (a tool = dockerspace/<tool>/tool.conf)"
elif [ -z "$GROUP_OK" ] || ! docker_running; then
    row "tools" "${YELLOW}not checked${RESET} — Docker must run and the group must work first"
else
    for conf in "${CONFS[@]}"; do
        tool="$(dirname "${conf#"$DOCKERSPACE_DIR"/}")"
        image="$(sed -n 's/^IMAGE=//p' "$conf" | head -1)"
        if [ -z "$image" ]; then
            row "$tool" "${YELLOW}no IMAGE= line${RESET} in $tool/tool.conf"
        elif docker image inspect "$image" >/dev/null 2>&1; then
            row "$tool" "${GREEN}here${RESET} — $image"
        else
            row "$tool" "not downloaded yet — $image (comes on first use)"
        fi
    done
fi
echo ""
exit 0
