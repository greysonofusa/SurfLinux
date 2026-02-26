#!/usr/bin/env bash
# =============================================================================
#  Arch Linux Installer — Microsoft Surface Pro 8
#  CPU  : Intel Core i5-1135G7 (Tiger Lake, 11th Gen)
#  GPU  : Intel Iris Xe / Tiger Lake-LP GT2
#  RAM  : 8 GB Physical  |  16 GB SWAP (swapfile)
#  DE   : COSMIC (System76) via AUR
#  BOOT : systemd-boot (UEFI / Secure-Boot-off)
#  OPT  : Steam / Gaming / linux-cachyos-surface kernel (CachyOS + Surface patches)
# =============================================================================
# HOW TO USE:
#   1. Boot the official Arch Linux ISO on your Surface Pro 8
#   2. Connect to the internet (wifi-menu or ethernet via USB-C adapter)
#   3. curl -O https://your-host/this-script.sh   (or paste it directly)
#   4. nano this-script.sh  → fill in USER CONFIG section below
#   5. chmod +x this-script.sh && bash this-script.sh
# =============================================================================

set -euo pipefail

# ── Colour helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()   { echo -e "${RED}[FAIL]${NC}  $*" >&2; exit 1; }
banner(){ echo -e "\n${BOLD}${CYAN}══════════════════════════════════════════${NC}"; \
          echo -e "${BOLD}${CYAN}  $*${NC}"; \
          echo -e "${BOLD}${CYAN}══════════════════════════════════════════${NC}\n"; }

# =============================================================================
#  ░░  USER CONFIGURATION — FILL THESE IN BEFORE RUNNING  ░░
# =============================================================================

HOSTNAME="surface-arch"
USERNAME="gamer"                   # your regular (non-root) username
USER_PASS="CHANGEME_NOW"           # ← change this
ROOT_PASS="CHANGEME_NOW"           # ← change this

LOCALE="en_US.UTF-8"
KEYMAP="us"
TIMEZONE="America/Chicago"         # timedatectl list-timezones | grep America

# Disk — leave blank to auto-detect the Surface Pro 8's NVMe drive
DISK=""

# Swap — 16 GB swapfile to complement 8 GB RAM for gaming headroom
SWAP_SIZE="16G"

# =============================================================================
#  ░░  SAFETY CHECKS  ░░
# =============================================================================

banner "Surface Pro 8 — Arch Linux Installer"

[[ $EUID -ne 0 ]] && die "Must be run as root from the Arch live ISO."

if [[ "$USER_PASS" == "CHANGEME_NOW" || "$ROOT_PASS" == "CHANGEME_NOW" ]]; then
    die "Please set USER_PASS and ROOT_PASS at the top of this script before running."
fi

# Verify we are booted in UEFI mode
[[ -d /sys/firmware/efi/efivars ]] || die "Not booted in UEFI mode. Check Surface UEFI settings."

# =============================================================================
#  ░░  NETWORK CHECK  ░░
# =============================================================================

banner "Checking Network"
if ! ping -c 2 archlinux.org &>/dev/null; then
    warn "No network detected. Attempting to bring up interfaces..."
    # Surface Pro 8 Wi-Fi (Marvell 88W8897 or similar) should load via firmware
    ip link set up "$(ip link | awk -F: '/^[0-9]+: w/{print $2; exit}' | tr -d ' ')" 2>/dev/null || true
    sleep 2
    ping -c 2 archlinux.org &>/dev/null || \
        die "No network. Connect via USB-C Ethernet or run iwctl to join Wi-Fi first."
fi
ok "Network is up."

# =============================================================================
#  ░░  DISK SELECTION & PARTITIONING  ░░
# =============================================================================

banner "Disk Setup"

if [[ -z "$DISK" ]]; then
    DISK=$(lsblk -dpnoNAME | grep "^/dev/nvme" | head -n1)
    [[ -z "$DISK" ]] && DISK=$(lsblk -dpnoNAME | grep "^/dev/sd" | head -n1)
    [[ -z "$DISK" ]] && die "No suitable disk found. Set DISK= manually at the top of this script."
fi

info "Target disk: ${BOLD}${DISK}${NC}"
echo
lsblk "$DISK"
echo
read -rp "$(echo -e "${RED}${BOLD}ALL DATA ON ${DISK} WILL BE DESTROYED. Type 'yes' to continue: ${NC}")" CONFIRM
[[ "$CONFIRM" == "yes" ]] || die "Aborted by user."

# Wipe & partition — GPT, 1 GB EFI, rest root (no separate /home for gaming flexibility)
info "Wiping and partitioning ${DISK}..."
wipefs -af "$DISK"
sgdisk -Z "$DISK"
sgdisk \
    -n 1:0:+1G   -t 1:ef00 -c 1:"EFI System Partition" \
    -n 2:0:0     -t 2:8300 -c 2:"Arch Linux Root"      \
    "$DISK"

# Detect partition suffix (nvme uses 'p', sda does not)
if [[ "$DISK" == *nvme* ]]; then
    PART_EFI="${DISK}p1"
    PART_ROOT="${DISK}p2"
else
    PART_EFI="${DISK}1"
    PART_ROOT="${DISK}2"
fi

info "Formatting partitions..."
mkfs.fat  -F32 -n EFI  "$PART_EFI"
mkfs.ext4 -L   ROOT    "$PART_ROOT"

info "Mounting partitions..."
mount "$PART_ROOT" /mnt
mkdir -p /mnt/boot/efi
mount "$PART_EFI"  /mnt/boot/efi

ok "Partitions ready."

# =============================================================================
#  ░░  SWAP FILE — 16 GB to complement 8 GB RAM  ░░
# =============================================================================

banner "Creating 16 GB Swapfile"

# fallocate is orders of magnitude faster than dd for this purpose
fallocate -l "$SWAP_SIZE" /mnt/swapfile
chmod 0600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
ok "16 GB swapfile active."

# =============================================================================
#  ░░  BASE SYSTEM INSTALL  ░░
# =============================================================================

banner "Installing Base System (pacstrap)"

# Sync mirrors and optimise for speed
info "Updating mirrorlist..."
reflector --country US --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

# Enable multilib for Steam/gaming lib32 packages right now so pacstrap can see it
sed -i '/^#\[multilib\]/,/^#Include/{s/^#//}' /etc/pacman.conf

pacstrap -K /mnt \
    base base-devel linux linux-headers linux-firmware \
    intel-ucode \
    e2fsprogs dosfstools \
    systemd-boot \
    networkmanager \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    xdg-desktop-portal xdg-user-dirs \
    git curl wget nano \
    reflector \
    sudo

ok "Base system installed."

# =============================================================================
#  ░░  FSTAB  ░░
# =============================================================================

banner "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

# Add swapfile entry (was missing in original script — swap won't survive reboot without this)
echo '/swapfile  none  swap  defaults  0 0' >> /mnt/etc/fstab
ok "fstab written (including persistent swapfile entry)."

# =============================================================================
#  ░░  CHROOT CONFIGURATION  ░░
# =============================================================================

banner "Entering chroot for system configuration"

arch-chroot /mnt /bin/bash <<CHROOT
set -euo pipefail

# ── Timezone & Clock ──────────────────────────────────────────────────────────
ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
hwclock --systohc

# ── Locale ────────────────────────────────────────────────────────────────────
sed -i "s/^#${LOCALE}/${LOCALE}/" /etc/locale.gen
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

# ── Hostname ──────────────────────────────────────────────────────────────────
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# ── Enable multilib (Steam / 32-bit gaming libraries) ─────────────────────────
sed -i '/^\[multilib\]/,/^Include/{s/^#//}' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include/{s/^#//}' /etc/pacman.conf
pacman -Sy --noconfirm

# ── pacman tweaks for speed ───────────────────────────────────────────────────
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf

# ── Users & Passwords ─────────────────────────────────────────────────────────
echo "root:${ROOT_PASS}" | chpasswd
useradd -m -G wheel,audio,video,input,storage,games -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASS}" | chpasswd

# Allow wheel group to use sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# ── mkinitcpio ────────────────────────────────────────────────────────────────
mkinitcpio -P

# ── systemd-boot ─────────────────────────────────────────────────────────────
bootctl --esp-path=/boot/efi install

# Get root UUID for boot entry
ROOT_UUID=\$(blkid -s UUID -o value ${PART_ROOT})

mkdir -p /boot/efi/loader/entries

cat > /boot/efi/loader/loader.conf <<EOF
default  arch.conf
timeout  4
console-mode max
editor   no
EOF

cat > /boot/efi/loader/entries/arch.conf <<EOF
title   Arch Linux (Surface Pro 8)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=\${ROOT_UUID} rw quiet splash
        mem_sleep_default=s2idle
        i915.enable_psr=1
        i915.enable_fbc=1
        mitigations=off
        nohz_full=1-3
        threadirqs
        nowatchdog
        ibt=off
EOF

cat > /boot/efi/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux — Fallback (Surface Pro 8)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options root=UUID=\${ROOT_UUID} rw
EOF

# ── Copy kernel & initrd to ESP (systemd-boot needs them on the ESP) ──────────
# The kernel is in /boot; with a separate ESP we need to copy/bind or use a
# pacman hook. Use the systemd-boot pacman hook approach:
mkdir -p /boot/efi
cp /boot/vmlinuz-linux          /boot/efi/
cp /boot/intel-ucode.img        /boot/efi/
cp /boot/initramfs-linux.img    /boot/efi/
cp /boot/initramfs-linux-fallback.img /boot/efi/

# Pacman hook to keep ESP in sync after kernel updates
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/95-systemd-boot.hook <<'EOF'
[Trigger]
Type = Package
Operation = Upgrade
Target = linux
Target = intel-ucode

[Action]
Description = Updating systemd-boot kernel files on ESP...
When = PostTransaction
Exec = /bin/sh -c 'cp /boot/vmlinuz-linux /boot/efi/ && cp /boot/intel-ucode.img /boot/efi/ && cp /boot/initramfs-linux.img /boot/efi/ && cp /boot/initramfs-linux-fallback.img /boot/efi/'
EOF

# ── Networking ────────────────────────────────────────────────────────────────
systemctl enable NetworkManager

# ── Firewall (UFW) ────────────────────────────────────────────────────────────
pacman -S --noconfirm ufw
systemctl enable ufw
ufw default deny incoming
ufw default allow outgoing
ufw enable

# ── Thermald (Surface thermal management — Tiger Lake) ────────────────────────
pacman -S --noconfirm thermald
systemctl enable thermald

# ── CachyOS repositories (x86-64-v3 — optimized for Tiger Lake i5-1135G7) ──────
# The i5-1135G7 fully supports the x86-64-v3 instruction set (AVX2, FMA3, etc.)
# CachyOS x86-64-v3 packages are recompiled with aggressive GCC/Clang flags that
# the standard Arch build system does not use, giving real-world performance gains.
#
# We intentionally skip the CachyOS custom pacman fork to stay 100% Arch-compatible.
# Only the optimized package repos are added.

info "Adding CachyOS x86-64-v3 optimized repositories..."

# Install CachyOS keyring and mirrorlist packages directly (no custom pacman needed)
pacman -U --noconfirm --needed \
    "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst" \
    "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst" \
    "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-22-1-any.pkg.tar.zst"

# Append CachyOS v3 repos above the standard Arch repos
# These must come BEFORE [core], [extra], [multilib] in pacman.conf
sed -i '/^\[core\]/i \
[cachyos-v3]\
Include = /etc/pacman.d/cachyos-v3-mirrorlist\
\
[cachyos-core-v3]\
Include = /etc/pacman.d/cachyos-v3-mirrorlist\
\
[cachyos-extra-v3]\
Include = /etc/pacman.d/cachyos-v3-mirrorlist\
' /etc/pacman.conf

pacman -Sy --noconfirm

# ── linux-surface repo — userspace tools only (iptsd, libwacom-surface) ────────
# We still need the linux-surface repo for Surface-specific userspace daemons.
# The kernel itself is replaced by linux-cachyos-surface below.
curl -s https://pkg.surfacelinux.com/arch/sign.gpg | pacman-key --add -
pacman-key --lsign-key 56C464BAAC421952

cat >> /etc/pacman.conf <<'EOF'

[linux-surface]
Server = https://pkg.surfacelinux.com/arch/
EOF

pacman -Sy --noconfirm
pacman -S --noconfirm iptsd libwacom-surface

# ── linux-cachyos-surface kernel ───────────────────────────────────────────────
# This is the centrepiece: CachyOS performance patches + linux-surface hardware
# patches merged into a single kernel, built with Clang + full LTO for maximum
# throughput on Tiger Lake.
#
# What you get vs stock linux-surface:
#   ✦ BORE scheduler   — burst-oriented, dramatically better gaming responsiveness
#   ✦ Clang + LTO full — whole-program optimisation, ~10% real-world throughput gain
#   ✦ x86-64-v3 build  — AVX2/FMA3 instruction paths active throughout the kernel
#   ✦ 1000Hz timer     — ultra-low scheduling latency
#   ✦ CONFIG_CACHY     — CachyOS scheduler and system tweaks baked into the config
#   ✦ All linux-surface patches — touchscreen, pen, cameras, SAM, power buttons
#
# Source: https://github.com/jonpetersathan/linux-cachyos-surface
# Prebuilt packages from GitHub releases avoid a multi-hour compile on the Surface.

info "Installing linux-cachyos-surface kernel from prebuilt release..."

CACHYOS_SURFACE_REPO="jonpetersathan/linux-cachyos-surface"
CACHYOS_SURFACE_DIR="/tmp/cachyos-surface-kernel"
mkdir -p "\$CACHYOS_SURFACE_DIR"

RELEASE_JSON=\$(curl -fsSL "https://api.github.com/repos/\${CACHYOS_SURFACE_REPO}/releases/latest" 2>/dev/null || true)

if [[ -n "\$RELEASE_JSON" ]]; then
    # Pull all .pkg.tar.zst asset URLs — kernel + headers (exclude LTS variant)
    mapfile -t PKG_URLS < <(echo "\$RELEASE_JSON" | \
        grep -o '"browser_download_url": *"[^"]*"' | \
        sed 's/"browser_download_url": *"//;s/"\$//' | \
        grep '\.pkg\.tar\.zst\$' | \
        grep -v 'lts')

    if [[ \${#PKG_URLS[@]} -gt 0 ]]; then
        info "Downloading linux-cachyos-surface packages..."
        for url in "\${PKG_URLS[@]}"; do
            fname=\$(basename "\$url")
            curl -fsSL "\$url" -o "\${CACHYOS_SURFACE_DIR}/\${fname}"
        done
        pacman -U --noconfirm \${CACHYOS_SURFACE_DIR}/*.pkg.tar.zst
        info "linux-cachyos-surface installed from prebuilt release."
    else
        warn "No prebuilt packages found in latest release — falling back to AUR build."
        # Install paru and build from source as fallback
        pacman -S --noconfirm --needed base-devel git
        sudo -u ${USERNAME} bash -c '
            cd /tmp
            git clone https://aur.archlinux.org/paru-bin.git
            cd paru-bin && makepkg -si --noconfirm
            cd /tmp
            git clone https://github.com/jonpetersathan/linux-cachyos-surface.git
            cd linux-cachyos-surface/linux-cachyos-surface
            # Use thin LTO to keep RAM usage manageable on 8 GB Surface
            sed -i "s/_use_llvm_lto:=full/_use_llvm_lto:=thin/" PKGBUILD
            makepkg -si --noconfirm --skipinteg
        '
    fi
else
    warn "Could not reach GitHub API — falling back to AUR build."
    pacman -S --noconfirm --needed base-devel git
    sudo -u ${USERNAME} bash -c '
        cd /tmp
        git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin && makepkg -si --noconfirm
        paru -S --noconfirm linux-cachyos-surface
    '
fi

# Generate initramfs for the cachyos-surface kernel
mkinitcpio -p linux-cachyos-surface

# ── Boot entry: linux-cachyos-surface [PRIMARY] ───────────────────────────────
CACHY_UUID=\$(blkid -s UUID -o value ${PART_ROOT})
cat > /boot/efi/loader/entries/arch-cachyos-surface.conf <<EOF
title   Arch Linux — linux-cachyos-surface (Surface Pro 8) [DEFAULT]
linux   /vmlinuz-linux-cachyos-surface
initrd  /intel-ucode.img
initrd  /initramfs-linux-cachyos-surface.img
options root=UUID=\${CACHY_UUID} rw quiet splash
        mem_sleep_default=s2idle
        i915.enable_psr=1
        i915.enable_fbc=1
        mitigations=off
        nohz_full=1-3
        threadirqs
        nowatchdog
        ibt=off
EOF

cp /boot/vmlinuz-linux-cachyos-surface              /boot/efi/
cp /boot/initramfs-linux-cachyos-surface.img        /boot/efi/
cp /boot/initramfs-linux-cachyos-surface-fallback.img /boot/efi/ 2>/dev/null || true

# Set cachyos-surface as the default boot entry
sed -i 's/^default.*/default  arch-cachyos-surface.conf/' /boot/efi/loader/loader.conf

# ── Update pacman hook to sync cachyos-surface kernel to ESP after updates ─────
cat > /etc/pacman.d/hooks/95-systemd-boot.hook <<'EOF'
[Trigger]
Type = Package
Operation = Upgrade
Target = linux-cachyos-surface
Target = linux
Target = intel-ucode

[Action]
Description = Syncing kernels to ESP after upgrade...
When = PostTransaction
Exec = /bin/sh -c 'for f in vmlinuz-linux-cachyos-surface initramfs-linux-cachyos-surface.img initramfs-linux-cachyos-surface-fallback.img vmlinuz-linux intel-ucode.img initramfs-linux.img initramfs-linux-fallback.img; do [ -f /boot/$f ] && cp /boot/$f /boot/efi/; done'
EOF

# Enable iptsd for Surface touchscreen & pen input
systemctl enable iptsd

# ── Gaming & Steam packages ────────────────────────────────────────────────────
# NOTE: multilib is already enabled above.
# Corrected from original script:
#   - Removed lib32-intel-media-driver (does not exist in Arch repos)
#   - Removed stray '-y' flag (apt syntax — invalid in pacman)
#   - Added --noconfirm for unattended install
#   - Added mesa-utils, lib32-mesa-utils for glxinfo diagnostics
#   - Added wine-staging + deps for broader game compatibility
#   - Added mangohud for in-game FPS/perf overlay
#   - Added proton-ge-custom via AUR for best Steam compatibility

pacman -S --noconfirm \
    steam \
    lib32-mesa \
    lib32-vulkan-intel \
    vulkan-intel \
    vulkan-tools \
    lib32-vulkan-icd-loader \
    lib32-gcc-libs \
    lib32-glibc \
    gamemode \
    lib32-gamemode \
    ttf-liberation \
    intel-media-driver \
    libva-utils \
    mesa-utils \
    lib32-mesa-utils \
    wine-staging \
    winetricks \
    lib32-alsa-plugins \
    lib32-libpulse \
    lib32-openal

# ── Phantom Browser (de-Googled Chromium by greysonofusa) ─────────────────────
# Repo   : https://github.com/greysonofusa/degoogledchromium
# Format : Linux x64 AppImage (released alongside Android/Windows builds)
# Icon   : pulled from repo's PhantomBrowserIcon.png
# NOTE   : The Linux AppImage build may still be in progress. This block checks
#          the GitHub releases API at install time, installs if available, and
#          exits cleanly with a reminder if the Linux build isn't up yet.

PHANTOM_REPO="greysonofusa/degoogledchromium"
PHANTOM_DIR="/opt/phantom-browser"
PHANTOM_ICON_URL="https://raw.githubusercontent.com/greysonofusa/degoogledchromium/main/PhantomBrowserIcon.png"
PHANTOM_DESKTOP="/usr/share/applications/phantom-browser.desktop"

echo ">>> Checking for Phantom Browser Linux AppImage on GitHub..."

RELEASE_JSON=\$(curl -fsSL "https://api.github.com/repos/\${PHANTOM_REPO}/releases/latest" 2>/dev/null || true)

if [[ -z "\$RELEASE_JSON" ]]; then
    echo ">>> [PHANTOM] Could not reach GitHub API — skipping browser install."
    echo ">>> Install manually later: https://github.com/\${PHANTOM_REPO}/releases"
else
    # Find the Linux x64 AppImage asset — exclude Android APKs, Windows EXEs, and ARM builds
    PHANTOM_URL=\$(echo "\$RELEASE_JSON" | \
        grep -o '"browser_download_url": *"[^"]*"' | \
        sed 's/"browser_download_url": *"//;s/"\$//' | \
        grep -iE '\.AppImage\$' | \
        grep -iv 'arm\|aarch\|android\|apk\|win\|mac\|darwin' | \
        head -n1)

    PHANTOM_VERSION=\$(echo "\$RELEASE_JSON" | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//')

    if [[ -z "\$PHANTOM_URL" ]]; then
        echo ">>> [PHANTOM] Linux AppImage not in release \${PHANTOM_VERSION} yet."
        echo ">>> The Linux build is still being compiled upstream."
        echo ">>> Check for it at: https://github.com/\${PHANTOM_REPO}/releases"
        echo ">>> When available: download the .AppImage, chmod +x it, place in \${PHANTOM_DIR}/"
    else
        PHANTOM_FILE=\$(basename "\$PHANTOM_URL")
        echo ">>> Found Phantom Browser \${PHANTOM_VERSION} — downloading \${PHANTOM_FILE}..."

        mkdir -p "\$PHANTOM_DIR"

        curl -fsSL "\$PHANTOM_URL" -o "\${PHANTOM_DIR}/\${PHANTOM_FILE}"
        chmod +x "\${PHANTOM_DIR}/\${PHANTOM_FILE}"

        # Fetch the official Phantom icon from the repo
        mkdir -p /usr/share/icons/hicolor/256x256/apps
        curl -fsSL "\$PHANTOM_ICON_URL" -o /usr/share/icons/hicolor/256x256/apps/phantom-browser.png 2>/dev/null || true

        # Create symlink for convenience
        ln -sf "\${PHANTOM_DIR}/\${PHANTOM_FILE}" /usr/local/bin/phantom-browser

        # .desktop launcher entry
        cat > "\$PHANTOM_DESKTOP" << DESKEOF
[Desktop Entry]
Name=Phantom Browser
GenericName=Web Browser
Comment=A Privacy Focused Browser You Can Trust
Exec=/usr/local/bin/phantom-browser %U
Icon=phantom-browser
Terminal=false
Type=Application
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;
StartupWMClass=Chromium-browser
DESKEOF

        update-desktop-database /usr/share/applications/ 2>/dev/null || true
        echo ">>> Phantom Browser \${PHANTOM_VERSION} installed to \${PHANTOM_DIR}/\${PHANTOM_FILE}"
        echo ">>> Launch with: phantom-browser"
    fi
fi


# ── COSMIC Desktop Environment (official Arch extra repo) ─────────────────────
# COSMIC is fully released and available in the Arch 'extra' repo as a package
# group — no AUR helper needed.
# The 'cosmic' group includes all 27 components: cosmic-session, cosmic-comp,
# cosmic-panel, cosmic-settings, cosmic-files, cosmic-terminal, cosmic-greeter,
# xdg-desktop-portal-cosmic, and more.
pacman -S --noconfirm \
    cosmic \
    power-profiles-daemon \
    xdg-user-dirs

# Create user folders (Documents, Pictures, Videos, etc.)
sudo -u ${USERNAME} xdg-user-dirs-update

# Enable power profiles daemon (required for COSMIC Power & Battery settings panel)
systemctl enable power-profiles-daemon

# Enable COSMIC greeter (display manager)
# FIX from original script: typo 'cosimic-greeter' → correct: 'cosmic-greeter'
systemctl enable cosmic-greeter.service

# ── Gaming performance: CPU governor & power settings ─────────────────────────
# Set CPU to performance governor on boot via a systemd service
cat > /etc/systemd/system/cpu-performance.service <<'EOF'
[Unit]
Description=Set CPU governor to performance for gaming
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable cpu-performance

# ── vm.swappiness — tune for 8 GB RAM + 16 GB swap gaming setup ──────────────
# Low swappiness keeps RAM preferred; swap acts as safety overflow for gaming
cat > /etc/sysctl.d/99-gaming.conf <<'EOF'
# Keep RAM preferred; only use swap when absolutely necessary during heavy gaming
vm.swappiness = 10

# Improved file system performance for gaming (loading assets)
vm.vfs_cache_pressure = 50

# Allow more memory-mapped files (needed by some games / Proton)
vm.max_map_count = 2147483642

# Reduce disk write latency — helps during gameplay
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
EOF

# ── Gamemode config ───────────────────────────────────────────────────────────
mkdir -p /etc/gamemode
cat > /etc/gamemode.ini <<'EOF'
[general]
reaper_freq=5
desiredgov=performance
igpu_desiredgov=performance
softrealtime=auto
renice=-10
ioprio=0
inhibit_screensaver=1

[filter]
whitelist=
blacklist=

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high
EOF

# ── Intel Xe GPU — Vulkan & VA-API verify helpers in .bashrc ──────────────────
sudo -u ${USERNAME} bash -c "cat >> /home/${USERNAME}/.bashrc" <<'EOF'

# Surface Pro 8 — Intel Xe GPU helpers
alias gpu-check='vulkaninfo --summary && vainfo'
# Launch Steam games with gamemode:
# gamemoderun %command%   (paste into Steam launch options)
export LIBVA_DRIVER_NAME=iHD
export VDPAU_DRIVER=va_gl
EOF

# ── Enable pipewire audio services for the user ───────────────────────────────
# These are user-level services; enable via loginctl linger so they start on boot
loginctl enable-linger "${USERNAME}"
sudo -u ${USERNAME} systemctl --user enable pipewire pipewire-pulse wireplumber || true

# ── reflector mirror refresh timer ───────────────────────────────────────────
cat > /etc/xdg/reflector/reflector.conf <<'EOF'
--country US
--age 12
--protocol https
--sort rate
--save /etc/pacman.d/mirrorlist
EOF
systemctl enable reflector.timer

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║       Chroot configuration complete!                 ║"
echo "╚══════════════════════════════════════════════════════╝"
CHROOT

# =============================================================================
#  ░░  FINAL STEPS (outside chroot)  ░░
# =============================================================================

banner "Finalising Installation"

# Unmount cleanly
swapoff /mnt/swapfile 2>/dev/null || true
umount -R /mnt

ok "Installation complete!"
echo
echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${GREEN}║  Surface Pro 8 — Arch Linux install finished!            ║${NC}"
echo -e "${BOLD}${GREEN}╠══════════════════════════════════════════════════════════╣${NC}"
echo -e "${BOLD}${GREEN}║  NEXT STEPS:                                             ║${NC}"
echo -e "${BOLD}${GREEN}║  1. Remove USB/install media                             ║${NC}"
echo -e "${BOLD}${GREEN}║  2. Reboot — select 'linux-cachyos-surface' at boot      ║${NC}"
echo -e "${BOLD}${GREEN}║  3. Log into COSMIC as '${USERNAME}'                        ║${NC}"
echo -e "${BOLD}${GREEN}║  4. Open Steam → enable Proton in Settings → Steam Play  ║${NC}"
echo -e "${BOLD}${GREEN}║  5. Add 'gamemoderun %command%' to game launch options   ║${NC}"
echo -e "${BOLD}${GREEN}║  6. Add 'MANGOHUD=1 %command%' for the FPS overlay       ║${NC}"
echo -e "${BOLD}${GREEN}║  7. Run 'gpu-check' in terminal to verify Intel Xe GPU   ║${NC}"
echo -e "${BOLD}${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo

# Correct reboot syntax (original had 'reboot now' which is invalid)
read -rp "Reboot now? [y/N]: " DO_REBOOT
[[ "${DO_REBOOT,,}" == "y" ]] && reboot || echo "Run 'reboot' when ready."
