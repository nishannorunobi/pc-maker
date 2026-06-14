#!/bin/bash
# troubleshoot_restart_loing_window.sh — Diagnose and fix login window (LightDM) black screen on boot.
# Tested on: Linux Lite (Ubuntu-based), Intel Iris Xe, LightDM + XFCE
set -euo pipefail

# ── Mirror logging ─────────────────────────────────────────────────────────────
_WS_ROOT="$(d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; while [ ! -d "$d/mountspace" ] && [ "$d" != "/" ]; do d="$(dirname "$d")"; done; echo "$d")"
if [ -f "$_WS_ROOT/init/create_logging_path.sh" ]; then
    source "$_WS_ROOT/init/create_logging_path.sh"
    setup_logging
fi
# ──────────────────────────────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

header() { echo -e "\n${BOLD}$*${RESET}"; echo -e "${CYAN}$(printf '─%.0s' {1..55})${RESET}"; }
row()    { printf "  ${BOLD}%-28s${RESET} %s\n" "$1" "$2"; }
ok()     { echo -e "  ${GREEN}[OK]${RESET}    $*"; }
warn()   { echo -e "  ${YELLOW}[WARN]${RESET}  $*"; }
fail()   { echo -e "  ${RED}[FAIL]${RESET}  $*"; }
fix()    { echo -e "  ${CYAN}[FIX]${RESET}   $*"; }

ISSUES=0

echo ""
echo -e "${BOLD}╔═════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        Login Window Black Screen Troubleshooter     ║${RESET}"
echo -e "${BOLD}╚═════════════════════════════════════════════════════╝${RESET}"
echo -e "  Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo -e "  Run as:    $(whoami)  |  Host: $(hostname)"

# ── Section 1: LightDM autologin user check ───────────────────────────────────
# ROOT CAUSE #1 — This caused the black screen on this machine.
# LightDM had autologin-user=linux (the Live USB user) after Linux Lite install.
# User 'linux' doesn't exist on the installed system, so LightDM failed silently,
# showed a black screen while recovering, then eventually fell back to the greeter.
header "1. LightDM Autologin Config  ← ROOT CAUSE CHECK"

CONF="/etc/lightdm/lightdm.conf"
if [ ! -f "$CONF" ]; then
    warn "LightDM config not found at $CONF"
else
    AUTOLOGIN_USER=$(grep -i "^autologin-user=" "$CONF" 2>/dev/null | cut -d= -f2 | xargs || echo "")

    if [ -n "$AUTOLOGIN_USER" ]; then
        row "autologin-user" "$AUTOLOGIN_USER"
        if id "$AUTOLOGIN_USER" &>/dev/null; then
            ok "Autologin user '$AUTOLOGIN_USER' exists on this system."
        else
            fail "Autologin user '$AUTOLOGIN_USER' does NOT exist!"
            echo ""
            echo -e "  ${RED}This is the black screen cause.${RESET} LightDM tries to auto-login"
            echo -e "  as '$AUTOLOGIN_USER' on every boot, fails, then shows a black screen"
            echo -e "  while recovering."
            echo ""
            echo -e "  ${BOLD}Fix A — Set autologin to your real username:${RESET}"
            echo "    sudo sed -i 's/^autologin-user=.*/autologin-user=$(whoami)/' $CONF"
            echo ""
            echo -e "  ${BOLD}Fix B — Disable autologin entirely (show login screen):${RESET}"
            echo "    sudo sed -i '/^autologin-user/d; /^autologin-user-timeout/d; /^autologin-session/d' $CONF"
            ISSUES=$((ISSUES + 1))
        fi
    else
        ok "No autologin configured — greeter shows normally."
    fi

    AUTOLOGIN_TIMEOUT=$(grep -i "^autologin-user-timeout=" "$CONF" 2>/dev/null | cut -d= -f2 | xargs || echo "")
    AUTOLOGIN_SESSION=$(grep -i "^autologin-session=" "$CONF" 2>/dev/null | cut -d= -f2 | xargs || echo "")
    [ -n "$AUTOLOGIN_TIMEOUT" ] && row "autologin-user-timeout" "$AUTOLOGIN_TIMEOUT"
    [ -n "$AUTOLOGIN_SESSION" ] && row "autologin-session" "$AUTOLOGIN_SESSION"
fi

# ── Section 2: LightDM service status ─────────────────────────────────────────
header "2. LightDM Service Status"

STATUS=$(systemctl is-active lightdm 2>/dev/null || echo "unknown")
ENABLED=$(systemctl is-enabled lightdm 2>/dev/null || echo "unknown")
RESTARTS=$(systemctl show lightdm -p NRestarts --value 2>/dev/null || echo "?")

row "Active state"     "$STATUS"
row "Enabled at boot"  "$ENABLED"
row "Restart count"    "$RESTARTS"

if [ "$STATUS" = "active" ]; then
    ok "LightDM is running."
else
    fail "LightDM is NOT running (state: $STATUS)"
    echo ""
    echo -e "  ${BOLD}Fix:${RESET}"
    echo "    sudo systemctl restart lightdm"
    ISSUES=$((ISSUES + 1))
fi

echo ""
echo -e "  ${BOLD}Recent journal (last 8 lines):${RESET}"
journalctl -u lightdm --no-pager -n 8 2>/dev/null | sed 's/^/  /'

# ── Section 3: networking.service boot delay ──────────────────────────────────
# ROOT CAUSE #2 — networking.service was taking 34.9 seconds at boot on this machine.
# It's a legacy SysV-style service. NetworkManager already handles all networking.
# Having both enabled causes a long boot hang before anything graphical starts.
header "3. Legacy networking.service  ← BOOT DELAY CHECK"

NET_STATE=$(systemctl is-active networking 2>/dev/null || echo "not-found")
NET_ENABLED=$(systemctl is-enabled networking 2>/dev/null || echo "not-found")
NET_MASKED=$(systemctl is-enabled networking 2>/dev/null || echo "not-found")

row "networking.service state"   "$NET_STATE"
row "networking.service enabled" "$NET_ENABLED"

if [ "$NET_ENABLED" = "masked" ]; then
    ok "networking.service is masked — no boot delay."
elif [ "$NET_ENABLED" = "enabled" ] || [ "$NET_STATE" = "active" ]; then
    warn "networking.service is active/enabled alongside NetworkManager."
    echo ""
    echo -e "  This legacy service reads /etc/network/interfaces and often"
    echo -e "  hangs for 30+ seconds waiting for interfaces that don't exist."
    echo -e "  NetworkManager already manages all your network — this is redundant."
    echo ""
    echo -e "  ${BOLD}Fix — mask it permanently (safe, NetworkManager takes over):${RESET}"
    echo "    sudo systemctl mask networking.service"
    echo ""
    echo -e "  ${BOLD}Estimated boot time saved: ~30 seconds${RESET}"
    ISSUES=$((ISSUES + 1))
else
    ok "networking.service not running (state: $NET_STATE)"
fi

# Check NetworkManager (should be running)
NM_STATE=$(systemctl is-active NetworkManager 2>/dev/null || echo "not-found")
row "NetworkManager state"       "$NM_STATE"
if [ "$NM_STATE" = "active" ]; then
    ok "NetworkManager is handling network — this is correct."
else
    warn "NetworkManager is not active (state: $NM_STATE)"
fi

# ── Section 4: Plymouth → LightDM handoff ─────────────────────────────────────
header "4. Plymouth Boot Splash Handoff"

CMDLINE=$(cat /proc/cmdline 2>/dev/null)
echo "  Kernel cmdline: $CMDLINE" | fold -s -w 72 | sed '2,$s/^/    /'
echo ""

if echo "$CMDLINE" | grep -q "splash"; then
    row "Plymouth splash" "enabled"
    if echo "$CMDLINE" | grep -q "vt.handoff"; then
        VT=$(echo "$CMDLINE" | grep -o "vt.handoff=[0-9]*" | cut -d= -f2)
        row "VT handoff" "VT$VT (expected: VT7 for X)"
        if [ "$VT" = "7" ]; then
            ok "vt.handoff=7 is correct for LightDM/X."
        else
            warn "vt.handoff=$VT — expected 7. May cause black screen on Plymouth exit."
            ISSUES=$((ISSUES + 1))
        fi
    else
        warn "vt.handoff not set — Plymouth may not release screen to LightDM correctly."
        echo ""
        echo -e "  ${BOLD}Fix — add vt.handoff=7 to GRUB_CMDLINE_LINUX_DEFAULT in /etc/default/grub:${RESET}"
        echo "    sudo nano /etc/default/grub"
        echo "    # Change to: GRUB_CMDLINE_LINUX_DEFAULT=\"quiet splash vt.handoff=7\""
        echo "    sudo update-grub"
        ISSUES=$((ISSUES + 1))
    fi
else
    warn "Plymouth splash not enabled. Boot may show brief black screen anyway."
fi

# ── Section 5: VMware kernel modules ──────────────────────────────────────────
header "5. VMware Service  (non-critical)"

VMW_STATE=$(systemctl is-active vmware 2>/dev/null || echo "not-found")
VMW_ENABLED=$(systemctl is-enabled vmware 2>/dev/null || echo "not-found")

row "vmware.service state"   "$VMW_STATE"
row "vmware.service enabled" "$VMW_ENABLED"

if [ "$VMW_STATE" = "failed" ]; then
    warn "VMware modules are not loaded for the current kernel."
    echo ""
    echo -e "  The 'Virtual machine monitor' and 'Virtual ethernet' modules"
    echo -e "  need to be recompiled after every kernel update."
    echo -e "  This does NOT cause the black screen but shows as a failed service."
    echo ""
    echo -e "  ${BOLD}Fix — recompile VMware kernel modules:${RESET}"
    echo "    sudo vmware-modconfig --console --install-all"
    echo ""
    echo -e "  ${BOLD}If you no longer use VMware, disable it entirely:${RESET}"
    echo "    sudo systemctl disable vmware"
    echo "    sudo systemctl mask vmware"
    ISSUES=$((ISSUES + 1))
elif [ "$VMW_STATE" = "active" ]; then
    ok "VMware service is running."
else
    ok "VMware service state: $VMW_STATE"
fi

# ── Section 6: GPU & display ──────────────────────────────────────────────────
header "6. GPU & Display"

GPU=$(lspci 2>/dev/null | grep -iE "vga|display|3d" | sed 's/.*: //')
if [ -n "$GPU" ]; then
    while IFS= read -r line; do row "GPU" "$line"; done <<< "$GPU"
else
    warn "No GPU detected via lspci"
fi

RENDERER=$(glxinfo 2>/dev/null | grep "OpenGL renderer" | cut -d: -f2 | xargs || echo "glxinfo not available")
row "OpenGL renderer" "$RENDERER"

if echo "$RENDERER" | grep -qi "mesa\|llvm\|intel\|amd\|nvidia"; then
    ok "GPU driver is active and rendering."
else
    warn "Could not confirm GPU renderer — may be a driver issue."
fi

# ── Section 7: Quick recovery commands ────────────────────────────────────────
header "7. Quick Recovery Commands  (run from TTY if screen is black)"

echo ""
echo -e "  ${BOLD}If you see a black screen on boot — press Ctrl+Alt+F2 to get a TTY,${RESET}"
echo -e "  ${BOLD}log in as nishan, then run:${RESET}"
echo ""
echo -e "  ${YELLOW}# Restart LightDM immediately (brings back login screen):${RESET}"
echo "  sudo systemctl restart lightdm"
echo ""
echo -e "  ${YELLOW}# If LightDM is stuck, kill it and restart:${RESET}"
echo "  sudo pkill -HUP lightdm && sudo systemctl restart lightdm"
echo ""
echo -e "  ${YELLOW}# Check why it failed:${RESET}"
echo "  sudo journalctl -u lightdm -n 30 --no-pager"
echo ""
echo -e "  ${YELLOW}# Force return to VT7 (where the login screen lives):${RESET}"
echo "  sudo chvt 7"

# ── Section 8: Permanent fixes summary ────────────────────────────────────────
header "8. Permanent Fix Commands  (run once, survives reboots)"

echo ""
echo -e "  ${BOLD}Fix 1 — Correct the autologin user (replace 'nishan' if different):${RESET}"
echo "  sudo sed -i 's/^autologin-user=.*/autologin-user=nishan/' /etc/lightdm/lightdm.conf"
echo ""
echo -e "  ${BOLD}Fix 2 — Remove autologin entirely (always show the login screen):${RESET}"
echo "  sudo sed -i '/^autologin-user/d; /^autologin-user-timeout/d; /^autologin-session/d' /etc/lightdm/lightdm.conf"
echo ""
echo -e "  ${BOLD}Fix 3 — Eliminate 34-second networking.service boot hang:${RESET}"
echo "  sudo systemctl mask networking.service"
echo ""
echo -e "  ${BOLD}Fix 4 — Rebuild VMware kernel modules after kernel update:${RESET}"
echo "  sudo vmware-modconfig --console --install-all"
echo ""
echo -e "  ${BOLD}Fix 5 — Disable VMware entirely if no longer needed:${RESET}"
echo "  sudo systemctl disable --now vmware && sudo systemctl mask vmware"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}╔═════════════════════════════════════════════════════╗${RESET}"
if [ "$ISSUES" -eq 0 ]; then
    echo -e "${BOLD}║   ${GREEN}All checks passed — system looks healthy.${RESET}${BOLD}        ║${RESET}"
else
    echo -e "${BOLD}║   ${YELLOW}$ISSUES issue(s) found — see sections above for fixes.${RESET}${BOLD}  ║${RESET}"
fi
echo -e "${BOLD}╚═════════════════════════════════════════════════════╝${RESET}"
echo ""
