#!/bin/bash

# Fedora-specific package management helpers for Omarchy

LIONHEARTP_HYPRLAND_REPO="copr:copr.fedorainfracloud.org:lionheartp:Hyprland"

fedora_is_lionheartp_hypr_package() {
  local package="$1"
  case "$package" in
  hyprland | hyprland-uwsm | hyprland-qt-support | hyprland-guiutils | hyprsunset | hyprpicker | hyprwire | gpu-screen-recorder | xdg-desktop-portal-hyprland | aquamarine | hyprgraphics | hyprutils | hyprlang | hyprcursor | uwsm | libxkbcommon | libxkbcommon-x11 | kitty | kitty-kitten | kitty-shell-integration | kitty-terminfo)
    return 0
    ;;
  *)
    return 1
    ;;
  esac
}

fedora_install_package() {
  local package="$1"

  if fedora_is_lionheartp_hypr_package "$package"; then
    # Do NOT use --repo= here: dnf5's --repo restricts dependency resolution to
    # that single repo as well, so Mesa/Wayland/xcb deps can't be found on a
    # Fedora Minimal install. lionheartp already has priority=10 (set by
    # fedora-copr.sh), so DNF will prefer it for the Hyprland packages while
    # still pulling dependencies from base Fedora repos.
    sudo dnf install -y --refresh --allowerasing "$package"
    return $?
  fi

  sudo dnf install -y "$package"
}

fedora_package_installed() {
  rpm -q "$1" &>/dev/null
}

fedora_remove_package() {
  sudo dnf remove -y "$1"
}

fedora_update_system() {
  sudo dnf upgrade -y --refresh
}
