#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# java.sh — run Java with nothing installed (JDK 21 in a throwaway container)
#
# Usage    bash dockerspace/jdk/java.sh Hello.java        one file: compiled + run
#          bash dockerspace/jdk/java.sh -cp . Hello       a compiled class
#          bash dockerspace/jdk/java.sh -jar app.jar      a jar
#          Java's own help: bash dockerspace/jdk/java.sh -help
#
# Sees     your current folder (and below) only — run it from your project folder
# Image    jdk/tool.conf (IMAGE=…) · first use downloads it once, then it stays
# Installs nothing: the tool runs in a throwaway container (docker run --rm)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../lib/run_tool.sh"
case "${1:-}" in --help) tool_help "$HERE/java.sh"; exit 0 ;; esac
tool_log "$HERE/java.sh" "$@"
run_tool jdk eclipse-temurin:21-jdk java "$@"
