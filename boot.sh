#!/bin/bash

set -e

# Set install mode to online since boot.sh is used for curl installations
export OMARCHY_ONLINE_INSTALL=true

ansi_art='                 ▄▄▄                                                   
 ▄█████▄    ▄███████████▄    ▄███████   ▄███████   ▄███████   ▄█   █▄    ▄█   █▄ 
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   █▀   ███   ███  ███   ███
███   ███  ███   ███   ███ ▄███▄▄▄███ ▄███▄▄▄██▀  ███       ▄███▄▄▄███▄ ███▄▄▄███
███   ███  ███   ███   ███ ▀███▀▀▀███ ▀███▀▀▀▀    ███      ▀▀███▀▀▀███  ▀▀▀▀▀▀███
███   ███  ███   ███   ███  ███   ███ ██████████  ███   █▄   ███   ███  ▄██   ███
███   ███  ███   ███   ███  ███   ███  ███   ███  ███   ███  ███   ███  ███   ███
 ▀█████▀    ▀█   ███   █▀   ███   █▀   ███   ███  ███████▀   ███   █▀    ▀█████▀ 
                                       ███   █▀                                  '

clear
echo -e "\n$ansi_art\n"

# Validate sudo access and refresh timestamp to minimize password prompts
echo "🔐 Omarchy Mac Fedora installation requires administrator access..."
if ! sudo -v; then
  echo "❌ Error: sudo access required. Please run with proper permissions."
  exit 1
fi

# Keep sudo alive during bootstrap
keep_sudo_alive() {
  while true; do
    sudo -v
    sleep 50
  done
}

keep_sudo_alive &
SUDO_KEEPALIVE_PID=$!

# Cleanup on exit
trap 'sudo -k; kill ${SUDO_KEEPALIVE_PID:-} 2>/dev/null' EXIT INT TERM

# ============================================================================
# Fedora Asahi Validation & Branch Selection
# ============================================================================

if [[ ! -f /etc/fedora-release ]]; then
  echo -e "\n❌ Unsupported distro. Omarchy Mac Fedora supports Fedora Asahi Remix only."
  exit 1
fi

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo -e "\n❌ Unsupported architecture: $(uname -m). Fedora Asahi on aarch64 is required."
  exit 1
fi

# Fedora 44 or newer only, and the check has to happen here - before the dnf upgrade below and before
# an existing installation is replaced. Stopping later would leave a Fedora 43 user with their working
# Omarchy already deleted.
FEDORA_VERSION="$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID%%.*}")"

if [[ ! $FEDORA_VERSION =~ ^[0-9]+$ ]] || ((FEDORA_VERSION < 44)); then
  echo -e "\n[CRITICAL] Omarchy requires Fedora Asahi Remix 44 or newer. Detected: Fedora ${FEDORA_VERSION:-unknown}."
  echo
  echo "Nothing has been changed. Upgrade Fedora first, then re-run this installer:"
  echo
  echo "  sudo dnf upgrade --refresh"
  echo "  sudo dnf install dnf-plugin-system-upgrade"
  echo "  sudo dnf system-upgrade download --releasever=44"
  echo "  sudo dnf system-upgrade reboot"
  echo
  echo "The machine reboots into the upgrade, so close your work first."
  exit 1
fi

if ! grep -q "asahi" /proc/version 2>/dev/null; then
  echo -e "\n❌ Fedora Asahi kernel not detected."
  exit 1
fi

echo -e "\n🐧 Detected: \e[34mFedora Asahi Remix $FEDORA_VERSION\e[0m"
OMARCHY_BRANCH="${OMARCHY_REF:-fedora}"

echo -e "\n📦 Installing Omarchy for: \e[32m$OMARCHY_BRANCH\e[0m"


# ============================================================================
# Package Manager Setup (distro-specific, via abstraction)
# ============================================================================

echo -e "\n🔄 Updating system packages (dnf)..."
sudo dnf upgrade -y --refresh
sudo dnf install -y git

# ============================================================================
# Clone Repository
# ============================================================================

# Use custom repo if specified, otherwise default to malik-na/omarchy-mac-fedora
OMARCHY_REPO="${OMARCHY_REPO:-malik-na/omarchy-mac-fedora}"

echo -e "\nCloning Omarchy from: https://github.com/${OMARCHY_REPO}.git (branch: $OMARCHY_BRANCH)"

# Warn if existing installation will be overwritten
if [[ -d ~/.local/share/omarchy ]]; then
  echo -e "\n⚠️  \e[33mWarning: Existing Omarchy installation found at ~/.local/share/omarchy/\e[0m"
  echo "   This will be DELETED and replaced with a fresh clone."
  echo ""
  read -t 15 -p "   Continue and replace? (y/N, auto-cancels in 15s): " confirm
  echo ""
  if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "❌ Aborted. Your existing installation was preserved."
    echo "   To update without re-cloning, run: ~/.local/share/omarchy/install.sh"
    exit 1
  fi
fi

rm -rf ~/.local/share/omarchy/
git clone -b "$OMARCHY_BRANCH" "https://github.com/${OMARCHY_REPO}.git" ~/.local/share/omarchy >/dev/null

echo -e "\nInstallation starting..."
bash ~/.local/share/omarchy/install.sh
