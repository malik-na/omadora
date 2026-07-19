#!/bin/bash

set -e

# Curl-able bootstrap: validate the platform, clone the repo into
# ~/.local/share/omarchy, and hand off to install.sh.
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

echo "🔐 omarchy-mac-fedora installation requires administrator access..."
if ! sudo -v; then
  echo "❌ Error: sudo access required. Please run with proper permissions."
  exit 1
fi

keep_sudo_alive() {
  while true; do
    sudo -n -v >/dev/null 2>&1
    sleep 50
  done
}
keep_sudo_alive &
SUDO_KEEPALIVE_PID=$!
trap 'sudo -k; kill ${SUDO_KEEPALIVE_PID:-} 2>/dev/null' EXIT INT TERM

# --- Fedora Asahi validation -------------------------------------------------

if [[ ! -f /etc/fedora-release ]]; then
  echo -e "\n❌ Unsupported distro. omarchy-mac-fedora supports Fedora Asahi Remix only."
  exit 1
fi

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo -e "\n❌ Unsupported architecture: $(uname -m). Fedora Asahi on aarch64 is required."
  exit 1
fi

# Fedora 44 or newer only, and the check has to happen here - before the dnf
# upgrade below and before an existing installation is replaced. Stopping later
# would leave a Fedora 43 user with their working Omarchy already deleted.
FEDORA_VERSION="$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID%%.*}")"

if [[ ! $FEDORA_VERSION =~ ^[0-9]+$ ]] || ((FEDORA_VERSION < 44)); then
  echo -e "\n[CRITICAL] omarchy-mac-fedora requires Fedora Asahi Remix 44 or newer. Detected: Fedora ${FEDORA_VERSION:-unknown}."
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

if [[ "${OMARCHY_ASSUME_ASAHI:-0}" != "1" ]] && ! grep -q "asahi" /proc/version 2>/dev/null; then
  echo -e "\n❌ Fedora Asahi kernel not detected."
  echo -e "   (set OMARCHY_ASSUME_ASAHI=1 to run in a plain Fedora aarch64 VM for testing)"
  exit 1
fi

echo -e "\n🐧 Detected: \e[34mFedora Asahi Remix $FEDORA_VERSION\e[0m"

# --- Package manager refresh + git -------------------------------------------

echo -e "\n🔄 Updating system packages (dnf)..."
sudo dnf upgrade -y --refresh
sudo dnf install -y git

# --- Clone -------------------------------------------------------------------

OMARCHY_REPO="${OMARCHY_REPO:-eightscrow/omarchy-mac-fedora-quattro}"
OMARCHY_BRANCH="${OMARCHY_REF:-quattro}"

echo -e "\nCloning from https://github.com/${OMARCHY_REPO}.git (branch: ${OMARCHY_BRANCH})"

if [[ -d ~/.local/share/omarchy ]]; then
  echo -e "\n⚠️  \e[33mExisting installation found at ~/.local/share/omarchy/\e[0m"
  echo "   It will be DELETED and replaced with a fresh clone."
  echo
  read -t 15 -p "   Continue and replace? (y/N, auto-cancels in 15s): " confirm
  echo
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
