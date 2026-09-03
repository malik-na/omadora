echo "Early-load the Apple HID drivers so the trackpad survives the boot race"

# install/hardware/apple/fix-asahi-hid-race.sh runs on new installs only, so
# existing ones keep losing the trackpad on unlucky boots until this runs it.
# See docs/apple-silicon-trackpad.md.
# Fedora Asahi uses dracut, not mkinitcpio.
hid_race_script="$OMARCHY_PATH/install/hardware/apple/fix-asahi-hid-race.sh"
conf="${OMARCHY_APPLE_HID_CONF:-/etc/dracut.conf.d/omarchy-apple-hid.conf}"

[[ -f $hid_race_script ]] || exit 0
[[ -f $conf ]] && exit 0 # already configured, by the installer or another user

# The leaf gates on the hardware itself and writes the drop-in, so running it
# keeps one copy of both. Anything that is not an Apple Silicon Mac writes
# nothing and falls out below.
bash -euo pipefail "$hid_race_script"
[[ -f $conf ]] || exit 0

# force_drivers reaches the boot only through a rebuilt initramfs, so the
# drop-in on its own would look applied and change nothing.
echo "Rebuilding the initramfs so the Apple HID drivers load early"
if ! sudo dracut -f; then
  echo "dracut failed. Run 'sudo dracut -f' to early-load the Apple HID drivers." >&2
  exit 0
fi

omarchy-state set reboot-required
