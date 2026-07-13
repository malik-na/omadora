#!/bin/bash

# Through omarchy-battery-present, not a BAT* glob: Apple Silicon calls its battery macsmc-battery, so
# the glob found nothing and every MacBook was treated as a desktop - performance power profile, and no
# low-battery monitor.
if omarchy-battery-present; then
  # This computer runs on a battery
  powerprofilesctl set balanced || true

  # Enable battery monitoring timer for low battery notifications
  systemctl --user enable --now omarchy-battery-monitor.timer
else
  powerprofilesctl set performance || true
fi
