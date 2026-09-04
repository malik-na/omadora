echo "Install grub-btrfs so Snapper snapshots appear in the GRUB menu"

# Fresh installs run fedora-grub-btrfs.sh then config/grub-btrfs.sh. Existing
# machines often have snapper configs but no /etc/grub.d/41_snapshots-btrfs.
if [[ ! -d /boot/grub2 ]]; then
  exit 0
fi

if sudo test -x /etc/grub.d/41_snapshots-btrfs; then
  echo "grub-btrfs already installed"
else
  helper="$OMARCHY_PATH/install/helpers/fedora-grub-btrfs.sh"
  [[ -f $helper ]] || exit 0
  bash "$helper" || {
    echo "Warning: grub-btrfs install failed; snapshot boot menu unavailable" >&2
    exit 0
  }
fi

leaf="$OMARCHY_PATH/install/config/grub-btrfs.sh"
[[ -f $leaf ]] || exit 0
bash "$leaf" || true
