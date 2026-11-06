#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# mvn.sh — run Maven with nothing installed (Maven 3.9 + JDK 25 in a throwaway container)
#
# Usage    bash dockerspace/maven/maven3.9/mvn.sh -v               versions
#          bash dockerspace/maven/maven3.9/mvn.sh package          build the project in this folder
#          Maven's own help: bash dockerspace/maven/maven3.9/mvn.sh -h
#
# Cache    downloaded libraries stay in dockerspace/.cache/maven/maven3.9/ (git-ignored) — not again every run
#
# Sees     your current folder (and below) only — run it from your project folder
# Image    maven/maven3.9/tool.conf (IMAGE=…) · first use downloads it once, then it stays
# Installs nothing: the tool runs in a throwaway container (docker run --rm)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../lib/run_tool.sh"
case "${1:-}" in --help) tool_help "$HERE/mvn.sh"; exit 0 ;; esac
tool_log "$HERE/mvn.sh" "$@"
run_tool maven/maven3.9 maven:3.9-eclipse-temurin-25 mvn -Duser.home=/tmp/home "$@"
