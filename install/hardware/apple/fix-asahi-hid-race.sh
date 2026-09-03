#!/bin/bash

# Apple Silicon (Asahi): the internal keyboard/trackpad HID devices from
# dockchannel-hid first bind to hid-generic, then get destroyed and re-created
# once hid_apple/hid_magicmouse load. That churn reshuffles the input event
# minors while udev, logind, and the compositor are starting; on unlucky boots
# logind's TakeDevice fails for the trackpad node (libseat "Couldn't open
# device") and libinput never retries, leaving the trackpad dead for the whole
# session. Loading the drivers from the initramfs makes the devices bind
# correctly on first registration, so the churn never happens.
# See docs/apple-silicon-trackpad.md.
if [[ $(uname -m) == "aarch64" ]] && grep -qi apple /proc/device-tree/compatible 2>/dev/null; then
  echo "Detected Apple Silicon Mac: early-loading Apple HID modules via dracut"

  modules=()
  for _omarchy_apple_hid_module in hid_apple hid_magicmouse; do
    if modinfo -k "$(uname -r)" "$_omarchy_apple_hid_module" >/dev/null 2>&1; then
      modules+=("$_omarchy_apple_hid_module")
    fi
  done

  if ((${#modules[@]} > 0)); then
    sudo mkdir -p /etc/dracut.conf.d
    # force_drivers pulls these into the initramfs so they bind before hid-generic.
    # Rebuild with `dracut -f` (or the next kernel install) for the change to take effect.
    printf 'force_drivers+=" %s "\n' "${modules[*]}" | sudo tee /etc/dracut.conf.d/omarchy-apple-hid.conf >/dev/null
  fi
fi
