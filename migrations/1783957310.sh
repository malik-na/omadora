echo "Remove blueman - bluetui is the Bluetooth UI"

# blueman was in the Fedora package list but nothing ever reached it: bluetui is installed on every
# machine and omarchy-launch-bluetooth prefers it. All blueman did was put a second, graphical Bluetooth
# app in the launcher. It stays a fallback in omarchy-launch-bluetooth for anyone who wants it back:
#
#   sudo dnf install blueman

rpm -q blueman >/dev/null 2>&1 || exit 0

echo "[INFO] Removing blueman"
sudo dnf remove -y --noautoremove blueman || echo "[WARNING] Could not remove blueman - continuing"
