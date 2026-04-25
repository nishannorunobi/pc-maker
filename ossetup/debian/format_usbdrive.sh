#!/bin/bash
# format_usbdrive.sh — Format a USB drive with a chosen filesystem.
# ALL data on the USB will be erased.
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Root check ────────────────────────────────────────────────────────────────
if [ "$EUID" -ne 0 ]; then
    error "This script must run as root."
    echo "  Run: sudo bash format_usbdrive.sh"
    exit 1
fi

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║        USB Drive Formatter           ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# ── Step 1: Show USB drives ───────────────────────────────────────────────────
echo -e "${BOLD}Detected USB drives:${RESET}"
echo ""

USB_COUNT=$(lsblk -d -o TRAN | grep -c "^usb" || true)

if [ "$USB_COUNT" -eq 0 ]; then
    error "No USB drives detected. Plug in your USB and try again."
    exit 1
fi

printf "  %-12s %-10s %-20s %-20s\n" "DEVICE" "SIZE" "MODEL" "MOUNTPOINT"
printf "  %-12s %-10s %-20s %-20s\n" "──────" "────" "─────" "──────────"
lsblk -d -o NAME,SIZE,TRAN,MODEL,MOUNTPOINT | awk 'NR>1 && $3=="usb" {
    printf "  %-12s %-10s %-20s %-20s\n", "/dev/"$1, $2, ($4?$4:"—"), ($5?$5:"(not mounted)")
}'
echo ""

# ── Step 2: Select device ─────────────────────────────────────────────────────
read -rp "Enter USB device to format (e.g. /dev/sdb): " USB_DEVICE
USB_DEVICE=$(echo "$USB_DEVICE" | sed 's/[0-9]*$//')

if [ ! -b "$USB_DEVICE" ]; then
    error "Device not found: $USB_DEVICE"
    exit 1
fi

# Block system disk
ROOT_DISK=$(lsblk -no PKNAME "$(findmnt -n -o SOURCE /)" 2>/dev/null || true)
if [ -n "$ROOT_DISK" ] && [[ "$USB_DEVICE" == *"$ROOT_DISK"* ]]; then
    error "You selected the system disk ($USB_DEVICE). Aborted for safety."
    exit 1
fi

DEVICE_INFO=$(lsblk -dno SIZE,MODEL "$USB_DEVICE" 2>/dev/null | head -1)
success "Selected: $USB_DEVICE  ($DEVICE_INFO)"

# ── Step 3: Choose filesystem ─────────────────────────────────────────────────
echo ""
echo -e "${BOLD}Choose filesystem:${RESET}"
echo "  1) FAT32   — best compatibility (Windows, Mac, Linux, USB boot)"
echo "  2) exFAT   — large files (>4GB), works on Windows and Mac"
echo "  3) ext4    — Linux only, best for Linux data drives"
echo "  4) NTFS    — Windows native, read/write on Linux too"
echo ""
read -rp "Enter choice [1-4]: " FS_CHOICE

case "$FS_CHOICE" in
    1) FS_TYPE="fat32";  MKFS_CMD="mkfs.vfat -F 32" ;;
    2) FS_TYPE="exfat";  MKFS_CMD="mkfs.exfat"       ;;
    3) FS_TYPE="ext4";   MKFS_CMD="mkfs.ext4 -F"     ;;
    4) FS_TYPE="ntfs";   MKFS_CMD="mkfs.ntfs -f"     ;;
    *)
        error "Invalid choice."
        exit 1 ;;
esac

# ── Step 4: Label ─────────────────────────────────────────────────────────────
echo ""
read -rp "Enter a label for the drive (leave blank to skip): " USB_LABEL

# ── Step 5: Confirm ───────────────────────────────────────────────────────────
echo ""
echo -e "${RED}${BOLD}⚠  WARNING — ALL DATA ON $USB_DEVICE WILL BE PERMANENTLY ERASED.${RESET}"
echo ""
echo -e "  Device     : $USB_DEVICE  ($DEVICE_INFO)"
echo -e "  Filesystem : $FS_TYPE"
echo -e "  Label      : ${USB_LABEL:-(none)}"
echo ""
read -rp "  Type YES to confirm: " CONFIRM

if [ "$CONFIRM" != "YES" ]; then
    info "Cancelled."
    exit 0
fi

# ── Step 6: Unmount all partitions ────────────────────────────────────────────
echo ""
info "Unmounting partitions on $USB_DEVICE..."
for PART in $(lsblk -lno NAME "$USB_DEVICE" | tail -n +2); do
    if grep -q "/dev/$PART" /proc/mounts 2>/dev/null; then
        umount "/dev/$PART" && info "  Unmounted /dev/$PART" || \
        warn "  Could not unmount /dev/$PART — continuing."
    fi
done

# ── Step 7: Wipe partition table ──────────────────────────────────────────────
info "Wiping existing partition table..."
wipefs -a "$USB_DEVICE" -q
success "  Partition table cleared."

# ── Step 8: Create new partition table + single partition ─────────────────────
info "Creating new MBR partition table and partition..."
parted -s "$USB_DEVICE" mklabel msdos
parted -s "$USB_DEVICE" mkpart primary 1MiB 100%
PARTITION="${USB_DEVICE}1"
sleep 1  # wait for kernel to register new partition
success "  Partition: $PARTITION"

# ── Step 9: Format ────────────────────────────────────────────────────────────
info "Formatting $PARTITION as $FS_TYPE..."

if [ -n "$USB_LABEL" ]; then
    case "$FS_TYPE" in
        fat32) $MKFS_CMD -n "$USB_LABEL" "$PARTITION" ;;
        exfat) $MKFS_CMD -n "$USB_LABEL" "$PARTITION" ;;
        ext4)  $MKFS_CMD -L "$USB_LABEL" "$PARTITION" ;;
        ntfs)  $MKFS_CMD -L "$USB_LABEL" "$PARTITION" ;;
    esac
else
    $MKFS_CMD "$PARTITION"
fi

sync
success "Format complete."

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
success "USB drive is ready!"
echo ""
echo -e "  ${BOLD}Device     ${RESET}  $PARTITION"
echo -e "  ${BOLD}Filesystem ${RESET}  $FS_TYPE"
echo -e "  ${BOLD}Label      ${RESET}  ${USB_LABEL:-(none)}"
echo -e "  ${BOLD}Size       ${RESET}  $(lsblk -dno SIZE "$PARTITION" 2>/dev/null || echo '—')"
echo ""
