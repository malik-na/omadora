echo "Enable the battery monitor and the balanced power profile on Apple Silicon"

# The kernel calls the battery on Apple Silicon macsmc-battery, not BAT0, so every `BAT*` glob in this
# project found nothing on a Mac. The installer and migration 1752168292 both used one to decide whether
# the machine is a laptop, so every MacBook came up looking like a desktop: the performance power
# profile, and no low-battery notifications. Both of those already ran and are stamped, so repair the
# machines they left behind. omarchy-battery-present now identifies a battery by its type instead.

OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"

omarchy-battery-present || exit 0

powerprofilesctl set balanced || true

mkdir -p ~/.config/systemd/user
cp "$OMARCHY_PATH"/config/systemd/user/omarchy-battery-monitor.* ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now omarchy-battery-monitor.timer || true
