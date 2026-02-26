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
*CachyOS-optimized kernel · COSMIC Desktop · Thermal engineering · Steam-ready*

---

![Arch Linux](https://img.shields.io/badge/Arch_Linux-1793D1?style=for-the-badge&logo=arch-linux&logoColor=white)
![Surface Pro 8](https://img.shields.io/badge/Surface_Pro_8-0078D4?style=for-the-badge&logo=microsoft&logoColor=white)
![COSMIC DE](https://img.shields.io/badge/COSMIC_Desktop-5E35B1?style=for-the-badge&logo=linux&logoColor=white)
![Steam](https://img.shields.io/badge/Steam-000000?style=for-the-badge&logo=steam&logoColor=white)
![Shell](https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white)
![CachyOS](https://img.shields.io/badge/CachyOS-x86--64--v3-orange?style=for-the-badge&logo=linux&logoColor=white)
![Secure Boot](https://img.shields.io/badge/Secure_Boot-sbctl-blue?style=for-the-badge&logo=linux&logoColor=white)

</div>

---

## 🎯 What Is This?

A **single-script, fully automated Arch Linux installer** purpose-built for the **Microsoft Surface Pro 8**. Boot the Arch ISO, run one command, walk away. When you come back you'll have a complete, gaming-ready system with the **linux-cachyos-surface** kernel (CachyOS performance patches merged with linux-surface hardware patches), the COSMIC desktop environment, a fully engineered thermal management stack, Steam, Phantom Browser, and a system tuned at every layer for Tiger Lake gaming.

No hand-holding through `pacstrap` steps. No forgotten packages. No rebooting into a broken system.

---

## 💻 Target Hardware

| Component | Spec |
|---|---|
| 🖥️ **Device** | Microsoft Surface Pro 8 |
| 🧠 **CPU** | Intel Core i5-1135G7 (11th Gen Tiger Lake, x86-64-v3) |
| 🎮 **GPU** | Intel Iris Xe — Tiger Lake-LP GT2 |
| 🧩 **RAM** | 8 GB LPDDR4x |
| 💾 **Storage** | NVMe SSD (auto-detected) |
| 🖱️ **Input** | Surface Touch + Pen via `iptsd` |

---

## ⚡ Quickstart

> **Prerequisites:** Boot the official [Arch Linux ISO](https://archlinux.org/download/), disable Secure Boot in the Surface UEFI, connect to the internet via `iwctl` or USB-C Ethernet, then:

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
┌─────────────────────────────────────────────────────────────────┐
│  🔍  Safety checks — UEFI mode, network, passwords             │
│  💿  Disk detection — NVMe auto-detected                       │
│  🗂️  Partitioning — 1 GB EFI + root (ext4)                     │
│  💤  16 GB swapfile — tuned for 8 GB RAM + gaming              │
│  📦  pacstrap — base system + intel-ucode                      │
│  ⚙️   chroot — locale, users, sudo, bootloader                 │
│  🥾  systemd-boot — dual entries (stock fallback + cachyos)    │
│  🐉  CachyOS x86-64-v3 repos — AVX2-optimized packages        │
│  🐧  linux-cachyos-surface — CachyOS + Surface patches merged  │
│  ✋  iptsd + libwacom-surface — touchscreen & pen daemons      │
│  🌡️  throttled — Tiger Lake power limit watchdog               │
│  📊  Intel RAPL — PL1/PL2 tuning to kill the throttle lag      │
│  🎮  Steam + Intel Xe gaming stack                             │
│  🔒  UFW firewall + thermald + irqbalance                      │
│  🌌  COSMIC Desktop (official Arch repos, pure pacman)         │
│  👻  Phantom Browser — pulled from GitHub releases             │
│  🔧  Deep performance tuning — sysctl, HWP, GuC/HuC, THP      │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🐉 CachyOS x86-64-v3 Repositories

The i5-1135G7 fully supports the **x86-64-v3** instruction set (AVX2, FMA3, BMI2, and more). The script adds the CachyOS optimized package repositories, which provide the entire Arch package ecosystem **recompiled with aggressive Clang/GCC flags** that the standard Arch build system never uses.

This means Steam, Mesa, glibc, Wine, and every other package on the system gets AVX2 instruction paths — not just the kernel.

```bash
# Only the optimized repos are added — no custom pacman fork
# Stays 100% compatible with standard Arch Linux workflows
[cachyos-v3]         # x86-64-v3 optimized packages
[cachyos-core-v3]    # core system packages recompiled
[cachyos-extra-v3]   # extra packages recompiled
```

> These repos sit **above** `[core]`, `[extra]`, and `[multilib]` in `pacman.conf` so optimized builds always take priority.

---

## 🐧 The linux-cachyos-surface Kernel

This is the centrepiece of the whole setup — a single kernel that combines **both** patch sets you need, built by [jonpetersathan/linux-cachyos-surface](https://github.com/jonpetersathan/linux-cachyos-surface).

### What's merged inside

| Layer | Source | What it provides |
|---|---|---|
| **linux-surface patches** | [linux-surface](https://github.com/linux-surface/linux-surface) | Touchscreen, pen, cameras, SAM controller, power buttons, Modern Standby |
| **CachyOS base patchset** | [CachyOS](https://github.com/CachyOS/linux-cachyos) | BORE scheduler, CONFIG_CACHY tweaks, low-latency patches |
| **Clang + full LTO** | LLVM toolchain | Whole-program optimisation — ~10% real throughput gain |
| **x86-64-v3 build** | CachyOS compiler flags | AVX2/FMA3 paths active in the kernel itself |
| **1000Hz timer** | CachyOS config | Scheduler fires 1000×/sec — minimum scheduling latency |

### linux-cachyos-surface vs stock linux-surface

| Feature | linux-surface | linux-cachyos-surface |
|---|---|---|
| 🖱️ Touchscreen | ✅ | ✅ |
| ✏️ Surface Pen | ✅ | ✅ |
| 📷 Cameras | ✅ | ✅ |
| 🔋 Battery reporting | ✅ | ✅ |
| 💤 Modern Standby | ✅ | ✅ |
| 🎮 Gaming scheduler | ❌ Stock EEVDF | ✅ BORE |
| ⚡ Compiler | ❌ GCC -O2 | ✅ Clang LTO full |
| 🧮 Instruction set | ❌ Generic x86-64 | ✅ x86-64-v3 (AVX2) |
| ⏱️ Timer frequency | ❌ 250Hz | ✅ 1000Hz |

### Installation method

The script fetches **prebuilt `.pkg.tar.zst` packages** from GitHub releases — no multi-hour compile on your 8 GB Surface. If no prebuilt exists in the latest release, it automatically falls back to building from source with thin LTO to keep memory usage manageable.

> `iptsd` and `libwacom-surface` still come from the linux-surface package repo as userspace daemons — unaffected by the kernel swap.

---

## 🌡️ Thermal Engineering — Solving the Throttle/Fan Surge Problem

This is the most critical section if you game on the Surface Pro 8 under Linux.

### What was happening before

```
① CPU bursts at PL2 (~64W) for milliseconds
② Temperature spikes to ~95°C near-instantly in the thin chassis
③ Surface EC hard-clamps back to PL1 (~15W) — sudden frequency cliff
④ Gaming lag and stutter hit
⑤ Fan screams trying to catch up after the thermal event already happened
⑥ Repeat every 30–60 seconds
```

This is a **power management problem, not a fan control problem.** The fan is reacting correctly to thermal events that should never have been allowed to happen.

### The fix: three layers of thermal control

**Layer 1 — Intel RAPL power limits (`/etc/tmpfiles.d/intel-rapl-gaming.conf`)**

Written at every boot to both the MSR and MMIO (MCHBAR) power cap paths:

| Limit | Stock Surface | This Script | Effect |
|---|---|---|---|
| PL1 sustained | ~15W | **28W** | Higher sustained clock during gaming |
| PL1 window | 28s | **32s** | Longer before long-term throttle kicks in |
| PL2 burst | ~64W | **40W** | Burst is sane — no instant thermal spike |
| Trip temp (AC) | 95°C | **92°C** | SAM begins ramping fan 3°C earlier |

**Layer 2 — `throttled` daemon**

The Surface EC resets RAPL values back to its own defaults every ~5 seconds. `throttled` has explicit **Tiger Lake detection** and continuously re-applies your PL1/PL2 values to win that fight. Two profiles configured automatically:

```ini
[AC]      # Gaming on mains — 28W sustained / 40W burst / trip at 92°C
[BATTERY] # On battery    — 15W sustained / 25W burst / trip at 85°C
```

**Layer 3 — CPU governor + HWP energy preference**

```bash
scaling_governor              → performance
energy_performance_preference → performance
```

The `energy_performance_preference` pin is critical — without it the Intel Hardware P-State logic overrides the governor's frequency decisions with its own power-saving heuristics mid-game.

### The result

```
Before:  75°C → spike 95°C → hard throttle → lag → fan surge → repeat
After:   75–85°C sustained → stable clock → fan at consistent moderate speed
```

### ⚠️ Fan direct control — the honest explanation

The Surface Pro 8's fan is controlled **exclusively by the Surface Aggregator Module (SAM) firmware**. The Linux kernel's `surface_fan` driver exposes only `fan1_input` — a **read-only** RPM value. There is no PWM write interface. No tool on any OS can override the SAM's fan curve — this is a hardware-level constraint, not a Linux limitation.

What the thermal engineering above achieves is the correct solution: by keeping temperatures in a stable 75–85°C sustained range, the SAM sees consistent thermals and holds the fan at a steady moderate speed throughout gaming, rather than surging reactively after each thermal spike.

### Monitoring your thermals in real time

```bash
thermals      # s-tui: CPU freq, temp, power draw, utilisation — all on one screen
fans          # watch -n1 sensors: live fan RPM + all thermal zones every second
powerlimits   # cat RAPL sysfs — confirm PL1=28W, PL2=40W are being held
gpu-check     # vulkaninfo + vainfo: verify Intel Xe Vulkan + VA-API
```

---

## 🎮 Gaming Stack

A complete Intel Iris Xe gaming environment tuned for the Surface Pro 8.

### Packages Installed

| Package | Purpose |
|---|---|
| `steam` | Game library and launcher |
| `lib32-mesa` + `lib32-vulkan-intel` | 32-bit Vulkan for older games via Proton |
| `vulkan-intel` + `vulkan-tools` | Native Vulkan for Intel Iris Xe |
| `gamemode` + `lib32-gamemode` | Automatic CPU/GPU optimisation on game launch |
| `intel-media-driver` | VA-API hardware H.264/HEVC video decode |
| `libva-utils` | `vainfo` diagnostic — verify VA-API is working |
| `wine-staging` + `winetricks` | Windows game compatibility layer |
| `ttf-liberation` | Font substitutes required by many Steam titles |
| `mesa-utils` + `lib32-mesa-utils` | `glxinfo` GPU diagnostics |
| `s-tui` | Real-time thermal and performance monitor |
| `lm_sensors` | Live sensor readings including Surface fan RPM |
| `irqbalance` | Distributes hardware IRQs across cores — reduces latency spikes |
| `msr-tools` | MSR register access required by `throttled` |

### Intel Xe GPU — GuC/HuC Firmware (`/etc/modprobe.d/i915-gaming.conf`)

```
enable_guc=3   GuC: GPU micro-controller handles command submission
               Offloads GPU scheduling from the CPU → less driver overhead
               HuC: hardware H.264/HEVC encode/decode offload
enable_rc6=1   GPU enters low-power state between frames → less heat generated
enable_fbc=1   Framebuffer compression → memory bandwidth savings
enable_psr=1   Panel Self Refresh → battery savings at stable framerates
```

### Steam Launch Options

```
gamemoderun %command%
```

For video-heavy games with cutscenes (enables hardware decode):
```
LIBVA_DRIVER_NAME=iHD gamemoderun %command%
```

---

## 💤 Swap Configuration

| | Value |
|---|---|
| 💾 Physical RAM | 8 GB |
| 🔄 Swapfile | **16 GB** |
| 📍 Location | `/swapfile` |
| ⚙️ `vm.swappiness` | `10` — RAM strongly preferred, swap is overflow only |
| 🗂️ fstab entry | ✅ Persistent across reboots |
| ⚡ Creation method | `fallocate` — instant, not `dd` |

---

## 🔧 Full Performance Tuning Reference

### `/etc/sysctl.d/99-gaming.conf`

```ini
# Memory
vm.swappiness = 10                   # Keep games in RAM; swap only as last resort
vm.vfs_cache_pressure = 50           # Retain filesystem cache — faster asset loads
vm.max_map_count = 2147483642        # Required by Proton, Steam, many Linux games
vm.dirty_ratio = 10                  # Reduce NVMe write stalls during gameplay
vm.dirty_background_ratio = 5
vm.dirty_writeback_centisecs = 1500  # Batch NVMe writes for I/O efficiency
vm.dirty_expire_centisecs = 3000

# CPU / Scheduler
kernel.sched_migration_cost_ns = 5000000  # Keep game threads on the same core longer
kernel.numa_balancing = 0                 # Not useful on single-socket mobile CPU

# Network — multiplayer game latency improvements
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
```

### Transparent Hugepages — `madvise` mode

```
/sys/kernel/mm/transparent_hugepage/enabled → madvise
/sys/kernel/mm/transparent_hugepage/defrag  → defer+madvise
```

Proton and Wine explicitly request 2 MB hugepages — `madvise` honours these requests without the background compaction overhead of `always` mode, which can cause frame time spikes. Persisted via `/etc/tmpfiles.d/thp-madvise.conf`.

### Boot Parameters (applied to both kernel entries)

```
mem_sleep_default=s2idle   Surface Modern Standby — proper sleep/wake
i915.enable_psr=1          Panel Self Refresh
i915.enable_fbc=1          Framebuffer compression
mitigations=off            Spectre/Meltdown mitigations off — measurable perf gain
nohz_full=1-3              Tickless idle on non-boot cores
threadirqs                 Threaded IRQs — smoother system response under load
nowatchdog                 Disable watchdog timer — removes scheduling noise
ibt=off                    Required for Proton/Wine module compatibility
```

---

## 🌌 COSMIC Desktop Environment

[COSMIC](https://github.com/pop-os/cosmic-epoch) is System76's fully Rust-native, Wayland-first desktop environment. Installed entirely from the **official Arch `extra` repository** — pure `pacman`, no AUR, no compiling.

```bash
pacman -S cosmic power-profiles-daemon xdg-user-dirs
systemctl enable cosmic-greeter.service
```

| Package | Why it's included |
|---|---|
| `cosmic` | Full 27-package group from Arch `extra` repo |
| `power-profiles-daemon` | Required for Power & Battery panel in COSMIC Settings |
| `xdg-user-dirs` | Creates Documents, Pictures, Videos, Downloads folders |

---

## 👻 Phantom Browser

[Phantom Browser](https://github.com/greysonofusa/degoogledchromium) is a de-Googled, privacy-hardened Chromium build based on [Cromite](https://github.com/uazo/cromite). Pulled at install time as a Linux x64 AppImage directly from the GitHub releases API.

```
✅ All Google services removed — no sync, no Safe Browsing, no RLZ tracking
✅ No telemetry or crash reporting
✅ Built-in ad blocking (Cromite)
✅ Brave Search + DuckDuckGo pre-installed
✅ Auto-update checker built in
✅ Official PhantomBrowserIcon.png pulled from repo
✅ Symlinked to /usr/local/bin/phantom-browser
✅ .desktop entry registered in COSMIC app launcher
```

> **Note:** The Linux AppImage build is still in progress upstream. If no Linux build exists in the latest release at install time, the script exits cleanly and prints instructions. Once the Linux build ships, it self-installs on the next run with no script changes needed.

---

## 🔒 Security & Network

```
🛡️  UFW firewall
    ├── Default: deny all incoming
    ├── Default: allow all outgoing
    └── Enabled and persistent via systemd

🌡️  thermald
    └── Intel thermal management daemon — Tiger Lake thermal zone handling

⚖️  irqbalance
    └── Distributes hardware interrupt load across all CPU cores
        Prevents single-core IRQ saturation during intensive gaming

🔑  sudo
    └── wheel group only — no passwordless sudo
```

---

## 🥾 Boot Entries

```
┌──────────────────────────────────────────────────────────────────┐
│  ★  Arch Linux — linux-cachyos-surface  [DEFAULT]               │
│     BORE scheduler · Clang LTO full · x86-64-v3 · 1000Hz timer  │
│     Full Surface Pro 8 hardware support                          │
│                                                                  │
│     Arch Linux — linux (stock)  [FALLBACK]                       │
│     Standard Arch kernel — emergency recovery use                │
└──────────────────────────────────────────────────────────────────┘
```

A **pacman hook** automatically syncs both kernels and their initramfs images to the ESP after every `pacman -Syu`, then calls `sbctl sign-all` to re-sign the updated files — boot entries never go stale or unsigned after a kernel update.

---

## 🔐 Secure Boot — sbctl with Auto-Signing

The script sets up a complete, self-maintaining Secure Boot chain using [sbctl](https://github.com/Foxboron/sbctl). Once configured, every `pacman -Syu` that touches a kernel or bootloader automatically re-signs the updated binaries — Secure Boot never breaks after an update.

### How it works

```
┌─────────────────────────────────────────────────────────────────────┐
│  sbctl creates 3 RSA-4096 key pairs:                                │
│    PK  (Platform Key)      — root of the trust chain               │
│    KEK (Key Exchange Key)  — signs updates to the db               │
│    db  (Database Key)      — used to sign EFI binaries             │
│                                                                     │
│  All EFI binaries are signed with db:                               │
│    /boot/efi/EFI/systemd/systemd-bootx64.efi  (bootloader)        │
│    /boot/efi/EFI/BOOT/BOOTX64.EFI             (fallback loader)   │
│    /boot/efi/vmlinuz-linux-cachyos-surface     (primary kernel)    │
│    /boot/efi/vmlinuz-linux                     (fallback kernel)   │
│    /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed           │
│         ↑ this signed source means bootctl updates stay signed too │
└─────────────────────────────────────────────────────────────────────┘
```

### What the install script does automatically

The install script handles everything that can be scripted:

- Installs `sbctl`
- Generates your PK, KEK, and db key pairs (stored in `/var/lib/sbctl/keys/`)
- Signs all EFI binaries using `sbctl sign -s` (the `-s` flag saves each path to the signing database)
- Signs the systemd-boot source at `/usr/lib/` so loader updates stay signed automatically
- Enables `systemd-boot-update.service` for automatic loader maintenance
- Updates the pacman hook to call `sbctl sign-all` after every kernel update

### ⚠️ What YOU must do manually (requires UEFI interaction)

Key enrollment into the UEFI firmware cannot be scripted — it requires physical interaction with the Surface UEFI. The script prints these instructions at the end of the install, but they're reproduced here for reference.

**Why `-m` (keep Microsoft's keys) is mandatory on Surface:**
The Surface Pro 8's UEFI firmware and SAM (Surface Aggregator Module) are themselves signed and verified by Microsoft's keys. Enrolling your keys without `-m` would prevent Surface UEFI firmware updates from ever working and could leave the system in an unrecoverable state.

**Step-by-step enrollment:**

```
STEP 1 — Put the Surface UEFI into Setup Mode
  Power off → hold Volume Up + Power button together → enter UEFI
  Navigate to: Security → Secure Boot → Clear Secure Boot Keys
  Save and exit. Boot into Arch Linux.
  (This clears the existing MS keys, putting firmware in Setup Mode)

STEP 2 — Confirm Setup Mode is active
  sudo sbctl status
  → Must show:  Setup Mode: Enabled ✓
  (If it shows Disabled, repeat Step 1)

STEP 3 — Enroll your keys alongside Microsoft's vendor keys
  sudo sbctl enroll-keys -m
  → The -m flag is REQUIRED on Surface hardware

STEP 4 — SHUT DOWN (do NOT reboot — Surface-specific requirement)
  sudo shutdown now
  A direct reboot bypasses the firmware key write step.
  You must fully power off, then power back on.

STEP 5 — Enable Secure Boot in the UEFI
  Power on → hold Volume Up + Power → enter UEFI
  Navigate to: Security → Secure Boot → Enable Secure Boot
  Save and exit. Boot into Arch Linux.

STEP 6 — Verify everything is working
  sudo sbctl status
  → Secure Boot: enabled  ✓
  → Vendor Keys: microsoft ✓
  → Setup Mode: Disabled  ✓

  sudo bootctl status | grep 'Secure Boot'
  → Secure Boot: enabled (user)  ✓
```

### How auto-signing works after updates

After `sudo pacman -Syu`, the sequence is fully automatic:

```
pacman upgrades linux-cachyos-surface or systemd
       ↓
95-systemd-boot.hook fires (PostTransaction)
       ↓
New kernel/initramfs copied to ESP (/boot/efi/)
       ↓
sbctl sign-all re-signs every registered EFI binary
       ↓
sbctl re-signs /usr/lib/systemd-bootx64.efi.signed
       ↓
Next boot: UEFI verifies signature → boots normally
```

You never need to manually sign anything after a routine system update.

### Troubleshooting Secure Boot

If the system fails to boot after an update, boot into the stock kernel (`linux`) fallback entry — it is also signed. Then run:

```bash
sudo sbctl verify        # shows what's signed and what isn't
sudo sbctl sign-all      # re-signs everything in the database
sudo sbctl list-files    # shows the full signing registry
```

If keys ever need to be rotated:
```bash
sudo sbctl rotate-keys   # generates new keys and re-signs everything
# Then repeat the enrollment steps above
```

---

## 📁 Configuration — Edit Before Running

```bash
HOSTNAME="surface-arch"       # your machine hostname
USERNAME="yourname"           # your regular (non-root) username
USER_PASS="your-password"     # ← CHANGE THIS
ROOT_PASS="your-password"     # ← CHANGE THIS
TIMEZONE="America/Chicago"    # timedatectl list-timezones | grep America
DISK=""                       # blank = auto-detect NVMe, or e.g. /dev/nvme0n1
```

---

## 🔧 Post-Install Checklist

```
□  Reboot and select "linux-cachyos-surface" at the boot menu
□  Log into COSMIC via cosmic-greeter
□  Connect to Wi-Fi in COSMIC Settings → Network
□  Run 'thermals' — verify CPU temp and power limits look sane
□  Run 'powerlimits' — confirm RAPL PL1=28W and PL2=40W are held
□  Run 'gpu-check' — confirm Vulkan + VA-API are working on Iris Xe
□  Open Steam → Settings → Compatibility → Enable Steam Play for all titles
□  Add 'gamemoderun %command%' to Steam game launch options
□  Verify Phantom Browser appears in the COSMIC app launcher
□  Always plug in AC power before gaming

── Secure Boot Enrollment (after first successful boot) ──────────────────

□  Check sbctl status: sudo sbctl status  (confirm keys exist)
□  Enter Surface UEFI: power off → hold Volume Up + Power
□  Navigate to Security → Secure Boot → Clear Secure Boot Keys (Setup Mode)
□  Save, exit, boot back into Arch
□  Verify Setup Mode: sudo sbctl status  → "Setup Mode: Enabled"
□  Enroll keys: sudo sbctl enroll-keys -m  (the -m is mandatory on Surface)
□  SHUT DOWN: sudo shutdown now  (do NOT reboot — Surface-specific requirement)
□  Power on → hold Volume Up + Power → UEFI → Enable Secure Boot → save & exit
□  Boot into Arch and verify: sudo sbctl status  → "Secure Boot: enabled"
□  Final verify: sudo bootctl status | grep 'Secure Boot'  → "enabled (user)"
```

---

## ⚠️ Known Limitations

- **Secure Boot setup requires physical UEFI interaction** — the install script generates and registers all keys and signatures automatically, but key enrollment into the firmware requires you to enter the Surface UEFI manually. Full step-by-step instructions are printed at the end of the install and documented in the [Secure Boot section](#-secure-boot--sbctl-with-auto-signing) above
- **Secure Boot was previously disabled** — if you're reinstalling over an existing Linux setup that had Secure Boot off, you'll need to clear existing keys in the UEFI before enrolling your sbctl keys
- **Cameras** require the linux-cachyos-surface kernel — will not work on stock `linux`
- **Fan speed cannot be directly controlled** — the Surface Aggregator Module firmware owns the fan curve. The thermal engineering in this script prevents the conditions that cause fan surges
- **Phantom Browser Linux AppImage** may not be in the latest upstream release yet — handled gracefully
- **linux-cachyos-surface prebuilt packages** may occasionally lag a kernel version behind — the script falls back to source build automatically

---

## 🛠️ Quick Reference — Shell Aliases

| Alias | Command | What it shows |
|---|---|---|
| `thermals` | `s-tui` | CPU freq, temp, power draw, utilisation |
| `fans` | `watch -n1 sensors` | Live fan RPM + all thermal zones |
| `powerlimits` | RAPL sysfs cat | Verify PL1/PL2 are correctly applied |
| `gpu-check` | `vulkaninfo && vainfo` | Confirm Iris Xe Vulkan + VA-API |

---

## 🙏 Credits & Upstream Projects

| Project | Role |
|---|---|
| [Arch Linux](https://archlinux.org) | The base system |
| [CachyOS](https://cachyos.org) | x86-64-v3 optimized repos, BORE scheduler, kernel patches |
| [jonpetersathan/linux-cachyos-surface](https://github.com/jonpetersathan/linux-cachyos-surface) | CachyOS + linux-surface merged kernel |
| [linux-surface](https://github.com/linux-surface/linux-surface) | Surface hardware patches, iptsd, libwacom-surface |
| [System76 / COSMIC](https://github.com/pop-os/cosmic-epoch) | Desktop environment |
| [Phantom Browser](https://github.com/greysonofusa/degoogledchromium) | Privacy-focused browser |
| [Cromite](https://github.com/uazo/cromite) | Chromium base for Phantom |
| [erpalma/throttled](https://github.com/erpalma/throttled) | Tiger Lake power limit watchdog |
| [Foxboron/sbctl](https://github.com/Foxboron/sbctl) | Secure Boot key manager — auto-signing on kernel updates |
| [Valve / Steam](https://store.steampowered.com) | Gaming platform |
| [FeralInteractive/gamemode](https://github.com/FeralInteractive/gamemode) | Per-game CPU/GPU performance optimiser |

---

<div align="center">

**Built for privacy. Engineered for thermals. Optimized for gaming. Designed for the Surface Pro 8.**

*Pull requests and issues welcome.*

![Arch Linux](https://img.shields.io/badge/BTW_I_use-Arch-1793D1?style=flat-square&logo=arch-linux&logoColor=white)
![CachyOS](https://img.shields.io/badge/kernel-linux--cachyos--surface-orange?style=flat-square)
![Thermal](https://img.shields.io/badge/thermals-engineered-green?style=flat-square)
![Secure Boot](https://img.shields.io/badge/Secure_Boot-sbctl-blue?style=flat-square)

</div>
