#!/bin/bash

# iwd is deliberately NOT enabled here. Enabling it while NetworkManager is still on the
# wpa_supplicant backend means that on the next boot both daemons claim the Wi-Fi device, and if the
# install is interrupted before post-install/network-finalize.sh writes the backend config, the user
# reboots into a machine with no Wi-Fi and no way to fix it. The backend swap - config, iwd, and
# wpa_supplicant - happens as one step at the very end, in post-install/network-finalize.sh.

# Prevent systemd-networkd-wait-online timeout on boot
sudo systemctl disable systemd-networkd-wait-online.service
sudo systemctl mask systemd-networkd-wait-online.service
