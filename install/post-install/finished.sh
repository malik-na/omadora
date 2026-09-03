#!/bin/bash
# Finished screen, ported from the 3.8.x installer: the logo, the install
# time, and the reboot prompt. Sourced by install.sh after stop_install_log,
# with helpers/presentation.sh already loaded.

# tte (terminaltexteffects) is in the base package set, so it is normally
# available by now; fall back to plain output when it is not.
if command -v tte &>/dev/null; then
  echo_in_style() {
    echo "$1" | tte --canvas-width 0 --anchor-text c --frame-rate 640 print
  }

  show_logo() {
    tte -i "$LOGO_PATH" --canvas-width 0 --anchor-text c --frame-rate 920 laseretch
  }
else
  echo_in_style() {
    echo "$1"
  }

  show_logo() {
    cat "$LOGO_PATH" 2>/dev/null || echo "  OMARCHY"
  }
fi

clear
echo
show_logo
echo

# stop_install_log wrote the duration as "Omarchy setup: XXm YYs".
TOTAL_TIME=$(tail -n 5 "$OMARCHY_INSTALL_LOG_FILE" 2>/dev/null | grep '^Omarchy setup:' | sed 's/^Omarchy setup:[[:space:]]*//')
if [[ -n $TOTAL_TIME ]]; then
  echo_in_style "Installed in $TOTAL_TIME"
else
  echo_in_style "Finished installing"
fi

# Drop the temporary installer sudoers rule here, not just in the EXIT trap:
# the trap must not race the shutdown when the user picks Reboot Now.
sudo rm -f /etc/sudoers.d/99-omarchy-installer 2>/dev/null || true

if [[ ${OMARCHY_SKIP_REBOOT_PROMPT:-0} == "1" ]]; then
  echo
  echo "[Omarchy] OMARCHY_SKIP_REBOOT_PROMPT=1 set, skipping reboot prompt."
  echo "Reboot to start Hyprland via SDDM."
else
  echo
  if gum confirm --show-help=false --default --affirmative "Reboot Now" --negative "" ""; then
    clear # Hide any shutdown messages
    sudo reboot 2>/dev/null
  else
    echo "Reboot to start Hyprland via SDDM."
  fi
fi
