#!/bin/bash
set -e

echo "[Omarchy] Setting up console font for TTY..."

if ! command -v setfont &>/dev/null; then
  echo "[Omarchy] Installing kbd package..."
  sudo dnf install -y kbd
fi

echo "[Omarchy] Installing console-font.service..."
sudo cp ~/.local/share/omarchy/config/systemd/system/console-font.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable console-font.service

# The TTY font is cosmetic, and loading it needs a real VT: it fails on a serial or virtio console
# (and in an ISO chroot there is no systemd to start it at all). Enabling it is what matters - the
# service runs on the installed system at boot - so a failed immediate start must not stop the
# install.
sudo systemctl start console-font.service ||
  echo "[Omarchy] Console font could not be applied now; it will be set at boot."

echo "[Omarchy] Console font service installed and enabled."
