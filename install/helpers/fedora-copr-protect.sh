#!/bin/bash

# Hyprland COPR repository protections.
#
# Two COPRs build the same Hyprland packages: lionheartp (the Asahi-safe build Omarchy targets) and
# solopasha (which we only want for utilities like satty). Without a priority and an exclude list,
# DNF is free to mix them, which is how you end up with a half-upgraded Hyprland.
#
# Sourced by fedora-copr.sh at install time and by the migration that repairs existing installs, so
# there is exactly one definition of what "protected" means.

LIONHEARTP_REPO_FILE="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:lionheartp:Hyprland.repo"
SOLOPASHA_REPO_FILE="/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:solopasha:hyprland.repo"
LIONHEARTP_EXCLUDE_LINE="exclude=gtk4* gtk3* pango* cairo*"

# hyprland-qt-support is in the base package list and is built by both COPRs, so it belongs here -
# priority alone is not protection if lionheartp's build ever goes missing.
# hyprland-qtutils is deliberately NOT excluded: solopasha is our only source for it.
SOLOPASHA_EXCLUDE_LINE="excludepkgs=hyprland hyprland-devel hyprland-qt-support hyprlock hypridle hyprsunset hyprpicker hyprwire aquamarine hyprgraphics hyprutils hyprlang hyprcursor xdg-desktop-portal-hyprland uwsm"

# COPRs that earlier Omarchy versions enabled and that must not survive an upgrade:
#   technochip/Hyprland-aarch64  - no fedora-44 chroot at all
#   pgdev/ghostty                - the COPR project does not exist; it hard-failed the installer
DEAD_COPR_REPO_FILES=(
  "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:technochip:Hyprland-aarch64.repo"
  "/etc/yum.repos.d/_copr:copr.fedorainfracloud.org:pgdev:ghostty.repo"
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
  if [[ -f "$SOLOPASHA_REPO_FILE" ]]; then
    # Drop any previous protections first so re-running cannot stack duplicate lines.
    sudo sed -i '/^priority=/d' "$SOLOPASHA_REPO_FILE"
    sudo sed -i '/^excludepkgs=/d' "$SOLOPASHA_REPO_FILE"

    echo "priority=90" | sudo tee -a "$SOLOPASHA_REPO_FILE" >/dev/null
    echo "$SOLOPASHA_EXCLUDE_LINE" | sudo tee -a "$SOLOPASHA_REPO_FILE" >/dev/null
    echo "[OK] Solopasha repo limits applied."
  fi

  if [[ -f "$LIONHEARTP_REPO_FILE" ]]; then
    sudo sed -i '/^priority=/d' "$LIONHEARTP_REPO_FILE"
    sudo sed -i '/^[[:space:]]*exclude=/d' "$LIONHEARTP_REPO_FILE"

    # Keep core GTK/Pango/Cairo coming from Fedora, not from the COPR.
    echo "priority=10" | sudo tee -a "$LIONHEARTP_REPO_FILE" >/dev/null
    echo "$LIONHEARTP_EXCLUDE_LINE" | sudo tee -a "$LIONHEARTP_REPO_FILE" >/dev/null
    echo "[OK] Lionheartp repo priority applied."
  fi
}
