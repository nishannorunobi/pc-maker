#!/bin/bash
# disk_health.sh — Overview of disk usage: space left, top directories, filesystem health.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}$*${RESET}"; echo -e "${CYAN}$(printf '─%.0s' {1..50})${RESET}"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║              Disk Health Report                  ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo -e "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"

# ── Section 1: Filesystem overview ───────────────────────────────────────────
header "1. Filesystem Overview (df)"
df -h --output=source,fstype,size,used,avail,pcent,target \
    -x tmpfs -x devtmpfs -x squashfs \
    | awk '
    NR==1 { printf "  %-22s %-8s %6s %6s %6s %5s  %s\n", $1,$2,$3,$4,$5,$6,$7; next }
    {
        pct = $6; gsub(/%/,"",pct)
        color = "\033[0;32m"
        if (pct+0 >= 90) color = "\033[0;31m"
        else if (pct+0 >= 75) color = "\033[1;33m"
        printf "  %-22s %-8s %6s %6s %6s " color "%5s\033[0m  %s\n", $1,$2,$3,$4,$5,$6,$7
    }'

# ── Section 2: Disk usage by top-level directories ───────────────────────────
header "2. Top Directories Using Most Space  (top 15)"
echo "  Scanning / — this may take a moment..."
echo ""

du -hx --max-depth=2 / 2>/dev/null \
    | grep -v "^0" \
    | sort -rh \
    | head -15 \
    | awk '{printf "  %-8s  %s\n", $1, $2}'

# ── Section 3: Home directory breakdown ──────────────────────────────────────
header "3. Home Directory Breakdown  (~)"
HOME_DIR="${HOME:-/root}"
if [ -d "$HOME_DIR" ]; then
    du -hx --max-depth=1 "$HOME_DIR" 2>/dev/null \
        | sort -rh \
        | awk '{printf "  %-8s  %s\n", $1, $2}'
else
    echo "  Home directory not found: $HOME_DIR"
fi

# ── Section 4: Largest files on system ───────────────────────────────────────
header "4. Largest Files on System  (top 10)"
echo "  Scanning — skipping /proc /sys /dev..."
echo ""

find / -xdev -type f -printf '%s %p\n' 2>/dev/null \
    | sort -rn \
    | head -10 \
    | awk '{
        size=$1; path=$2
        if (size >= 1073741824) printf "  %6.1f GB  %s\n", size/1073741824, path
        else if (size >= 1048576) printf "  %6.1f MB  %s\n", size/1048576, path
        else printf "  %6.1f KB  %s\n", size/1024, path
    }'

# ── Section 5: Inode usage ────────────────────────────────────────────────────
header "5. Inode Usage"
df -i --output=source,itotal,iused,iavail,ipcent,target \
    -x tmpfs -x devtmpfs -x squashfs \
    | awk '
    NR==1 { printf "  %-22s %10s %10s %10s %6s  %s\n", $1,$2,$3,$4,$5,$6; next }
    {
        pct = $5; gsub(/%/,"",pct)
        color = "\033[0;32m"
        if (pct+0 >= 90) color = "\033[0;31m"
        else if (pct+0 >= 75) color = "\033[1;33m"
        printf "  %-22s %10s %10s %10s " color "%6s\033[0m  %s\n", $1,$2,$3,$4,$5,$6
    }'

# ── Section 6: Disk health summary ───────────────────────────────────────────
header "6. Low Space Warnings"

WARNED=0
while IFS= read -r line; do
    PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
    MNT=$(echo "$line" | awk '{print $6}')
    AVAIL=$(echo "$line" | awk '{print $4}')
    if [ "$PCT" -ge 90 ] 2>/dev/null; then
        echo -e "  ${RED}[CRITICAL]${RESET}  $MNT is ${PCT}% full — only $AVAIL left!"
        WARNED=1
    elif [ "$PCT" -ge 75 ] 2>/dev/null; then
        echo -e "  ${YELLOW}[WARNING] ${RESET}  $MNT is ${PCT}% full — only $AVAIL left"
        WARNED=1
    fi
done < <(df -h --output=size,used,avail,pcent,target -x tmpfs -x devtmpfs -x squashfs | tail -n +2)

if [ "$WARNED" -eq 0 ]; then
    echo -e "  ${GREEN}All filesystems are healthy.${RESET}"
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                   Done                           ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
