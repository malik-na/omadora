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

# Check if running on Fedora Asahi specifically.
# OMARCHY_ASSUME_ASAHI=1 forces this true for running the installer in a plain Fedora aarch64 VM
# (which has no Asahi kernel). It validates only the distro/session logic - never the Apple hardware
# paths (battery, keyboard backlight, wifi), which still require a real Mac.
is_fedora_asahi() {
  [[ "${OMARCHY_ASSUME_ASAHI:-0}" == "1" ]] && return 0
  is_fedora && grep -q "asahi" /proc/version 2>/dev/null
}

# Helper kept for compatibility with existing scripts
is_arch_asahi() {
  return 1
}

# To stderr, not stdout. Every command that sources this helper would otherwise start its output
# with this line, and callers that read a command's stdout would parse it as data - it made
# `omarchy-migrate --pending` look like it had one pending migration on a machine that had none.
# The install log captures both streams, so this stays just as visible there.
echo "Distro: $OMARCHY_DISTRO" >&2
