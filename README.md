# pc-maker

Scripts and templates to set up a fresh Linux machine from scratch.

---

## Structure

```
pc-maker/
├── home/
│   └── user/                        ← template files copied to user home (~/)
│       └── .bashrc
├── ossetup/
│   └── debian/                      ← OS setup scripts for Debian/Ubuntu
│       ├── check_usb_found_debian.sh
│       ├── boot_usb.sh
│       └── format_usbdrive.sh
└── README.md
```

---

## Home templates

| File       | Purpose                        |
|------------|--------------------------------|
| `.bashrc`  | Shell aliases and configuration |

### Aliases included

| Alias  | Command                            | Description                  |
|--------|------------------------------------|------------------------------|
| `hs`   | `history`                          | Short history command        |
| `copy` | `xclip -selection clipboard`       | Pipe output to clipboard     |

---

## How to apply

Copy the `.bashrc` template to your home directory:

```bash
cp home/user/.bashrc ~/.bashrc
source ~/.bashrc
```

---

---

## USB Boot Maker

Write an OS ISO image to a USB drive and make it bootable.

> **Warning** — all data on the USB will be erased.

```bash
sudo bash ossetup/debian/boot_usb.sh                                    # interactive prompts
sudo bash ossetup/debian/boot_usb.sh ~/Downloads/ubuntu.iso /dev/sdb   # direct arguments
```

**Steps it runs:**
1. Asks for the ISO file path
2. Lists all drives — you pick the USB device
3. Requires typing `YES` to confirm
4. Unmounts any partitions on the USB
5. Writes with `dd` and shows live progress
6. Syncs and confirms when done

---

## USB Drive Formatter

Format a USB drive with a chosen filesystem.

> **Warning** — all data on the USB will be erased.

```bash
sudo bash ossetup/debian2debian/format_usbdrive.sh
```

### Filesystem choices

| # | Filesystem | Best for |
|---|-----------|----------|
| 1 | **FAT32** ✅ preferred | General use — works on Windows, Mac, Linux. Files up to 4 GB. |
| 2 | exFAT | Files larger than 4 GB — works on Windows, Mac, and Linux |
| 3 | ext4 | Linux-only data drives |
| 4 | NTFS | Windows-native, read/write on Linux too |

**Last used:** FAT32 (choice 1) — SanDisk 233.1G `/dev/sda`

---

## Requirements

```bash
sudo apt install xclip    # needed for the copy alias
```
