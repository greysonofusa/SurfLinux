#!/usr/bin/env bash
# =============================================================================
#  SurfLinux — Post-Install EFI Boot, Secure Boot & UFW Configuration
# =============================================================================

set -euo pipefail

[[ $EUID -ne 0 ]] && echo "[FAIL] Must be run as root." >&2 && exit 1
[[ -d /sys/firmware/efi/efivars ]] || echo "[WARN] Not booted in UEFI mode. Bootloader may not install correctly."

echo ">>> Dynamically finding Root UUID..."
ROOT_UUID=$(findmnt -n -o UUID /)
if [[ -z "$ROOT_UUID" ]]; then
    echo "[FAIL] Could not determine UUID for the root partition. Are you in a chroot?" >&2
    exit 1
fi
echo "[ OK ] Root UUID: $ROOT_UUID"

# ── systemd-boot ─────────────────────────────────────────────────────────────
echo ">>> Installing systemd-boot..."
bootctl --esp-path=/boot/efi install

mkdir -p /boot/efi/loader/entries

cat > /boot/efi/loader/loader.conf <<EOF
default  arch-cachyos-surface.conf
timeout  4
console-mode max
editor   no
EOF

cat > /boot/efi/loader/entries/arch.conf <<EOF
title   Arch Linux (Surface Pro 8)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options root=UUID=${ROOT_UUID} rw quiet splash mem_sleep_default=s2idle i915.enable_psr=1 i915.enable_fbc=1 mitigations=off nohz_full=1-3 threadirqs nowatchdog ibt=off
EOF

cat > /boot/efi/loader/entries/arch-fallback.conf <<EOF
title   Arch Linux — Fallback (Surface Pro 8)
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux-fallback.img
options root=UUID=${ROOT_UUID} rw
EOF

cat > /boot/efi/loader/entries/arch-cachyos-surface.conf <<EOF
title   Arch Linux — linux-cachyos-surface (Surface Pro 8) [DEFAULT]
linux   /vmlinuz-linux-cachyos-surface
initrd  /intel-ucode.img
initrd  /initramfs-linux-cachyos-surface.img
options root=UUID=${ROOT_UUID} rw quiet splash mem_sleep_default=s2idle i915.enable_psr=1 i915.enable_fbc=1 mitigations=off nohz_full=1-3 threadirqs nowatchdog ibt=off
EOF

# ── Copy kernels to ESP ───────────────────────────────────────────────────────
echo ">>> Copying kernels to ESP..."
for f in vmlinuz-linux intel-ucode.img initramfs-linux.img initramfs-linux-fallback.img \
         vmlinuz-linux-cachyos-surface initramfs-linux-cachyos-surface.img initramfs-linux-cachyos-surface-fallback.img; do
    [ -f "/boot/$f" ] && cp "/boot/$f" /boot/efi/ || true
done

# ── Pacman hook for systemd-boot & sbctl sync ─────────────────────────────────
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
    [ -f /boot/$f ] && cp /boot/$f /boot/efi/; \
  done; \
  sbctl sign-all 2>/dev/null || true; \
  sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi 2>/dev/null || true'
EOF

# ── SECURE BOOT — sbctl ───────────────────────────────────────────────────────
echo ">>> Configuring Secure Boot keys..."
pacman -S --noconfirm --needed sbctl
sbctl create-keys

echo ">>> Signing systemd-boot loader..."
sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi
sbctl sign -s /boot/efi/EFI/systemd/systemd-bootx64.efi  2>/dev/null || true
sbctl sign -s /boot/efi/EFI/BOOT/BOOTX64.EFI             2>/dev/null || true

echo ">>> Signing kernels..."
sbctl sign -s /boot/efi/vmlinuz-linux-cachyos-surface 2>/dev/null || true
sbctl sign -s /boot/efi/vmlinuz-linux                 2>/dev/null || true

systemctl enable systemd-boot-update.service

# ── UFW Firewall Configuration ────────────────────────────────────────────────
echo ">>> Configuring UFW Firewall..."
pacman -S --noconfirm --needed ufw
systemctl enable ufw

# We use '|| true' here because 'ufw enable' cannot manipulate netfilter rules
# from inside a chroot environment. This ensures the defaults are set, but prevents 
# the script from crashing. The ufw.service enabled above will start it on actual boot.
ufw default deny incoming || true
ufw default allow outgoing || true
ufw enable || echo "[WARN] 'ufw enable' failed (expected inside a chroot). It will automatically activate on next boot."

echo ""
echo "[ OK ] Bootloader, Secure Boot, and Firewall logic complete!"
echo "If your UEFI is currently in Setup Mode, run 'sbctl enroll-keys -m' to finish Secure Boot."
