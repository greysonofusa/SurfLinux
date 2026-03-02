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

# ── Networking & UFW ──────────────────────────────────────────────────────────
systemctl enable NetworkManager
pacman -S --noconfirm ufw
systemctl enable ufw
ufw default deny incoming
ufw default allow outgoing
ufw enable

# ── Thermald ──────────────────────────────────────────────────────────────────
pacman -S --noconfirm thermald
system
