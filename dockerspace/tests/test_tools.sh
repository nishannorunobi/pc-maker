#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# test_tools.sh — auto tests of lib/run_tool.sh + the tools (jdk · maven)
#
# What for    Proves every tool builds the right throwaway `docker run` WITHOUT running one:
#             docker · systemctl · getent · id are FAKES first in PATH (the fake docker
#             records its arguments), the cache goes to a temp folder. Refuses otherwise.
#
# Who         Claude / you:   bash dockerspace/tests/test_tools.sh      (no sudo, no internet)
# Result      one PASS / FAIL line per test · "ALL PASS" · exit 1 on any FAIL
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

case "${1:-}" in -h|--help) sed -n '3,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

DS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$DS/zz-testtool"' EXIT
BIN="$TMP/bin"; ST="$TMP/state"; PROJ="$TMP/my project"; ARGS="$TMP/docker_args"
PASS=0; FAIL=0
ok()  { echo -e "\033[0;32mPASS\033[0m $1"; PASS=$((PASS+1)); }
bad() { echo -e "\033[0;31mFAIL\033[0m $1"; [ -n "${2:-}" ] && echo "$2" | tail -12 | sed 's/^/     | /'; FAIL=$((FAIL+1)); }
check() { local name="$1" out; out="$(sed 's/\x1b\[[0-9;]*m//g' <<<"$2")"; shift 2; local p; for p in "$@"; do
            if [[ "$p" == !* ]]; then grep -qF -- "${p#!}" <<<"$out" && { bad "$name (has '${p#!}')" "$out"; return; }
            else grep -qF -- "$p" <<<"$out" || { bad "$name (no '$p')" "$out"; return; }; fi; done; ok "$name"; }

# ── fakes ─────────────────────────────────────────────────────────────────────
mkdir -p "$BIN"
fake() { printf '#!/bin/bash\nST=%q; ARGS=%q\n%s\n' "$ST" "$ARGS" "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }
fake docker '[ -f $ST/installed ] || exit 127
case "$1" in
  --version) echo "Docker version 99.0.0 (fake)";;
  image)     [ -f $ST/image ];;
  pull)      echo "pull $*" >> $ST/calls; touch $ST/image;;
  build)     echo "build $*" >> $ST/calls; touch $ST/image;;
  run)       printf "%s\n" "$@" > $ARGS; echo "FAKE-RUN";;
esac'
fake systemctl '[ "$1" = is-active ] && [ -f $ST/running ]'
fake getent    '[ -f $ST/group ] && echo "docker:x:999:$USER"; exit 0'
fake id        'case "$1" in -u) echo 4242;; -g) echo 4343;; *) [ -f $ST/session ] && echo "$USER docker" || echo "$USER";; esac'
export PATH="$BIN:$PATH" DOCKERSPACE_CACHE="$TMP/cache"
for c in docker systemctl getent id; do
    [ "$(command -v $c)" = "$BIN/$c" ] || { echo "REFUSED: $c is not the fake ($(command -v $c))"; exit 1; }
done
[ "$EUID" -ne 0 ] || { echo "REFUSED: run as a normal user"; exit 1; }

reset() { rm -rf "$ST" "$ARGS" "$TMP/cache"; mkdir -p "$ST" "$PROJ"; local s; for s in "$@"; do touch "$ST/$s"; done; }
READY="installed running group session"
run_in() { (cd "$PROJ" && bash "$@" 2>&1 </dev/null); }
args()   { tr '\n' ' ' < "$ARGS" 2>/dev/null; }

# ── tests ─────────────────────────────────────────────────────────────────────
n=0; for f in "$DS/lib/run_tool.sh" "$DS"/jdk/jdk*/*.sh "$DS"/maven/maven*/*.sh "$0"; do bash -n "$f" || n=1; done
[ $n -eq 0 ] && ok "T1 bash -n on every script" || bad "T1 bash -n"

for s in jdk/jdk21/java.sh jdk/jdk21/javac.sh jdk/jdk25/java.sh jdk/jdk25/javac.sh maven/maven3.8/mvn.sh maven/maven3.9/mvn.sh; do
    check "T2 --help $s" "$(bash "$DS/$s" --help)" "Usage" "throwaway container" "!FAKE-RUN"
done

reset $READY
out="$(run_in "$DS/jdk/jdk21/java.sh" Hello.java)"
check "T3 java.sh: first use → downloaded once, then run" "$out $(cat "$ST/calls")" "downloading eclipse-temurin:21-jdk" "pull -q eclipse-temurin:21-jdk" "FAKE-RUN"
check "T4 java.sh: docker run --rm · as you · same folder · HOME · image · command" "$(args)" \
    "run --rm -i --user 4242:4343 -e HOME=/tmp/home -v $PROJ:$PROJ -w $PROJ eclipse-temurin:21-jdk java Hello.java" "! -t "

reset $READY image
out="$(run_in "$DS/jdk/jdk21/java.sh" Hello.java)"
check "T5 image already here → no download" "$out" "FAKE-RUN" "!downloading"
[ ! -f "$ST/calls" ] && ok "T5b no pull / build" || bad "T5b" "$(cat "$ST/calls")"

reset $READY image
run_in "$DS/jdk/jdk21/javac.sh" "My File.java" -d out >/dev/null
grep -qx "My File.java" "$ARGS" && check "T6 javac.sh: arguments kept as they are (spaces)" "$(args)" "eclipse-temurin:21-jdk javac My File.java -d out" \
    || bad "T6 'My File.java' split" "$(cat "$ARGS")"

reset $READY image
run_in "$DS/maven/maven3.9/mvn.sh" package >/dev/null
check "T7 mvn.sh: cache kept · MAVEN_CONFIG · user.home" "$(args)" \
    "-v $TMP/cache/maven/maven3.9:/tmp/home/.m2" "-e MAVEN_CONFIG=/tmp/home/.m2" "maven:3.9-eclipse-temurin-25 mvn -Duser.home=/tmp/home package"
[ -d "$TMP/cache/maven/maven3.9" ] && ok "T7b cache folder made (dockerspace/.cache/maven/maven3.9)" || bad "T7b no cache folder"

# a new tool = a new folder — nothing in lib/ changes
mkdir -p "$DS/zz-testtool"; : > "$DS/zz-testtool/tool.conf"
reset $READY image
out="$(cd "$PROJ" && bash -c "source '$DS/lib/run_tool.sh'; run_tool zz-testtool example/default:1 echo hi" 2>&1 </dev/null)"
check "T8 tool.conf without IMAGE → WARN + the default, still runs" "$out $(args)" "no IMAGE=" "example/default:1 echo hi" "FAKE-RUN"

rm -f "$DS/zz-testtool/tool.conf"
out="$(cd "$PROJ" && bash -c "source '$DS/lib/run_tool.sh'; run_tool zz-testtool example/default:1 echo hi" 2>&1 </dev/null)"
check "T9 no tool.conf → WARN + default" "$out" "tool.conf missing" "FAKE-RUN"

echo "FROM scratch" > "$DS/zz-testtool/Dockerfile"; echo "IMAGE=zz/own:1" > "$DS/zz-testtool/tool.conf"
reset $READY
out="$(cd "$PROJ" && bash -c "source '$DS/lib/run_tool.sh'; run_tool zz-testtool x:1 true" 2>&1 </dev/null)"
check "T10 Dockerfile in the tool folder → built, not downloaded" "$out $(cat "$ST/calls")" "building zz/own:1" "build -q -t zz/own:1" "!pull"
rm -rf "$DS/zz-testtool"

reset
out="$(run_in "$DS/jdk/jdk21/java.sh" Hello.java)"; rc=$?
check "T11 no Docker (no terminal) → says docker_install.sh, exit 1, nothing run" "$out rc=$rc" "not installed" "docker_install.sh" "rc=1" "!FAKE-RUN" "!Installing"

reset installed group session
out="$(run_in "$DS/jdk/jdk21/java.sh" Hello.java)"; rc=$?
check "T12 Docker stopped → says so, exit 1" "$out rc=$rc" "not running" "rc=1" "!FAKE-RUN"

reset installed running group
out="$(run_in "$DS/jdk/jdk21/java.sh" Hello.java)"; rc=$?
check "T13 group not active yet → log out + in, exit 1" "$out rc=$rc" "log out and back in" "rc=1" "!FAKE-RUN"

reset installed running
out="$(run_in "$DS/jdk/jdk21/java.sh" Hello.java)"; rc=$?
check "T14 not in the docker group → docker_install.sh adds you" "$out rc=$rc" "not in the docker group" "rc=1" "!FAKE-RUN"

reset $READY image
out="$(cd / && bash "$DS/jdk/jdk21/java.sh" Hello.java 2>&1 </dev/null)"; rc=$?
check "T15 run from / → refused (/ is never given to a tool)" "$out rc=$rc" "not /" "rc=1" "!FAKE-RUN"

reset $READY
out="$(bash "$DS/docker_status.sh" 2>&1)"
check "T16 docker_status.sh lists every version folder from its tool.conf" "$out" \
    "jdk/jdk21" "eclipse-temurin:21-jdk" "jdk/jdk25" "eclipse-temurin:25-jdk" \
    "maven/maven3.8" "maven:3.8-eclipse-temurin-21" "maven/maven3.9" "maven:3.9-eclipse-temurin-25"

# T18: each version folder runs ITS image, with its own cache
for v in 21 25; do
    reset $READY image
    run_in "$DS/jdk/jdk$v/java.sh" -version >/dev/null
    check "T18 jdk/jdk$v/java.sh → eclipse-temurin:$v-jdk" "$(args)" "eclipse-temurin:$v-jdk java -version"
done
for mv in "3.8 21" "3.9 25"; do set -- $mv
    reset $READY image
    run_in "$DS/maven/maven$1/mvn.sh" -v >/dev/null
    check "T18 maven/maven$1/mvn.sh → maven:$1-eclipse-temurin-$2 · cache maven/maven$1" "$(args)" \
        "maven:$1-eclipse-temurin-$2 mvn" "-v $TMP/cache/maven/maven$1:/tmp/home/.m2"
done
[ ! -e "$DS/jdk/java.sh" ] && [ ! -e "$DS/maven/mvn.sh" ] && [ ! -e "$DS/maven/jdk21" ] && ok "T19 no old jdk/java.sh · maven/mvn.sh · maven/jdk21 left" || bad "T19 old scripts still there"

grep -qx "dockerspace/.cache/" "$DS/../.gitignore" && ok "T17 dockerspace/.cache/ is git-ignored" || bad "T17 .gitignore"

echo ""
if [ $FAIL -eq 0 ]; then echo -e "\033[0;32mALL PASS\033[0m ($PASS)"; exit 0; fi
echo -e "\033[0;31m$FAIL FAIL\033[0m · $PASS pass"; exit 1
