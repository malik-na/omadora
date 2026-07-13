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

if ! grep -q "asahi" /proc/version 2>/dev/null; then
  echo -e "\n❌ Fedora Asahi kernel not detected."
  exit 1
fi

echo -e "\n🐧 Detected: \e[34mFedora Asahi Remix\e[0m"
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
