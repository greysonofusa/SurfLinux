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

banner "Disk Setup
