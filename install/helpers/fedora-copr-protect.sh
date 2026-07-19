#!/bin/bash

# Hyprland COPR repository protections.
#
# lionheartp/Hyprland is the single COPR source for the Hyprland stack (the Asahi-safe builds
# Omarchy targets). It gets priority=10 so dnf prefers it for those packages, with core
# GTK/Pango/Cairo excluded so they keep coming from Fedora proper.
#
# Sourced by fedora-copr.sh at install time and by the migration that repairs existing installs, so
# there is exactly one definition of what "protected" means.

LIONHEARTP_REPO_FILE="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lionheartp:Hyprland.repo"
LIONHEARTP_EXCLUDE_LINE="exclude=gtk4* gtk3* pango* cairo*"

# COPRs that earlier Omarchy versions enabled and that must not survive an upgrade:
#   technochip/Hyprland-aarch64  - no fedora-44 chroot at all
#   pgdev/ghostty                - the COPR project does not exist; it hard-failed the installer
#   solopasha/hyprland           - unmaintained (no builds since 2025-10); it only ever supplied
#                                  satty, which quattro retires. Removing it also removes the risk
#                                  of dnf mixing its stale Hyprland builds with lionheartp's.
#   erikreider/swayosd           - swayosd is retired by quattro (the shell draws the OSD)
DEAD_COPR_REPO_FILES=(
  "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:technochip:Hyprland-aarch64.repo"
  "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:pgdev:ghostty.repo"
  "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:solopasha:hyprland.repo"
  "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:erikreider:swayosd.repo"
)

fedora_remove_dead_copr_repos() {
  local repo_file
  for repo_file in "${DEAD_COPR_REPO_FILES[@]}"; do
    if [[ -f "$repo_file" ]]; then
      echo "[INFO] Removing dead COPR repository: $(basename "$repo_file")"
      sudo rm -f "$repo_file"
    fi
  done
}

fedora_apply_copr_protections() {
  if [[ -f "$LIONHEARTP_REPO_FILE" ]]; then
    sudo sed -i '/^priority=/d' "$LIONHEARTP_REPO_FILE"
    sudo sed -i '/^[[:space:]]*exclude=/d' "$LIONHEARTP_REPO_FILE"

    # Keep core GTK/Pango/Cairo coming from Fedora, not from the COPR.
    echo "priority=10" | sudo tee -a "$LIONHEARTP_REPO_FILE" >/dev/null
    echo "$LIONHEARTP_EXCLUDE_LINE" | sudo tee -a "$LIONHEARTP_REPO_FILE" >/dev/null
    echo "[OK] Lionheartp repo priority applied."
  fi
}
