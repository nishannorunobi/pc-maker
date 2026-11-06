#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# javac.sh — compile Java with nothing installed (JDK 25 in a throwaway container)
#
# Usage    bash dockerspace/jdk/jdk25/javac.sh Hello.java       → Hello.class (owned by you)
#          bash dockerspace/jdk/jdk25/javac.sh -d out src/*.java
#          javac's own help: bash dockerspace/jdk/jdk25/javac.sh -help
#
# Sees     your current folder (and below) only — run it from your project folder
# Image    jdk/jdk25/tool.conf (IMAGE=…) · first use downloads it once, then it stays
# Installs nothing: the tool runs in a throwaway container (docker run --rm)
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../lib/run_tool.sh"
case "${1:-}" in --help) tool_help "$HERE/javac.sh"; exit 0 ;; esac
tool_log "$HERE/javac.sh" "$@"
run_tool jdk/jdk25 eclipse-temurin:25-jdk javac "$@"
