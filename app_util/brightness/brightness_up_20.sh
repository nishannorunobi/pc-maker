#!/bin/bash
# brightness_up_20.sh — increase screen brightness by 20%.
#
# Usage:  bash brightness/brightness_up_20.sh
set -euo pipefail

# ── Mirror-logging block (writes to mountspace/logs mirroring this path) ──────
_SELF_ABS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
_BASE="$(basename "$_SELF_ABS")"; _EXT="${_BASE##*.}"; _STEM="${_BASE%.*}"
_WS_ROOT="$(cd "$(dirname "$_SELF_ABS")" && d="$PWD"; while [ "$d" != "/" ] && [ ! -d "$d/mountspace" ]; do d="$(dirname "$d")"; done; echo "$d")"
_REL_DIR="$(dirname "${_SELF_ABS#${_WS_ROOT}/}")"
[ "$_REL_DIR" = "." ] && _REL_DIR="" || _REL_DIR="/$_REL_DIR"
LOG_FILE="${_WS_ROOT}/mountspace/logs/myworkspace${_REL_DIR}/${_STEM}_${_EXT}.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true; touch "$LOG_FILE" 2>/dev/null || true; export LOG_FILE
exec > >(awk '{ print strftime("[%Y-%m-%d %H:%M:%S]"), $0; fflush() }' | tee -a "$LOG_FILE") 2>&1
echo "[logging] → $LOG_FILE"
# ─────────────────────────────────────────────────────────────────────────────

brightnessctl set +20%
