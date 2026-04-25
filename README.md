# pc-maker

Scripts and templates to set up a fresh Linux (Debian/Ubuntu) machine from scratch.

---

## Structure

```
pc-maker/
├── home/
│   └── user/
│       └── .bashrc                          ← shell aliases template
├── ossetup/
│   └── debian2debian/                       ← OS setup scripts for Debian/Ubuntu
│       ├── os_lookup.sh                     ← find or download an OS ISO
│       ├── boot_usbdrive.sh                 ← write ISO to USB (bootable)
│       ├── format_usbdrive.sh               ← format USB drive
│       ├── check_usbdrive.sh                ← verify USB drive detected
│       └── utility/                         ← individual app installers
│           ├── install_required_utility.sh  ← run all installers at once
│           ├── git_install.sh
│           ├── vim_install.sh
│           ├── xclip_for_copy.sh
│           ├── guake_for_terminal.sh
│           ├── chrome_install.sh
│           ├── vscode_install.sh
│           └── docker_install.sh
├── pchealth/                                ← system monitoring scripts
│   ├── disk_health.sh                       ← disk usage and storage report
│   └── system_info.sh                       ← full system overview
├── .gitignore
└── README.md
```

---

## Home Templates

Copy `.bashrc` to your home directory:

```bash
cp home/user/.bashrc ~/.bashrc
source ~/.bashrc
```

### Aliases

| Alias  | Command                        | Description              |
|--------|--------------------------------|--------------------------|
| `hs`   | `history`                      | Short history command    |
| `copy` | `xclip -selection clipboard`   | Pipe output to clipboard |

---

## OS Setup

### 1. ISO Lookup

Searches the current directory for the configured ISO. Downloads it automatically if not found.

```bash
bash ossetup/debian2debian/os_lookup.sh
```

Saves the ISO path to `/tmp/os_lookup_result.env` for use by other scripts.
Edit `ISO_NAME` and `ISO_URL` at the top of the script to target a different OS.

**Current config:** Linux Lite 7.8 64-bit

---

### 2. USB Boot Maker

Writes an OS ISO to a USB drive and makes it bootable. Uses `os_lookup.sh` automatically to find or download the ISO.

> **Warning** — all data on the USB will be erased.

```bash
sudo bash ossetup/debian2debian/boot_usbdrive.sh              # auto ISO lookup
sudo bash ossetup/debian2debian/boot_usbdrive.sh myfile.iso   # use specific ISO
```

Steps:
1. Finds or downloads the ISO via `os_lookup.sh`
2. Lists all drives — you pick the USB device
3. Requires typing `YES` to confirm
4. Unmounts any partitions on the USB
5. Writes with `dd bs=4M` and shows live progress
6. Syncs and confirms when done

---

### 3. USB Drive Formatter

Formats a USB drive with a chosen filesystem.

> **Warning** — all data on the USB will be erased.

```bash
sudo bash ossetup/debian2debian/format_usbdrive.sh
```

| # | Filesystem | Best for |
|---|------------|----------|
| 1 | **FAT32** ✅ preferred | General use — works on Windows, Mac, Linux. Files up to 4 GB. |
| 2 | exFAT | Files larger than 4 GB — works on Windows, Mac and Linux |
| 3 | ext4 | Linux-only data drives |
| 4 | NTFS | Windows-native, read/write on Linux too |

**Last used:** FAT32 (choice 1) — SanDisk 233.1G `/dev/sda`

---

## Utility Installers

### Install all at once

```bash
sudo bash ossetup/debian2debian/utility/install_required_utility.sh
```

Runs all installers in order, prints a pass/fail summary at the end.

### Individual installers

| Script | Installs |
|--------|----------|
| `git_install.sh` | Git version control |
| `vim_install.sh` | Vim text editor |
| `xclip_for_copy.sh` | xclip — pipe command output to clipboard |
| `guake_for_terminal.sh` | Guake drop-down terminal + autostart on login |
| `chrome_install.sh` | Google Chrome browser |
| `vscode_install.sh` | Visual Studio Code |
| `docker_install.sh` | Docker Engine + Compose plugin |

Each script is standalone — run any one individually:

```bash
sudo bash ossetup/debian2debian/utility/<script_name>.sh
```

---

## PC Health

### Disk Health

Storage usage report: space used/free per filesystem, top directories, largest files, inode usage, low-space warnings.

```bash
bash pchealth/disk_health.sh
```

| Section | What it shows |
|---------|--------------|
| Filesystem Overview | All mounts — size, used, free, % (color-coded) |
| Top Directories | Top 15 heaviest directories on the system |
| Home Breakdown | Space usage inside `~` |
| Largest Files | Top 10 biggest individual files |
| Inode Usage | Inode consumption per filesystem |
| Warnings | Red ≥ 90% full, yellow ≥ 75% full |

### System Info

Full system snapshot: OS, CPU, RAM, storage, network, GPU, processes, packages, temperatures.

```bash
bash pchealth/system_info.sh
```

| Section | What it shows |
|---------|--------------|
| OS & Kernel | Hostname, distro, kernel, uptime, last boot |
| CPU | Model, cores, threads, clock speed, load, usage % |
| Memory | RAM and swap — total, used, free, available |
| Storage | All filesystems — size, used, free, % |
| Network | Interfaces with IPs, gateway, DNS |
| GPU | Detected GPU via `lspci` |
| Processes | Total/running/sleeping, top 5 by CPU and memory |
| Packages | Count of dpkg / snap / flatpak installed |
| Temperatures | CPU/GPU temps via `sensors` |
| Logged-in Users | Currently active sessions |

---

## Notes

- `*.iso` files are excluded from git (see `.gitignore`)
- All scripts use `set -euo pipefail` — they stop immediately on any error
- Scripts that need root will tell you: `sudo bash <script>.sh`
