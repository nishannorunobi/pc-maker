#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# run_tool.sh — run a tool as a THROWAWAY container (sourced, never run)
#
# What for    ONE function for every dockerspace/<tool>/<command>.sh:
#               run_tool <tool folder> <default image> <command> [args…]
#             1. Docker missing → offered (docker_install.sh) · stopped / group pending → what to do
#             2. <tool>/tool.conf: IMAGE · CACHE · ENV   (missing IMAGE → WARN + the default)
#             3. image not here → <tool>/Dockerfile → built · else downloaded, once
#             4. docker run --rm · as YOU (files stay yours) · your current folder at the SAME path
#
# Add a tool  a new folder: tool.conf + a 3-line <command>.sh — nothing here changes
#
# Log         one line per run (date · folder · command) in the workspace mirror log, when the
#             workspace is there. The screen is NOT piped (java, jshell … need the real terminal).
#
# Test seam   DOCKERSPACE_CACHE (default dockerspace/.cache) — where CACHE folders are kept
# ─────────────────────────────────────────────────────────────────────────────

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/docker_common.sh"
DOCKERSPACE_CACHE="${DOCKERSPACE_CACHE:-$DOCKERSPACE_DIR/.cache}"

# the header of the calling script, as its --help
tool_help() { sed -n '3,/^# ─/p' "$1" | sed '$d; s/^# \{0,1\}//'; }

# one line in the workspace mirror log (mountspace/logs/<ws>/<path>/<stem>_sh.log) — never fails
tool_log() {
    local self="$1"; shift
    local d; d="$(dirname "$self")"
    while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done
    [ "$d" = "/" ] && return 0
    local rel="${self#"$d"/}" base; base="$(basename "$self")"
    local log="$d/mountspace/logs/$(basename "$d")/$(dirname "$rel")/${base%.*}_${base##*.}.log"
    { mkdir -p "$(dirname "$log")" && echo "[$(date '+%Y-%m-%d %H:%M:%S')] $PWD \$ $(basename "$self") $*" >> "$log"; } 2>/dev/null || true
}

# Docker usable by this user, now? Else say what to do and return 1.
docker_ready() {
    if ! docker_installed; then
        warn "Docker is not installed — the tools in dockerspace/ run inside Docker."
        if [ -t 0 ] && [ -t 1 ]; then
            local a; read -rp "  Install Docker now (bash dockerspace/docker_install.sh)? [Y/n] " a
            case "$a" in n|N|no|No) ;; *) bash "$DOCKERSPACE_DIR/docker_install.sh" || return 1 ;; esac
        fi
        docker_installed || { error "Docker is needed first:  bash dockerspace/docker_install.sh"; return 1; }
    fi
    if ! docker_running; then
        error "Docker is not running:  bash dockerspace/docker_install.sh  (starts it)"; return 1
    fi
    if [ "$EUID" -ne 0 ] && ! session_has_docker_group; then
        if user_in_docker_group "$USER"; then
            error "You were added to the docker group — log out and back in once, then run this again."
        else
            error "You are not in the docker group:  bash dockerspace/docker_install.sh  (adds you)"
        fi
        return 1
    fi
}

run_tool() {
    local tool="$1" default="$2"; shift 2
    local dir="$DOCKERSPACE_DIR/$tool" IMAGE="" CACHE="" ENV=""
    if [ -f "$dir/tool.conf" ]; then
        # shellcheck disable=SC1091
        source "$dir/tool.conf"
    else
        warn "$tool/tool.conf missing"
    fi
    if [ -z "$IMAGE" ]; then warn "no IMAGE= in $tool/tool.conf — using the default: $default"; IMAGE="$default"; fi
    if [ "$PWD" = "/" ]; then error "Run it from a project folder, not / (that folder is given to the tool)."; exit 1; fi

    docker_ready || exit 1

    if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
        if [ -f "$dir/Dockerfile" ]; then
            info "First use: building $IMAGE from $tool/Dockerfile (once)"
            docker build -q -t "$IMAGE" "$dir" >/dev/null || { error "Could not build $IMAGE"; exit 1; }
        else
            info "First use: downloading $IMAGE (needs the internet this once)"
            docker pull -q "$IMAGE" >/dev/null || { error "Could not download $IMAGE"; exit 1; }
        fi
    fi

    local args=(run --rm -i --user "$(id -u):$(id -g)" -e HOME=/tmp/home -v "$PWD:$PWD" -w "$PWD")
    if [ -t 0 ] && [ -t 1 ]; then args+=(-t); fi
    if [ -n "$CACHE" ]; then
        mkdir -p "$DOCKERSPACE_CACHE/$tool"
        args+=(-v "$DOCKERSPACE_CACHE/$tool:$CACHE")
    fi
    local e; for e in $ENV; do args+=(-e "$e"); done

    exec docker "${args[@]}" "$IMAGE" "$@"
}
