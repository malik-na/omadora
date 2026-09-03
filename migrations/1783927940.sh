echo "Remove dead COPR repositories and re-apply the Hyprland repo protections"

OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"

source "$OMARCHY_INSTALL/helpers/fedora-copr-protect.sh"

# technochip/Hyprland-aarch64 has no Fedora 44 chroot and pgdev/ghostty never existed at all. Both
# were enabled by earlier Omarchy versions and both break DNF on Fedora 44 if left behind.
fedora_remove_dead_copr_repos

# lionheartp is where Hyprland comes from now. Enabling it is idempotent.
if [[ ! -f "$LIONHEARTP_REPO_FILE" ]]; then
  echo "[INFO] Enabling COPR repository: lionheartp/Hyprland"
  sudo dnf copr enable -y lionheartp/Hyprland
fi

fedora_apply_copr_protections

sudo dnf makecache --refresh >/dev/null || true
