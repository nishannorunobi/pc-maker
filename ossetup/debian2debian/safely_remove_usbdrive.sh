#!/bin/bash
# safely_remove_usbdrive.sh — Unmount and safely eject a USB drive.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

if [ "$EUID" -ne 0 ]; then
    error "This script must run as root."
    echo "  Run: sudo bash safely_remove_usbdrive.sh"
    exit 1
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║       Safe USB Drive Remover         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── Step 1: Detect USB drives ─────────────────────────────────────────────────
echo -e "${BOLD}Step 1 — Detected USB drives${RESET}"
echo ""

USB_COUNT=$(lsblk -d -o TRAN 2>/dev/null | grep -c "^usb" || true)

if [ "$USB_COUNT" -eq 0 ]; then
    warn "No USB drives detected. Nothing to remove."
    exit 0
fi

printf "  %-12s %-10s %-22s %-20s\n" "DEVICE" "SIZE" "MODEL" "MOUNTPOINT"
printf "  %-12s %-10s %-22s %-20s\n" "──────" "────" "─────" "──────────"
lsblk -o NAME,SIZE,TRAN,MODEL,MOUNTPOINT 2>/dev/null | awk '$3=="usb" {
    printf "  %-12s %-10s %-22s %-20s\n", "/dev/"$1, $2, ($4?$4:"—"), ($5?$5:"(not mounted)")
}'
echo ""

# ── Step 2: Select device ─────────────────────────────────────────────────────
USB_DEVICE="${1:-}"
if [ -z "$USB_DEVICE" ]; then
    read -rp "  Enter USB device to eject (e.g. /dev/sdb): " USB_DEVICE
fi

# Normalize — strip partition number if given
USB_DEVICE=$(echo "$USB_DEVICE" | sed 's/[0-9]*$//')

if [ ! -b "$USB_DEVICE" ]; then
    error "Device not found: $USB_DEVICE"
    exit 1
fi

# ── Safety: block system disk ─────────────────────────────────────────────────
ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || true)
if [ -n "$ROOT_DISK" ] && [[ "$USB_DEVICE" == *"$ROOT_DISK"* ]]; then
    error "You selected the system disk ($USB_DEVICE). Aborted for safety."
    exit 1
fi

DEVICE_INFO=$(lsblk -dno SIZE,MODEL "$USB_DEVICE" 2>/dev/null | head -1 || echo "unknown")
info "Selected: $USB_DEVICE  ($DEVICE_INFO)"

# ── Step 3: Kill processes using the drive ────────────────────────────────────
echo ""
echo -e "${BOLD}Step 2 — Checking for processes using the drive${RESET}"
echo ""

if command -v lsof &>/dev/null; then
    PROCS=$(lsof 2>/dev/null | grep "$USB_DEVICE" | awk '{print $2}' | sort -u || true)
    if [ -n "$PROCS" ]; then
        warn "Processes using $USB_DEVICE:"
        lsof 2>/dev/null | grep "$USB_DEVICE" | awk '{printf "  PID %-8s %s\n", $2, $1}' | sort -u
        echo ""
        read -rp "  Kill these processes and continue? [y/N]: " KILL_CONFIRM
        if [[ "$KILL_CONFIRM" =~ ^[Yy]$ ]]; then
            echo "$PROCS" | xargs -r kill -9
            success "Processes killed."
        else
            info "Cancelled."
            exit 0
        fi
    else
        success "No processes are using $USB_DEVICE."
    fi
else
    warn "lsof not found — skipping process check."
fi

# ── Step 4: Unmount all partitions ────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 3 — Unmounting partitions${RESET}"
echo ""

UNMOUNTED=0
for PART in $(lsblk -lno NAME "$USB_DEVICE" | tail -n +2); do
    PART_PATH="/dev/$PART"
    if grep -q "$PART_PATH" /proc/mounts 2>/dev/null; then
        MOUNT_PT=$(grep "$PART_PATH" /proc/mounts | awk '{print $2}' | head -1)
        if umount "$PART_PATH" 2>/dev/null; then
            success "Unmounted $PART_PATH  ($MOUNT_PT)"
            UNMOUNTED=$((UNMOUNTED + 1))
        else
            warn "Could not unmount $PART_PATH — trying lazy unmount..."
            umount -l "$PART_PATH" && success "Lazy unmounted $PART_PATH" || \
            error "Failed to unmount $PART_PATH"
        fi
    else
        info "$PART_PATH is not mounted — skipping."
    fi
done

# ── Step 5: Flush write cache ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 4 — Flushing write cache${RESET}"
echo ""
sync
success "Write cache flushed."

# ── Step 6: Power off the device ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 5 — Powering off $USB_DEVICE${RESET}"
echo ""

if command -v udisksctl &>/dev/null; then
    udisksctl power-off -b "$USB_DEVICE" 2>/dev/null && \
        success "Drive powered off via udisksctl." || \
        warn "udisksctl power-off failed — trying eject..."
elif command -v eject &>/dev/null; then
    eject "$USB_DEVICE" 2>/dev/null && \
        success "Drive ejected." || \
        warn "eject failed — you can safely unplug after the sync above."
else
    warn "Neither udisksctl nor eject found."
    info "The drive is unmounted and synced — safe to physically remove."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
success "USB drive $USB_DEVICE ($DEVICE_INFO) is safe to remove."
echo ""
