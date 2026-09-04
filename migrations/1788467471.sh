echo "Install the Omarchy GRUB theme and shorten the boot menu timeout"

# Arch brands Limine; Fedora Asahi uses GRUB. Existing installs still show a
# plain 5-second menu until this runs.
if [[ ! -d /boot/grub2 ]]; then
  exit 0
fi

if omarchy-cmd-present omarchy-refresh-grub; then
  omarchy-refresh-grub
  exit 0
fi

leaf="$OMARCHY_PATH/install/config/grub-theme.sh"
[[ -f $leaf ]] || exit 0
# shellcheck disable=SC1090
source "$leaf"
