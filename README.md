
<div align="center">

```
 █████╗ ██████╗  ██████╗██╗  ██╗    ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
██╔══██╗██╔══██╗██╔════╝██║  ██║    ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
███████║██████╔╝██║     ███████║    ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝ 
██╔══██║██╔══██╗██║     ██╔══██║    ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗ 
██║  ██║██║  ██║╚██████╗██║  ██║    ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
```

### **Microsoft Surface Pro 8 — Arch Linux Install Script**
*Gaming-optimized · COSMIC Desktop · linux-surface kernel · Steam-ready*

---

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Surface Pro 8](https://img.shields.io/badge/Surface_Pro_8-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)
![COSMIC DE](https://img.shields.io/badge/COSMIC_Desktop-5E35B1?style=for-the-badge&logo=linux&logoColor=white)
![Steam](https://img.shields.io/badge/Steam-000000?style=for-the-badge&logo=steam&logoColor=white)
![Shell](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)

</div>

---

## 🎯 What Is This?

A **single-script, fully automated Arch Linux installer** purpose-built for the **Microsoft Surface Pro 8**. Boot the Arch ISO, run one command, walk away. When you come back you'll have a complete, gaming-ready system with the COSMIC desktop environment, the `linux-surface` kernel, Steam, and Phantom Browser — tuned specifically for the Surface Pro 8's hardware.

No hand-holding through `pacstrap` steps. No forgotten packages. No rebooting into a broken system. Just fill in your username and password at the top of the script, run it, and reboot.

---

## 💻 Target Hardware

| Component | Spec |
|---|---|
| 🖥️ **Device** | Microsoft Surface Pro 8 |
| 🧠 **CPU** | Intel Core i5-1135G7 (11th Gen Tiger Lake) |
| 🎮 **GPU** | Intel Iris Xe — Tiger Lake-LP GT2 |
| 🧩 **RAM** | 8 GB LPDDR4x |
| 💾 **Storage** | NVMe SSD (auto-detected) |
| 🖱️ **Input** | Surface Touch + Pen via `iptsd` |

---

## ⚡ Quickstart

> **Prerequisites:** Boot the official [Arch Linux ISO](https://archlinux.org/download/), connect to the internet via `iwctl` or USB-C Ethernet, then:

```bash
# 1. Download the script
curl -O https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/surface_pro8_arch_install.sh

# 2. Open it and fill in your username, password, and timezone
nano surface_pro8_arch_install.sh

# 3. Make it executable and run
chmod +x surface_pro8_arch_install.sh && bash surface_pro8_arch_install.sh
```

> ⚠️ **This will erase your entire disk.** The script asks for confirmation before touching anything. Double-check your disk target before typing `yes`.

---

## 🗂️ What The Script Does — Step by Step

```
┌─────────────────────────────────────────────────────┐
│  🔍  Safety checks — UEFI mode, network, passwords  │
│  💿  Disk detection — NVMe auto-detected            │
│  🗂️  Partitioning — 1 GB EFI + root (ext4)          │
│  💤  16 GB swapfile — tuned for 8 GB RAM + gaming   │
│  📦  pacstrap — base system + intel-ucode           │
│  ⚙️   chroot — locale, users, sudo, bootloader      │
│  🥾  systemd-boot — dual entries (stock + surface)  │
│  🐧  linux-surface kernel — proper SP8 support      │
│  ✋  iptsd — touchscreen & pen daemon               │
│  🎮  Steam + gaming stack                           │
│  🔒  UFW firewall + Thermald                        │
│  🌌  COSMIC Desktop + cosmic-greeter                │
│  👻  Phantom Browser — from GitHub releases         │
│  🔧  Performance tuning — sysctl + CPU governor     │
└─────────────────────────────────────────────────────┘
```

---

## 🐧 The linux-surface Kernel

The stock Arch kernel works on Surface hardware — but only barely. The `linux-surface` kernel adds patches maintained by the [linux-surface project](https://github.com/linux-surface/linux-surface) that unlock full hardware support:

| Feature | Stock Kernel | linux-surface |
|---|---|---|
| 🖱️ Touchscreen | ❌ Broken | ✅ Works |
| ✏️ Surface Pen | ❌ Not detected | ✅ Works |
| 📷 Cameras | ❌ Not supported | ✅ Works |
| 🔋 Battery reporting | ⚠️ Partial | ✅ Full |
| 💤 Modern Standby (S0ix) | ⚠️ Unreliable | ✅ Tuned |
| ⌨️ Type Cover | ✅ Works | ✅ Works |

The script installs **both** kernels and creates separate `systemd-boot` entries for each. The `linux-surface` entry is set as default. The stock kernel entry remains as a fallback.

---

## 🌌 COSMIC Desktop Environment

[COSMIC](https://github.com/pop-os/cosmic-epoch) is System76's fully Rust-native desktop environment — Wayland-first, tiling-capable, and blazing fast. It's available in the **official Arch `extra` repository** and installed as the full `cosmic` package group, which includes:

- 🖥️ `cosmic-comp` — Wayland compositor
- 🧭 `cosmic-panel` — top bar and dock
- 📁 `cosmic-files` — file manager
- 💻 `cosmic-terminal` — GPU-accelerated terminal
- 🎨 `cosmic-settings` — system settings
- 🔐 `cosmic-greeter` — display manager / login screen
- 🔋 `power-profiles-daemon` — Power & Battery panel support
- 📂 `xdg-user-dirs` — standard user folders (Documents, Pictures, etc.)

> No AUR, no `paru`, no compiling from source. Pure `pacman`.

---

## 🎮 Gaming Stack

The script builds a complete Steam gaming environment optimized for Intel Iris Xe graphics on the Surface Pro 8.

### Packages Installed

| Package | Purpose |
|---|---|
| `steam` | Game library and launcher |
| `lib32-mesa` + `lib32-vulkan-intel` | 32-bit Vulkan for older games via Proton |
| `vulkan-intel` + `vulkan-tools` | Native Vulkan for Intel Iris Xe |
| `gamemode` + `lib32-gamemode` | Automatic CPU/GPU optimisation on game launch |
| `intel-media-driver` | VA-API hardware video decode |
| `wine-staging` + `winetricks` | Windows compatibility layer |
| `ttf-liberation` | Font substitutes required by many Steam games |

### Steam Launch Options

Add these to any game's launch options in Steam for best performance:

```
gamemoderun %command%
```

For hardware video decode in supported games:
```
LIBVA_DRIVER_NAME=iHD gamemoderun %command%
```

### Performance Tuning Applied

```ini
# /etc/sysctl.d/99-gaming.conf

vm.swappiness          = 10      # Keep RAM preferred; swap is overflow only
vm.vfs_cache_pressure  = 50      # Retain filesystem cache longer
vm.max_map_count       = 2147483642  # Required by Proton / many Linux games
vm.dirty_ratio         = 10      # Reduce disk write stall during gameplay
vm.dirty_background_ratio = 5
```

A `systemd` service locks all CPU cores to the **performance** governor at boot — no waiting for the scheduler to ramp up during game load screens.

---

## 💤 Swap Configuration

| | Value |
|---|---|
| 💾 Physical RAM | 8 GB |
| 🔄 Swapfile | **16 GB** |
| 📍 Location | `/swapfile` |
| ⚙️ `vm.swappiness` | `10` (RAM strongly preferred) |
| 🗂️ fstab entry | ✅ Persistent across reboots |
| ⚡ Creation method | `fallocate` (instant, not `dd`) |

16 GB of swap gives the kernel plenty of overflow headroom when gaming with multiple background apps, without swapping aggressively during normal use thanks to the low swappiness value.

---

## 👻 Phantom Browser

[Phantom Browser](https://github.com/greysonofusa/degoogledchromium) — a de-Googled, privacy-hardened Chromium build based on [Cromite](https://github.com/uazo/cromite) — is pulled directly from the GitHub releases API at install time as a Linux x64 AppImage.

```
✅ No Google services
✅ No telemetry or crash reporting  
✅ Built-in ad blocking
✅ Brave Search pre-installed
✅ Auto-update checker built in
```

The script handles the AppImage lifecycle completely — download, `chmod +x`, symlink to `/usr/local/bin/phantom-browser`, pulls the official icon from the repo, and registers a `.desktop` entry so it appears in the COSMIC launcher.

> **Note:** The Linux AppImage build is still in progress. If no Linux build is found in the latest release at install time, the script exits cleanly and prints instructions. It will self-install the next time you run it once the Linux build goes live.

---

## 🔒 Security & Network

```
🛡️  UFW firewall
    ├── Default: deny all incoming
    ├── Default: allow all outgoing
    └── Enabled at boot via systemd

🌡️  thermald
    └── Intel thermal management daemon — prevents Tiger Lake throttling

🔑  sudo
    └── wheel group only — no passwordless sudo
```

---

## 🥾 Boot Entries

The script creates two `systemd-boot` entries:

```
┌──────────────────────────────────────────────────────┐
│  ★  Arch Linux — linux-surface  [DEFAULT]            │
│     Full Surface hardware support                    │
│                                                      │
│     Arch Linux — linux (stock)  [FALLBACK]           │
│     Standard Arch kernel                             │
└──────────────────────────────────────────────────────┘
```

Kernel boot parameters applied to both entries:

```
mem_sleep_default=s2idle   # Modern Standby for Surface
i915.enable_psr=1          # Panel Self Refresh — saves battery
i915.enable_fbc=1          # Framebuffer compression
mitigations=off            # Spectre/Meltdown mitigations off for perf
nohz_full=1-3              # Tickless CPU cores for gaming
threadirqs                 # Threaded IRQs — smoother under load
nowatchdog                 # Disable watchdog — reduces latency
ibt=off                    # Required for some Proton/Wine compatibility
```

A **pacman hook** automatically syncs the kernel and initramfs to the ESP after every `pacman -Syu` so your boot entries never go stale after an update.

---

## 📁 Configuration — Edit Before Running

Open the script and set these variables at the top before running:

```bash
HOSTNAME="surface-arch"       # your machine's hostname
USERNAME="yourname"           # your regular user account
USER_PASS="your-password"     # ← CHANGE THIS
ROOT_PASS="your-password"     # ← CHANGE THIS
TIMEZONE="America/Chicago"    # timedatectl list-timezones
DISK=""                       # blank = auto-detect NVMe, or set e.g. /dev/nvme0n1
```

---

## 🔧 Post-Install Checklist

```
□  Reboot and select "linux-surface" at the boot menu
□  Log into COSMIC via cosmic-greeter
□  Connect to Wi-Fi via COSMIC Settings → Network
□  Open Steam → Settings → Compatibility → Enable Steam Play for all titles
□  Set game launch options to: gamemoderun %command%
□  Run 'gpu-check' in cosmic-terminal to verify Intel Xe Vulkan + VA-API
□  Check Phantom Browser is in the COSMIC app launcher
```

---

## ⚠️ Known Limitations

- **Secure Boot** must be disabled in the Surface UEFI before booting the Arch ISO
- **BitLocker** (if previously enabled) must be fully decrypted before wiping
- **Cameras** require `linux-surface` kernel — they will not work on the stock kernel
- **Phantom Browser Linux AppImage** may not be in the latest release yet — the script handles this gracefully

---

## 🙏 Credits & Upstream Projects

| Project | Role |
|---|---|
| [Arch Linux](https://archlinux.org) | The base system |
| [linux-surface](https://github.com/linux-surface/linux-surface) | Surface kernel patches |
| [System76 / COSMIC](https://github.com/pop-os/cosmic-epoch) | Desktop environment |
| [Phantom Browser](https://github.com/greysonofusa/degoogledchromium) | Privacy browser |
| [Cromite](https://github.com/uazo/cromite) | Chromium base for Phantom |
| [Valve / Steam](https://store.steampowered.com) | Gaming platform |
| [FeralInteractive / gamemode](https://github.com/FeralInteractive/gamemode) | Gaming optimiser |

---

<div align="center">

**Built for privacy. Optimized for gaming. Designed for the Surface Pro 8.**

*Pull requests and issues welcome.*

![Arch Linux](https://img.shields.io/badge/BTW_I_use-Arch-1793D1?style=flat-square&logo=arch-linux&logoColor=white)

</div>
