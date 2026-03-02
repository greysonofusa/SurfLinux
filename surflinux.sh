#!/usr/bin/env bash
# =============================================================================
#  SurfLinux — Arch Linux Installer for Microsoft Surface Pro 8
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
#  ░░  USER CONFIGURATION
# =============================================================================

HOSTNAME="surface-arch"
USERNAME="gamer"
USER_PASS="CHANGEME_NOW"
ROOT_PASS="CHANGEME_NOW"

LOCALE="en_US.UTF-8"
KEYMAP="us"
TIMEZONE="America/Chicago"

DISK=""
SWAP_SIZE="16G"

# =============================================================================
#  ░░  SAFETY CHECKS & NETWORK
# =============================================================================

banner "SurfLinux — Surface Pro 8 Arch Linux Installer"

[[ $EUID -ne 0 ]] && die "Must be run as root from the Arch live ISO."

if [[ "$USER_PASS" == "CHANGEME_NOW" || "$ROOT_PASS" == "CHANGEME_NOW" ]]; then
    die "Please set USER_PASS and ROOT_PASS at the top of this script before running."
fi

[[ -d /sys/firmware/efi/efivars ]] || die "Not booted in UEFI mode. Check Surface UEFI settings."

banner "Checking Network"
if ! ping -c 2 archlinux.org &>/dev/null; then
    warn "No network detected. Attempting to bring up interfaces..."
    ip link set up "$(ip link | awk -F: '/^[0-9]+: w/{print $2; exit}' | tr -d ' ')" 2>/dev/null || true
    sleep 2
    ping -c 2 archlinux.org &>/dev/null || \
        die "No network. Connect via USB-C Ethernet or run iwctl to join Wi-Fi first."
fi
ok "Network is up."

# =============================================================================
#  ░░  DISK SELECTION & PARTITIONING
# =============================================================================

banner "Disk Setup"

if [[ -z "$DISK" ]]; then
    DISK=$(lsblk -dpnoNAME | grep "^/dev/nvme0" | head -n1)
    [[ -z "$DISK" ]] && DISK=$(lsblk -dpnoNAME | grep "^/dev/sd" | head -n1)
    [[ -z "$DISK" ]] && die "No suitable disk found. Set DISK= manually at the top of this script."
fi

info "Target disk: ${BOLD}${DISK}${NC}"
echo
lsblk "$DISK"
echo
read -rp "$(echo -e "${RED}${BOLD}ALL DATA ON ${DISK} WILL BE DESTROYED. Type 'yes' to continue: ${NC}")" CONFIRM
[[ "$CONFIRM" == "yes" ]] || die "Aborted by user."

info "Wiping and partitioning ${DISK}..."
wipefs -af "$DISK"
sgdisk -Z "$DISK"
sgdisk \
    -n 1:0:+1G   -t 1:ef00 -c 1:"EFI System Partition" \
    -n 2:0:0     -t 2:8300 -c 2:"Arch Linux Root"      \
    "$DISK"

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
#  ░░  SWAP FILE
# =============================================================================
banner "Creating 16 GB Swapfile"
fallocate -l "$SWAP_SIZE" /mnt/swapfile
chmod 0600 /mnt/swapfile
mkswap /mnt/swapfile
swapon /mnt/swapfile
ok "16 GB swapfile active."

# =============================================================================
#  ░░  BASE SYSTEM INSTALL
# =============================================================================
banner "Installing Base System (pacstrap)"
info "Updating mirrorlist..."
reflector --country US --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

sed -i '/^#\[multilib\]/,/^#Include/{s/^#//}' /etc/pacman.conf

pacstrap -K /mnt \
    base base-devel linux linux-headers linux-firmware \
    intel-ucode \
    e2fsprogs dosfstools \
    systemd \
    networkmanager \
    pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber \
    xdg-desktop-portal xdg-user-dirs \
    git curl wget nano \
    reflector \
    sudo

ok "Base system installed."

# =============================================================================
#  ░░  FSTAB
# =============================================================================
banner "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab
echo '/swapfile  none  swap  defaults  0 0' >> /mnt/etc/fstab
ok "fstab written (including persistent swapfile entry)."

# =============================================================================
#  ░░  CHROOT CONFIGURATION
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

# ── Enable multilib ───────────────────────────────────────────────────────────
sed -i '/^\[multilib\]/,/^Include/{s/^#//}' /etc/pacman.conf
sed -i '/^#\[multilib\]/,/^#Include/{s/^#//}' /etc/pacman.conf
pacman -Sy --noconfirm

# ── pacman tweaks ─────────────────────────────────────────────────────────────
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 10/' /etc/pacman.conf
sed -i 's/^#Color/Color/' /etc/pacman.conf

# ── Users & Passwords ─────────────────────────────────────────────────────────
echo "root:${ROOT_PASS}" | chpasswd
useradd -m -G wheel,audio,video,input,storage,games -s /bin/bash "${USERNAME}"
echo "${USERNAME}:${USER_PASS}" | chpasswd
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

mkinitcpio -P

# ── Networking ────────────────────────────────────────────────────────────────
systemctl enable NetworkManager

# ── Thermald ──────────────────────────────────────────────────────────────────
pacman -S --noconfirm thermald
systemctl enable thermald

# ── CachyOS repositories ──────────────────────────────────────────────────────
echo ">>> [INFO] Adding CachyOS x86-64-v3 optimized repositories..."
pacman -U --noconfirm --needed \
    "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-keyring-20240331-1-any.pkg.tar.zst" \
    "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-mirrorlist-22-1-any.pkg.tar.zst" \
    "https://mirror.cachyos.org/repo/x86_64/cachyos/cachyos-v3-mirrorlist-22-1-any.pkg.tar.zst"

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

# ── linux-surface repo ────────────────────────────────────────────────────────
curl -s https://pkg.surfacelinux.com/arch/sign.gpg | pacman-key --add -
pacman-key --lsign-key 56C464BAAC421952
cat >> /etc/pacman.conf <<'EOF'

[linux-surface]
Server = https://pkg.surfacelinux.com/arch/
EOF
pacman -Sy --noconfirm
pacman -S --noconfirm iptsd libwacom-surface

# ── linux-cachyos-surface kernel ───────────────────────────────────────────────
echo ">>> [INFO] Installing linux-cachyos-surface kernel..."
CACHYOS_SURFACE_REPO="jonpetersathan/linux-cachyos-surface"
CACHYOS_SURFACE_DIR="/tmp/cachyos-surface-kernel"
mkdir -p "\$CACHYOS_SURFACE_DIR"

RELEASE_JSON=\$(curl -fsSL "https://api.github.com/repos/\${CACHYOS_SURFACE_REPO}/releases/latest" 2>/dev/null || true)

if [[ -n "\$RELEASE_JSON" ]]; then
    mapfile -t PKG_URLS < <(echo "\$RELEASE_JSON" | \
        grep -o '"browser_download_url": *"[^"]*"' | \
        sed 's/"browser_download_url": *"//;s/"\$//' | \
        grep '\.pkg\.tar\.zst\$' | \
        grep -v 'lts')

    if [[ \${#PKG_URLS[@]} -gt 0 ]]; then
        for url in "\${PKG_URLS[@]}"; do
            fname=\$(basename "\$url")
            curl -fsSL "\$url" -o "\${CACHYOS_SURFACE_DIR}/\${fname}"
        done
        pacman -U --noconfirm \${CACHYOS_SURFACE_DIR}/*.pkg.tar.zst
    else
        echo ">>> [WARN] No prebuilt packages found in latest release — falling back to AUR build."
        pacman -S --noconfirm --needed base-devel git
        sudo -u ${USERNAME} bash -c '
            cd /tmp
            git clone https://aur.archlinux.org/paru-bin.git
            cd paru-bin && makepkg -si --noconfirm
            cd /tmp
            git clone https://github.com/jonpetersathan/linux-cachyos-surface.git
            cd linux-cachyos-surface/linux-cachyos-surface
            sed -i "s/_use_llvm_lto:=full/_use_llvm_lto:=thin/" PKGBUILD
            makepkg -si --noconfirm --skipinteg
        '
    fi
else
    echo ">>> [WARN] Could not reach GitHub API — falling back to AUR build."
    pacman -S --noconfirm --needed base-devel git
    sudo -u ${USERNAME} bash -c '
        cd /tmp
        git clone https://aur.archlinux.org/paru-bin.git
        cd paru-bin && makepkg -si --noconfirm
        paru -S --noconfirm linux-cachyos-surface
    '
fi

mkinitcpio -p linux-cachyos-surface
systemctl enable iptsd

# ── Gaming & Steam packages ────────────────────────────────────────────────────
pacman -S --noconfirm \
    steam lib32-mesa lib32-vulkan-intel vulkan-intel vulkan-tools \
    lib32-vulkan-icd-loader lib32-gcc-libs lib32-glibc gamemode \
    lib32-gamemode ttf-liberation intel-media-driver libva-utils \
    mesa-utils lib32-mesa-utils wine-staging winetricks \
    lib32-alsa-plugins lib32-libpulse lib32-openal sbctl

# ── Phantom Browser ───────────────────────────────────────────────────────────
PHANTOM_REPO="greysonofusa/degoogledchromium"
PHANTOM_DIR="/opt/phantom-browser"
PHANTOM_ICON_URL="https://raw.githubusercontent.com/greysonofusa/degoogledchromium/main/PhantomBrowserIcon.png"
PHANTOM_DESKTOP="/usr/share/applications/phantom-browser.desktop"

RELEASE_JSON=\$(curl -fsSL "https://api.github.com/repos/\${PHANTOM_REPO}/releases/latest" 2>/dev/null || true)
if [[ -n "\$RELEASE_JSON" ]]; then
    PHANTOM_URL=\$(echo "\$RELEASE_JSON" | grep -o '"browser_download_url": *"[^"]*"' | sed 's/"browser_download_url": *"//;s/"\$//' | grep -iE '\.AppImage\$' | grep -iv 'arm\|aarch\|android\|apk\|win\|mac\|darwin' | head -n1)
    if [[ -n "\$PHANTOM_URL" ]]; then
        PHANTOM_FILE=\$(basename "\$PHANTOM_URL")
        mkdir -p "\$PHANTOM_DIR"
        curl -fsSL "\$PHANTOM_URL" -o "\${PHANTOM_DIR}/\${PHANTOM_FILE}"
        chmod +x "\${PHANTOM_DIR}/\${PHANTOM_FILE}"
        mkdir -p /usr/share/icons/hicolor/256x256/apps
        curl -fsSL "\$PHANTOM_ICON_URL" -o /usr/share/icons/hicolor/256x256/apps/phantom-browser.png 2>/dev/null || true
        ln -sf "\${PHANTOM_DIR}/\${PHANTOM_FILE}" /usr/local/bin/phantom-browser
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
StartupWMClass=Chromium-browser
DESKEOF
        update-desktop-database /usr/share/applications/ 2>/dev/null || true
    fi
fi

# ── COSMIC Desktop ────────────────────────────────────────────────────────────
pacman -S --noconfirm cosmic power-profiles-daemon xdg-user-dirs
sudo -u ${USERNAME} xdg-user-dirs-update
systemctl enable power-profiles-daemon
systemctl enable cosmic-greeter.service

# ── Tuning & Helpers (RAPL, Throttled, Gamemode, i915) ────────────────────────
cat > /etc/systemd/system/cpu-performance.service <<'EOF'
[Unit]
Description=Set CPU governor and HWP hint to performance
After=multi-user.target
[Service]
Type=oneshot
ExecStart=/bin/sh -c '  echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor;   echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference 2>/dev/null || true'
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target
EOF
systemctl enable cpu-performance

cat > /etc/tmpfiles.d/intel-rapl-gaming.conf <<'EOF'
w /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw   - - - - 28000000
w /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_0_time_window_us   - - - - 32000000
w /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_1_power_limit_uw   - - - - 40000000
w /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_1_time_window_us   - - - - 10000
w /sys/devices/virtual/powercap/intel-rapl-mmio/intel-rapl-mmio:0/constraint_0_power_limit_uw - - - - 28000000
w /sys/devices/virtual/powercap/intel-rapl-mmio/intel-rapl-mmio:0/constraint_0_time_window_us - - - - 32000000
w /sys/devices/virtual/powercap/intel-rapl-mmio/intel-rapl-mmio:0/constraint_1_power_limit_uw - - - - 40000000
EOF

pacman -S --noconfirm --needed python python-dbus msr-tools s-tui lm_sensors irqbalance
sudo -u ${USERNAME} bash -c 'cd /tmp && git clone https://aur.archlinux.org/throttled.git && cd throttled && makepkg -si --noconfirm'

cat > /etc/throttled.conf <<'EOF'
[GENERAL]
Enabled: True
Sysfs_Power_Path: /sys/class/power_supply/*/online
[BATTERY]
PL1_Tdp_W: 15
PL1_Duration_s: 28
PL2_Tdp_W: 25
PL2_Duration_s: 0.002
Trip_Temp_C: 85
[AC]
PL1_Tdp_W: 28
PL1_Duration_s: 32
PL2_Tdp_W: 40
PL2_Duration_s: 0.002
Trip_Temp_C: 92
[UNDERVOLT.CORE]
Offset_mV: 0
[UNDERVOLT.GPU]
Offset_mV: 0
[UNDERVOLT.CACHE]
Offset_mV: 0
EOF
systemctl enable throttled
sensors-detect --auto 2>/dev/null || true
systemctl enable irqbalance

cat >> /etc/sysctl.d/99-gaming.conf <<'EOF'
vm.nr_hugepages = 0
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.max_map_count = 2147483642
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.dirty_writeback_centisecs = 1500
vm.dirty_expire_centisecs = 3000
kernel.sched_migration_cost_ns = 5000000
kernel.numa_balancing = 0
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_tw_reuse = 1
EOF

echo madvise > /sys/kernel/mm/transparent_hugepage/enabled 2>/dev/null || true
cat > /etc/tmpfiles.d/thp-madvise.conf <<'EOF'
w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
w /sys/kernel/mm/transparent_hugepage/defrag  - - - - defer+madvise
EOF

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
[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
[custom]
start=systemctl restart throttled
end=systemctl restart throttled
EOF

cat > /etc/modprobe.d/i915-gaming.conf <<'EOF'
options i915 enable_guc=3
options i915 enable_rc6=1
options i915 enable_fbc=1
options i915 enable_psr=1
EOF
mkinitcpio -P

sudo -u ${USERNAME} bash -c "cat >> /home/${USERNAME}/.bashrc" <<'EOF'
alias gpu-check='vulkaninfo --summary && echo "---" && vainfo'
alias thermals='s-tui'
alias fans='watch -n1 sensors'
alias powerlimits='cat /sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/constraint_*'
export LIBVA_DRIVER_NAME=iHD
export VDPAU_DRIVER=va_gl
EOF

loginctl enable-linger "${USERNAME}"
sudo -u ${USERNAME} systemctl --user enable pipewire pipewire-pulse wireplumber || true

cat > /etc/xdg/reflector/reflector.conf <<'EOF'
--country US
--age 12
--protocol https
--sort rate
--save /etc/pacman.d/mirrorlist
EOF
systemctl enable reflector.timer

CHROOT

# =============================================================================
#  ░░  FINAL STEPS (outside chroot)
# =============================================================================
banner "Finalising Installation"
swapoff /mnt/swapfile 2>/dev/null || true
umount -R /mnt
ok "Base Installation complete! (BOOTLOADER NOT YET INSTALLED)"
echo "You must now arch-chroot back in and run the post-install script."
