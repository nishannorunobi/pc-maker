#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# test_dockerspace.sh — auto tests of docker_install.sh + docker_status.sh
#
# What for    Proves the install / status logic WITHOUT touching this PC:
#             every system command the scripts use (docker · apt-get · sudo · systemctl ·
#             usermod · getent · id · curl · gpg · dpkg) is a FAKE first in PATH, and
#             PCM_ROOT points every /etc path into a temp folder. Refuses to run otherwise.
#
# Who         Claude / you:   bash dockerspace/tests/test_dockerspace.sh      (no sudo)
# Result      one PASS / FAIL line per test · "ALL PASS" · exit 1 on any FAIL
# ─────────────────────────────────────────────────────────────────────────────
set -uo pipefail

case "${1:-}" in -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;; esac

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$HERE/docker_install.sh"; STATUS="$HERE/docker_status.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BIN="$TMP/bin"; ST="$TMP/state"; ROOT="$TMP/root"; LOG="$TMP/calls.log"
PASS=0; FAIL=0

ok()  { echo -e "\033[0;32mPASS\033[0m $1"; PASS=$((PASS+1)); }
bad() { echo -e "\033[0;31mFAIL\033[0m $1"; [ -n "${2:-}" ] && echo "$2" | tail -15 | sed 's/^/     | /'; FAIL=$((FAIL+1)); }
check() { local name="$1" out; out="$(sed "s/\x1b\[[0-9;]*m//g" <<<"$2")"; shift 2; local p; for p in "$@"; do
            if [[ "$p" == !* ]]; then grep -q -- "${p#!}" <<<"$out" && { bad "$name (has '${p#!}')" "$out"; return; }
            else grep -q -- "$p" <<<"$out" || { bad "$name (no '$p')" "$out"; return; }; fi; done; ok "$name"; }

# ── fakes ─────────────────────────────────────────────────────────────────────
mkdir -p "$BIN"
fake() { printf '#!/bin/bash\nST=%q; LOG=%q\necho "%s $*" >> "$LOG"\n%s\n' "$ST" "$LOG" "$1" "$2" > "$BIN/$1"; chmod +x "$BIN/$1"; }
fake docker    '[ -f $ST/installed ] || exit 127; case "$1" in --version) echo "Docker version 99.0.0 (fake)";; image) [ -f $ST/image ];; esac'
fake apt-get   'case " $* " in *" install "*docker-ce*) touch $ST/installed;; esac; exit 0'
fake systemctl 'case "$1" in is-active) [ -f $ST/running ];; start) touch $ST/running;; esac'
fake usermod   'touch $ST/group'
fake getent    '[ -f $ST/group ] && echo "docker:x:999:$USER"; exit 0'
fake id        'if [ -f $ST/session ]; then echo "$USER docker"; else echo "$USER"; fi'
fake sudo      'exec "$@"'
fake curl      'echo "$*" > $ST/curl_url; echo FAKEKEY'
fake gpg       'out=""; yes=""; while [ $# -gt 0 ]; do case "$1" in --yes) yes=1;; -o) out="$2"; shift;; esac; shift; done
                [ -f "$out" ] && [ -z "$yes" ] && { echo "gpg: File exists" >&2; exit 2; }; cat > "$out"'
fake dpkg      'echo amd64'
export PATH="$BIN:$PATH" PCM_ROOT="$ROOT"

# safety: refuse unless every command really is the fake
for c in docker apt-get systemctl usermod getent id sudo curl gpg dpkg; do
    [ "$(command -v $c)" = "$BIN/$c" ] || { echo "REFUSED: $c is not the fake ($(command -v $c))"; exit 1; }
done

# reset <state files…> · os <os-release lines…>
reset() { rm -rf "$ST" "$ROOT" "$LOG"; mkdir -p "$ST" "$ROOT/etc"; : > "$LOG"; local s; for s in "$@"; do touch "$ST/$s"; done; }
os()    { printf '%s\n' "$@" > "$ROOT/etc/os-release"; }
list()  { cat "$ROOT/etc/apt/sources.list.d/docker.list" 2>/dev/null; }

# ── tests ─────────────────────────────────────────────────────────────────────
n=0; for f in "$INSTALL" "$STATUS" "$HERE/lib/docker_common.sh" "$0" "$HERE/../ossetup/debian2debian/utility/install_required_utility.sh"; do
    bash -n "$f" || n=1; done
[ $n -eq 0 ] && ok "D1 bash -n on every script" || bad "D1 bash -n"

check "D2 --help (install)" "$(bash "$INSTALL" --help)" "Usage" "docker_status.sh"
check "D3 --help (status)"  "$(bash "$STATUS" --help)"  "Usage" "looks only"

reset; os 'ID=ubuntu' 'VERSION_CODENAME=noble' 'UBUNTU_CODENAME=noble'
out="$(bash "$INSTALL" 2>&1)"; check "D4 Ubuntu → ubuntu noble, installed, group, started" "$out$(list)" \
    "linux/ubuntu noble stable" "Docker installed" "added to the docker group" "Log out and back in"
grep -q "linux/ubuntu/gpg" "$ST/curl_url" && ok "D4b Ubuntu → ubuntu key" || bad "D4b key url" "$(cat "$ST/curl_url")"

reset; os 'ID=debian' 'VERSION_CODENAME=bookworm'
out="$(bash "$INSTALL" 2>&1)"; check "D5 Debian → debian bookworm" "$out$(list)" "linux/debian bookworm stable" "!not recognised"
grep -q "linux/debian/gpg" "$ST/curl_url" && ok "D5b Debian → debian key" || bad "D5b key url" "$(cat "$ST/curl_url")"

reset; os 'ID=linuxlite' 'ID_LIKE="ubuntu debian"' 'VERSION_CODENAME=fluxbox' 'UBUNTU_CODENAME=noble'
out="$(bash "$INSTALL" 2>&1)"; check "D6 Linux Lite → ubuntu + Ubuntu's codename (not its own)" "$out$(list)" "linux/ubuntu noble stable" "!fluxbox"

reset; os 'ID=linuxmint' 'ID_LIKE=ubuntu' 'VERSION_CODENAME=wilma' 'UBUNTU_CODENAME=noble'
out="$(bash "$INSTALL" 2>&1)"; check "D7 Mint → ubuntu noble" "$out$(list)" "linux/ubuntu noble stable" "!wilma"

reset; os 'ID=arch' 'PRETTY_NAME="Arch Linux"'
out="$(bash "$INSTALL" 2>&1)"; check "D8 unknown OS → WARN + docker.conf default, still installs" "$out$(list)" \
    "not recognised" "linux/ubuntu noble stable" "Docker installed"

reset; rm -f "$ROOT/etc/os-release"
out="$(bash "$INSTALL" 2>&1)"; check "D9 no os-release → WARN + default" "$out$(list)" "not found" "linux/ubuntu noble stable"

reset installed running group
out="$(bash "$INSTALL" 2>&1)"; check "D10 all there → nothing to do, no apt / sudo" "$out" "nothing to do"
grep -qE "^(apt-get|sudo|usermod)" "$LOG" && bad "D10b nothing changed" "$(cat "$LOG")" || ok "D10b nothing changed (no apt-get · sudo · usermod)"

reset installed group
out="$(bash "$INSTALL" 2>&1)"; check "D11 installed but stopped → only started" "$out" "already installed" "started" "!Installing Docker Engine"

reset installed running
out="$(bash "$INSTALL" 2>&1)"; check "D12 installed, user not in group → only added" "$out" "added to the docker group" "already running" "Log out"

reset; os 'ID=ubuntu' 'UBUNTU_CODENAME=noble'
mkdir -p "$ROOT/etc/apt/keyrings"; echo OLD > "$ROOT/etc/apt/keyrings/docker.gpg"
out="$(bash "$INSTALL" 2>&1)"; rc=$?
[ $rc -eq 0 ] && grep -q FAKEKEY "$ROOT/etc/apt/keyrings/docker.gpg" && ok "D13 key file already there → overwritten (gpg --yes), no stop" || bad "D13 rerun with key (rc=$rc)" "$out"

reset
out="$(bash "$STATUS" 2>&1)"; rc=$?
check "D14 status: not installed → fix hint, exit 0" "$out rc=$rc" "installed" "docker_install.sh" "rc=0"

reset installed running group
out="$(bash "$STATUS" 2>&1)"; check "D15 status: in group, not in this login → log out + in" "$out" "pending" "log out"

reset installed running group session
out="$(bash "$STATUS" 2>&1)"; check "D16 status: all ok · tools listed" "$out" "without sudo" "jdk" "maven" "!→ bash"

reset installed group session
out="$(bash "$STATUS" 2>&1)"; check "D17 status: not running → fix hint" "$out" "running" "docker_install.sh"

# D18: tool images come from dockerspace/<tool>/tool.conf (a temp tool folder, removed after)
mkdir -p "$HERE/zz-testtool"; echo "IMAGE=example/tool:1" > "$HERE/zz-testtool/tool.conf"
reset installed running group session
out1="$(bash "$STATUS" 2>&1)"; touch "$ST/image"; out2="$(bash "$STATUS" 2>&1)"; rm -rf "$HERE/zz-testtool"
check "D18 status: tool image missing → 'first use' · present → 'here'" "$out1 ## $out2" "not downloaded yet" "here — example/tool:1"

UTIL="$HERE/../ossetup/debian2debian/utility"
target="$(sed -n 's/^ *"\(.*docker_install.sh\)".*/\1/p' "$UTIL/install_required_utility.sh")"
[ -f "$UTIL/$target" ] && [ "$(cd "$UTIL" && realpath "$target")" = "$INSTALL" ] \
    && ok "D19 install_required_utility.sh runs dockerspace/docker_install.sh" || bad "D19 path '$target'"
[ ! -e "$UTIL/docker_install.sh" ] && ok "D20 no docker_install.sh left in utility/" || bad "D20 old copy still in utility/"

echo ""
if [ $FAIL -eq 0 ]; then echo -e "\033[0;32mALL PASS\033[0m ($PASS)"; exit 0; fi
echo -e "\033[0;31m$FAIL FAIL\033[0m · $PASS pass"; exit 1
