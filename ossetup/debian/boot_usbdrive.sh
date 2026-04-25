#!/bin/bash
# boot_usbdrive.sh — Write an OS ISO image to a USB drive (makes it bootable).
# Uses os_lookup.sh to find or download the ISO automatically.
# Uses `dd` under the hood. ALL data on the USB will be erased.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    error "This script must run as root."
    echo "  Run: sudo bash usbboot.sh"
    exit 1
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        USB Boot Maker                ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── Step 1: Resolve ISO via os_lookup.sh ─────────────────────────────────────
echo -e "${BOLD}Step 1 — ISO lookup${RESET}"

if [ -n "${1:-}" ] && [ -f "$1" ]; then
    # ISO path passed directly as argument — skip lookup
    ISO_PATH="$1"
    success "ISO: $ISO_PATH  ($(du -h "$ISO_PATH" | cut -f1))"
else
    bash "$SCRIPT_DIR/os_lookup.sh"
    source /tmp/os_lookup_result.env
fi

if [ ! -f "$ISO_PATH" ]; then
    error "ISO not found: $ISO_PATH"
    exit 1
fi

ISO_SIZE=$(du -h "$ISO_PATH" | cut -f1)
success "Using ISO: $ISO_PATH  ($ISO_SIZE)"

# ── Step 2: List USB drives ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Step 2 — Available drives${RESET}"
echo ""
lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,MOUNTPOINT \
    | grep -E "^NAME|disk" | head -20
echo ""
warn "Only select a USB drive. Writing to the wrong device will destroy your data."
echo ""

USB_DEVICE="${2:-}"

if [ -z "$USB_DEVICE" ]; then
    read -rp "  Enter USB device (e.g. /dev/sdb): " USB_DEVICE
fi

# Normalize — strip partition number if given (e.g. /dev/sdb1 → /dev/sdb)
USB_DEVICE=$(echo "$USB_DEVICE" | sed 's/[0-9]*$//')

if [ ! -b "$USB_DEVICE" ]; then
    error "Device not found: $USB_DEVICE"
    exit 1
fi

# Reject system disk (heuristic: check if it has a mounted / partition)
ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || true)
if [ -n "$ROOT_DISK" ] && [[ "$USB_DEVICE" == *"$ROOT_DISK"* ]]; then
    error "You selected the system disk ($USB_DEVICE). Aborted for safety."
    exit 1
fi

DEVICE_INFO=$(lsblk -no SIZE,MODEL "$USB_DEVICE" 2>/dev/null | head -1 || echo "unknown")
success "Target: $USB_DEVICE  ($DEVICE_INFO)"

# ── Step 3: Confirm ───────────────────────────────────────────────────────────
echo ""
echo -e "${RED}${BOLD}⚠  WARNING — ALL DATA ON $USB_DEVICE WILL BE PERMANENTLY ERASED.${RESET}"
echo ""
echo -e "  ISO     : $ISO_PATH  ($ISO_SIZE)"
echo -e "  Device  : $USB_DEVICE  ($DEVICE_INFO)"
echo ""
read -rp "  Type YES to confirm and start writing: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    info "Cancelled."
    exit 0
fi

# ── Step 4: Unmount all partitions on target ──────────────────────────────────
echo ""
info "Unmounting any mounted partitions on $USB_DEVICE..."
for PART in $(lsblk -lno NAME "$USB_DEVICE" | tail -n +2); do
    if mountpoint -q "/dev/$PART" 2>/dev/null || \
       grep -q "/dev/$PART" /proc/mounts 2>/dev/null; then
        umount "/dev/$PART" && info "  Unmounted /dev/$PART" || \
        warn "  Could not unmount /dev/$PART — continuing anyway."
    fi
done

# ── Step 5: Write ISO ─────────────────────────────────────────────────────────
echo ""
info "Writing ISO to $USB_DEVICE — do not remove the USB drive..."
echo ""

dd if="$ISO_PATH" of="$USB_DEVICE" bs=4M status=progress oflag=sync

echo ""
success "Write complete!"

# ── Step 6: Sync and done ─────────────────────────────────────────────────────
info "Flushing write cache..."
sync
success "USB drive is ready to boot."
echo ""
echo -e "  ${BOLD}Next step${RESET}  Safely remove the USB, then boot from it in BIOS/UEFI."
echo ""
