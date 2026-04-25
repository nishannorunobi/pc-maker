#!/bin/bash
# check_usb_found_debian.sh — Detect plugged-in USB drives and show their name and path.

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

echo ""
echo -e "${BOLD}╔══════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║      USB Drive Detector              ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════╝${RESET}"
echo ""

# Find USB drives via transport type = usb
USB_DEVICES=$(lsblk -o NAME,SIZE,TRAN,VENDOR,MODEL,MOUNTPOINT -d \
    | awk 'NR==1 || $3=="usb"')

USB_COUNT=$(lsblk -d -o TRAN | grep -c "^usb" || true)

if [ "$USB_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}No USB drives detected.${RESET}"
    echo "  Plug in your USB and run this script again."
    echo ""
    exit 0
fi

echo -e "${GREEN}Found $USB_COUNT USB drive(s):${RESET}"
echo ""
printf "  %-12s %-10s %-20s %-30s %s\n" "DEVICE" "SIZE" "VENDOR" "MODEL" "MOUNTPOINT"
printf "  %-12s %-10s %-20s %-30s %s\n" "──────" "────" "──────" "─────" "──────────"

lsblk -d -o NAME,SIZE,TRAN,VENDOR,MODEL,MOUNTPOINT | awk 'NR>1 && $3=="usb" {
    dev  = "/dev/" $1
    size = $2
    vend = $4 ? $4 : "—"
    model= $5 ? $5 : "—"
    mnt  = $6 ? $6 : "(not mounted)"
    printf "  %-12s %-10s %-20s %-30s %s\n", dev, size, vend, model, mnt
}'

echo ""

# Also show partitions on each USB device
echo -e "${BOLD}Partitions:${RESET}"
echo ""
lsblk -d -o NAME,TRAN | awk 'NR>1 && $2=="usb" {print $1}' | while read -r DEV; do
    echo -e "  ${CYAN}/dev/$DEV${RESET}"
    lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT "/dev/$DEV" | sed 's/^/    /'
    echo ""
done
