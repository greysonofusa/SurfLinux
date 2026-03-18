#!/usr/bin/env bash
# =============================================================================
#  SurfLinux — Post-Install EFI Boot, Secure Boot & UFW Configuration
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[ OK ]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()  { echo -e "${RED}[FAIL]${NC}  $*" >&2; exit 1; }

# =============================================================================
#  SAFETY CHECKS
# =============================================================================

[[ $EUID -ne 0 ]] && die "Must be run as root."

# FIX #1: UEFI check now hard-exits — continuing without UEFI mode means
# bootctl will fail and all ESP writes land on the root fs instead of the ESP.
[[ -d /sys/firmware/efi/efivars ]] || die "Not booted in UEFI mode. \
Cannot install systemd-boot without EFI variable access. \
Check your Surface UEFI settings and ensure Secure Boot is disabled before running this script."

# FIX #2 & #3: Verify the ESP is actually mounted before touching anything.
# Without this guard, every write to /boot/efi/ silently goes to the root
# filesystem instead of the EFI System Partition — bootloader never makes
# it onto the ESP and the system won't POST.
info "Checking ESP mount..."
if ! mountpoint -q /boot/efi; then
    die "/boot/efi is not mounted. Mount your EFI System Partition first:
  mount /dev/nvme0n1p1 /boot/efi   (adjust device as needed)
Then re-run this script."
fi
ok "ESP is mounted at /boot/efi."

# =============================================================================
#  ROOT UUID DETECTION
# =============================================================================

info "Finding root partition UUID..."
ROOT_UUID=$(findmnt -n -o UUID /)
[[ -z "$ROOT_UUID" ]] && die "Could not determine UUID for the root partition. \
If you are inside a chroot, make sure the root filesystem is properly mounted."
ok "Root UUID: $ROOT_UUID"

# =============================================================================
#  SYSTEMD-BOOT INSTALLATION
# =============================================================================

info "Installing systemd-boot to ESP..."
bootctl --esp-path=/boot/efi install

mkdir -p /boot/efi/loader/entries

cat > /boot/efi/loader/loader.conf <<EOF
default  arch-cachyos-surface.conf
timeout  4
console-mode max
editor   no
EOF

cat > /boot/efi/loader/entries/arch.conf <<EOF
title   Arch Linux — Stock Kernel (Surface Pro 8)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw quiet splash mem_sleep_default=s2idle i915.enable_psr=1 i915.enable_fbc=1 mitigations=off nohz_full=1-3 threadirqs nowatchdog ibt=off
EOF

# FIX (improvement): arch-fallback uses the cachyos-surface fallback initramfs,
# not the stock initramfs. A broken cachyos initramfs should fall back to the
# cachyos-surface fallback image — which still has Surface hardware drivers.
# The stock linux entry above already covers the generic emergency case.
cat > /boot/efi/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux — Fallback Initramfs (linux-cachyos-surface)
linux   /vmlinuz-linux-cachyos-surface
initrd  /intel-ucode.img
initrd  /initramfs-linux-cachyos-surface-fallback.img
options root=UUID=${ROOT_UUID} rw
EOF

cat > /boot/efi/loader/entries/arch-cachyos-surface.conf <<EOF
title   SurfLinux — linux-cachyos-surface [DEFAULT]
linux   /vmlinuz-linux-cachyos-surface
initrd  /intel-ucode.img
initrd  /initramfs-linux-cachyos-surface.img
options root=UUID=${ROOT_UUID} rw quiet splash mem_sleep_default=s2idle i915.enable_psr=1 i915.enable_fbc=1 mitigations=off nohz_full=1-3 threadirqs nowatchdog ibt=off
EOF

ok "Boot entries written."

# =============================================================================
#  COPY KERNELS TO ESP
# =============================================================================

info "Copying kernels and initramfs images to ESP..."
MISSING_KERNELS=()
for f in vmlinuz-linux intel-ucode.img initramfs-linux.img initramfs-linux-fallback.img \
         vmlinuz-linux-cachyos-surface initramfs-linux-cachyos-surface.img \
         initramfs-linux-cachyos-surface-fallback.img; do
    if [ -f "/boot/$f" ]; then
        cp "/boot/$f" /boot/efi/
        ok "Copied $f"
    else
        # FIX: Warn loudly on missing kernel files instead of silently skipping.
        # A missing vmlinuz-linux-cachyos-surface means the default boot entry
        # will fail at POST with "file not found" — the user must know now.
        warn "MISSING: /boot/$f — boot entry pointing to this file will fail!"
        MISSING_KERNELS+=("$f")
    fi
done

if [[ ${#MISSING_KERNELS[@]} -gt 0 ]]; then
    warn "The following kernel files were not found on /boot:"
    for f in "${MISSING_KERNELS[@]}"; do
        warn "  - $f"
    done
    warn "Install the missing kernel packages before rebooting."
fi

# =============================================================================
#  PACMAN HOOK — auto-sync ESP + re-sign on kernel/systemd upgrades
# =============================================================================

mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/95-systemd-boot.hook <<'EOF'
[Trigger]
Type = Package
Operation = Upgrade
Target = linux-cachyos-surface
Target = linux
Target = intel-ucode
Target = systemd

[Action]
Description = Syncing kernels to ESP and re-signing for Secure Boot...
When = PostTransaction
Exec = /bin/sh -c '\
  for f in vmlinuz-linux-cachyos-surface initramfs-linux-cachyos-surface.img \
            initramfs-linux-cachyos-surface-fallback.img vmlinuz-linux \
            intel-ucode.img initramfs-linux.img initramfs-linux-fallback.img; do \
    [ -f /boot/$f ] && cp /boot/$f /boot/efi/ || echo "[WARN] post-upgrade: /boot/$f not found"; \
  done; \
  sbctl sign-all 2>/dev/null || echo "[WARN] sbctl sign-all failed — run manually"; \
  sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi 2>/dev/null || true'
EOF

ok "Pacman hook written."

# =============================================================================
#  SECURE BOOT — sbctl
# =============================================================================

info "Installing sbctl..."
pacman -S --noconfirm --needed sbctl

# FIX #4: sbctl create-keys exits non-zero if keys already exist.
# With set -euo pipefail that aborts the whole script on a re-run.
# Guard by checking /var/lib/sbctl/keys/ — if the db key exists, keys are present.
if [[ -f /var/lib/sbctl/keys/db/db.key ]]; then
    ok "sbctl keys already exist — skipping create-keys."
else
    info "Generating Secure Boot signing keys..."
    sbctl create-keys
    ok "Secure Boot keys created."
fi

info "Signing systemd-boot loader (source + ESP copies)..."
# Sign the /usr/lib source — bootctl install/update auto-copies .signed to ESP
sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi \
    || warn "Could not sign /usr/lib/systemd/boot/efi/systemd-bootx64.efi — check sbctl keys."

# FIX: log sign failures instead of swallowing them with bare || true
sbctl sign -s /boot/efi/EFI/systemd/systemd-bootx64.efi \
    || warn "Could not sign /boot/efi/EFI/systemd/systemd-bootx64.efi (may not exist yet — OK after bootctl)"
sbctl sign -s /boot/efi/EFI/BOOT/BOOTX64.EFI \
    || warn "Could not sign /boot/efi/EFI/BOOT/BOOTX64.EFI (may not exist yet — OK after bootctl)"

info "Signing kernels..."
sbctl sign -s /boot/efi/vmlinuz-linux-cachyos-surface \
    || warn "Could not sign vmlinuz-linux-cachyos-surface — not present on ESP?"
sbctl sign -s /boot/efi/vmlinuz-linux \
    || warn "Could not sign vmlinuz-linux — not present on ESP?"

systemctl enable systemd-boot-update.service
ok "systemd-boot-update.service enabled."

# =============================================================================
#  UFW FIREWALL
# =============================================================================

info "Installing and configuring UFW..."
pacman -S --noconfirm --needed ufw
systemctl enable ufw

# These || true are intentional — ufw cannot manipulate netfilter from inside a
# chroot (no running kernel netfilter). The defaults are written to /etc/ufw/
# and ufw.service will enforce them on first real boot.
ufw default deny incoming  || true
ufw default allow outgoing || true
ufw enable \
    || warn "'ufw enable' failed (expected inside a chroot — ufw.service will activate on next boot)."

# =============================================================================
#  FIX (improvement): POST-RUN VERIFICATION
#  Show the user the full signing status and boot entry list before they reboot.
# =============================================================================

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  POST-INSTALL VERIFICATION${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════${NC}"

echo ""
info "sbctl status:"
sbctl status || true

echo ""
info "sbctl signing database (all registered files + signed status):"
sbctl list-files || true

echo ""
info "sbctl verify (unsigned files will be flagged):"
sbctl verify || true

echo ""
info "systemd-boot entries:"
bootctl list 2>/dev/null || bootctl status 2>/dev/null || true

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
ok "Bootloader, Secure Boot, and Firewall configuration complete!"
echo ""
echo -e "${YELLOW}SECURE BOOT ENROLLMENT — required before enabling SB in UEFI:${NC}"
echo "  1. Run: sudo sbctl enroll-keys -m"
echo "  2. Run: sudo shutdown now  (NOT reboot — Surface firmware quirk)"
echo "  3. Power on → hold Vol Up+Power → UEFI → Security → Enable Secure Boot"
echo "  4. Boot into SurfLinux and verify: sudo sbctl status"
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
