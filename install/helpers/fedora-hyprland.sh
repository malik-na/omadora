#!/bin/bash
# Hyprland core package selection for Fedora aarch64.
#
# lionheartp/Hyprland is the only aarch64 source for the compositor: Fedora proper ships hyprlang and
# hyprutils, but no hyprland, aquamarine or uwsm. Its stable `hyprland` package is built once per
# release, so when the COPR rebuilds hyprutils/aquamarine across an soname bump, stable stops
# resolving until it is rebuilt too. hyprland-0.55.4 was built 2026-06-11 against libhyprutils.so.12
# and libaquamarine.so.11; the 2026-07-18 library rebuilds moved those to .13 and .12 and left
# stable uninstallable.
#
# hyprland-git is rebuilt from git daily against the current libraries, so it covers those windows.
# The two packages conflict, so exactly one is ever installed.
#
# Stable is always preferred. This runs from the installer and from omarchy-update-manual-pkgs, so a
# machine parked on hyprland-git returns to stable on its own as soon as the COPR ships a working
# build - the user never has to do anything. The swap is a single dnf transaction: dnf resolves it
# fully before touching any package, so an attempt made while stable is still broken fails without
# disturbing the working hyprland-git install.

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"

is_fedora || exit 0

if rpm -q hyprland &>/dev/null; then
  echo "[hyprland] stable hyprland installed"
  exit 0
fi

if rpm -q hyprland-git &>/dev/null; then
  echo "[hyprland] on hyprland-git - checking whether stable has been rebuilt"
  if sudo dnf swap -y --refresh --allowerasing hyprland-git hyprland >/dev/null 2>&1; then
    echo "[hyprland] stable hyprland is available again - swapped off hyprland-git"
  else
    echo "[hyprland] stable hyprland still does not resolve - staying on hyprland-git"
  fi
  exit 0
fi

echo "[hyprland] installing the Hyprland core"
if sudo dnf install -y --refresh --allowerasing hyprland; then
  exit 0
fi

echo "[hyprland] stable hyprland does not resolve - falling back to hyprland-git"
sudo dnf install -y --refresh --allowerasing hyprland-git
