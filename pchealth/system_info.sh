#!/bin/bash
# system_info.sh — Full system information overview.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}$*${RESET}"; echo -e "${CYAN}$(printf '─%.0s' {1..50})${RESET}"; }
row()    { printf "  ${BOLD}%-22s${RESET} %s\n" "$1" "$2"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║             System Information                   ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo -e "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"

# ── Section 1: OS & Kernel ────────────────────────────────────────────────────
header "1. OS & Kernel"
row "Hostname"       "$(hostname)"
row "OS"             "$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
row "Kernel"         "$(uname -r)"
row "Architecture"   "$(uname -m)"
row "Uptime"         "$(uptime -p)"
row "Last boot"      "$(who -b | awk '{print $3, $4}')"

# ── Section 2: CPU ────────────────────────────────────────────────────────────
header "2. CPU"
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo | cut -d: -f2 | xargs)
CPU_CORES=$(grep -c "^processor" /proc/cpuinfo)
CPU_THREADS=$(grep "siblings" /proc/cpuinfo | head -1 | awk '{print $3}')
CPU_SPEED=$(grep -m1 "cpu MHz" /proc/cpuinfo | awk '{printf "%.0f MHz", $4}')
LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

row "Model"          "$CPU_MODEL"
row "Cores"          "$CPU_CORES"
row "Threads"        "${CPU_THREADS:-N/A}"
row "Clock speed"    "$CPU_SPEED"
row "Load avg"       "$LOAD  (1m / 5m / 15m)"

# CPU usage %
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%id,' 2>/dev/null || echo "0")
CPU_USAGE=$(echo "100 - ${CPU_IDLE:-0}" | bc 2>/dev/null || echo "N/A")
row "CPU usage"      "${CPU_USAGE}%"

# ── Section 3: Memory (RAM) ───────────────────────────────────────────────────
header "3. Memory (RAM)"
MEM_TOTAL=$(free -h | awk '/^Mem/ {print $2}')
MEM_USED=$(free -h  | awk '/^Mem/ {print $3}')
MEM_FREE=$(free -h  | awk '/^Mem/ {print $4}')
MEM_AVAIL=$(free -h | awk '/^Mem/ {print $7}')
MEM_PCT=$(free | awk '/^Mem/ {printf "%.1f", $3/$2*100}')

SWP_TOTAL=$(free -h | awk '/^Swap/ {print $2}')
SWP_USED=$(free -h  | awk '/^Swap/ {print $3}')
SWP_FREE=$(free -h  | awk '/^Swap/ {print $4}')

row "Total RAM"      "$MEM_TOTAL"
row "Used"           "$MEM_USED  (${MEM_PCT}%)"
row "Free"           "$MEM_FREE"
row "Available"      "$MEM_AVAIL"
row "Swap total"     "$SWP_TOTAL"
row "Swap used"      "$SWP_USED"
row "Swap free"      "$SWP_FREE"

# ── Section 4: Storage ────────────────────────────────────────────────────────
header "4. Storage"
df -h --output=source,size,used,avail,pcent,target \
    -x tmpfs -x devtmpfs -x squashfs \
    | awk '
    NR==1 { printf "  %-20s %6s %6s %6s %5s  %s\n", $1,$2,$3,$4,$5,$6; next }
    {
        pct=$5; gsub(/%/,"",pct)
        color="\033[0;32m"
        if (pct+0 >= 90) color="\033[0;31m"
        else if (pct+0 >= 75) color="\033[1;33m"
        printf "  %-20s %6s %6s %6s " color "%5s\033[0m  %s\n", $1,$2,$3,$4,$5,$6
    }'

# ── Section 5: Network ────────────────────────────────────────────────────────
header "5. Network"
row "Hostname"       "$(hostname -f 2>/dev/null || hostname)"

# Active interfaces
echo ""
ip -o addr show 2>/dev/null | awk '!/127.0.0.1|::1/ {
    printf "  %-22s %-15s %s\n", $2, $4, $9
}' | grep -v "^$" || echo "  No active interfaces found"

# Default gateway
GW=$(ip route | awk '/default/ {print $3; exit}')
echo ""
row "Default gateway" "${GW:-N/A}"

# DNS
DNS=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
row "DNS servers"    "${DNS:-N/A}"

# ── Section 6: GPU ────────────────────────────────────────────────────────────
header "6. GPU"
if command -v lspci &>/dev/null; then
    GPU=$(lspci 2>/dev/null | grep -iE "vga|3d|display" | sed 's/.*: //')
    if [ -n "$GPU" ]; then
        while IFS= read -r line; do
            row "GPU" "$line"
        done <<< "$GPU"
    else
        row "GPU" "Not detected via lspci"
    fi
else
    row "GPU" "lspci not available (install pciutils)"
fi

# ── Section 7: Processes ──────────────────────────────────────────────────────
header "7. Processes"
TOTAL_PROC=$(ps aux --no-headers | wc -l)
RUNNING=$(ps aux --no-headers | awk '$8=="R"' | wc -l)
SLEEPING=$(ps aux --no-headers | awk '$8~/S|D/' | wc -l)

row "Total"          "$TOTAL_PROC"
row "Running"        "$RUNNING"
row "Sleeping"       "$SLEEPING"

echo ""
echo -e "  ${BOLD}Top 5 by CPU:${RESET}"
ps aux --no-headers --sort=-%cpu | head -5 \
    | awk '{printf "  %-6s %-6s %-6s  %s\n", $1, $3"%", $4"%", $11}'

echo ""
echo -e "  ${BOLD}Top 5 by Memory:${RESET}"
ps aux --no-headers --sort=-%mem | head -5 \
    | awk '{printf "  %-6s %-6s %-6s  %s\n", $1, $3"%", $4"%", $11}'

# ── Section 8: Installed packages ────────────────────────────────────────────
header "8. Packages"
if command -v dpkg &>/dev/null; then
    row "Installed (dpkg)" "$(dpkg -l 2>/dev/null | grep -c '^ii')"
fi
if command -v snap &>/dev/null; then
    row "Snap packages"   "$(snap list 2>/dev/null | tail -n +2 | wc -l)"
fi
if command -v flatpak &>/dev/null; then
    row "Flatpak apps"    "$(flatpak list 2>/dev/null | wc -l)"
fi

# ── Section 9: System temperatures ───────────────────────────────────────────
header "9. Temperatures"
if command -v sensors &>/dev/null; then
    sensors 2>/dev/null | grep -E "°C|temp" | awk '{printf "  %s\n", $0}'
else
    echo -e "  ${YELLOW}sensors not available.${RESET}  Install with: sudo apt install lm-sensors"
fi

# ── Section 10: Users ─────────────────────────────────────────────────────────
header "10. Logged-in Users"
who | awk '{printf "  %-15s %-10s %s %s\n", $1, $2, $3, $4}'

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║                    Done                          ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════╝${RESET}"
echo ""
