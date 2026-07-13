#!/bin/bash

# Distro detection and environment setup
# Sets OMARCHY_DISTRO to 'fedora' when supported

detect_distro() {
  if [[ -f /etc/fedora-release ]]; then
    echo "fedora"
  else
    echo "unknown"
  fi
}

# Set OMARCHY_DISTRO if not already set
if [[ -z "${OMARCHY_DISTRO:-}" ]]; then
  export OMARCHY_DISTRO="$(detect_distro)"
fi

# Helper to check if running on Fedora
is_fedora() {
  [[ "$OMARCHY_DISTRO" == "fedora" ]]
}

# Major Fedora release number (e.g. 44). Empty when not on Fedora.
fedora_version() {
  local version_id=""
  if [[ -r /etc/os-release ]]; then
    version_id="$(. /etc/os-release 2>/dev/null && echo "${VERSION_ID:-}")"
  fi
  echo "${version_id%%.*}"
}

# Omarchy on Fedora Asahi requires Fedora 44 or newer
OMARCHY_MIN_FEDORA_VERSION=44

is_fedora_supported_version() {
  local version
  version="$(fedora_version)"
  [[ "$version" =~ ^[0-9]+$ ]] && ((version >= OMARCHY_MIN_FEDORA_VERSION))
}

# Printed wherever we stop an F43 (or older) system: never upgrade the machine for the user.
fedora_upgrade_instructions() {
  cat <<INSTRUCTIONS
[CRITICAL] Omarchy $(cat "${OMARCHY_PATH:-$HOME/.local/share/omarchy}/version" 2>/dev/null || echo "3.8.2") requires Fedora Asahi Remix $OMARCHY_MIN_FEDORA_VERSION or newer.
Detected: Fedora $(fedora_version).

Nothing has been changed. Upgrade Fedora first, then re-run Omarchy:

  sudo dnf upgrade --refresh
  sudo dnf install dnf-plugin-system-upgrade
  sudo dnf system-upgrade download --releasever=$OMARCHY_MIN_FEDORA_VERSION
  sudo dnf system-upgrade reboot

The machine reboots into the upgrade, so close your work first. Fedora Asahi Remix
upgrade notes: https://docs.fedoraproject.org/en-US/quick-docs/upgrading-fedora-offline/

After the upgrade completes, run:

  omarchy-update
INSTRUCTIONS
}

# Helper kept for compatibility with existing scripts
is_arch() {
  return 1
}

# Check if running on Fedora Asahi specifically
is_fedora_asahi() {
  is_fedora && grep -q "asahi" /proc/version 2>/dev/null
}

# Helper kept for compatibility with existing scripts
is_arch_asahi() {
  return 1
}

echo "Distro: $OMARCHY_DISTRO"
