# Install the parts of default/ that belong to the system rather than to a user.
#
# Upstream ships these in the omarchy-settings Arch package, which drops them straight into /usr.
# The fork installs by git clone, so nothing was placing them at all: the SDDM theme
# install/login/sddm.sh selects, the systemd user units, the uwsm and environment.d drop-ins, the
# fontconfig rule and the Plymouth theme were all missing on a finished install. Runs as root from
# install.sh, so no internal sudo.
#
# Everything here is a copy from the checkout, so re-running refreshes the installed copies. The
# checkout stays the source of truth: an omarchy-update that changes these files needs this script
# (or the matching omarchy-refresh-* command) to run before the change reaches the system.

omarchy_default="$OMARCHY_PATH/default"

# SDDM theme and its Hyprland config. install/login/sddm.sh writes [Theme] Current=omarchy, so
# without this SDDM starts with a theme directory that does not exist.
install -d /usr/share/sddm/themes
cp -RT "$omarchy_default/sddm/omarchy" /usr/share/sddm/themes/omarchy
install -Dm644 "$omarchy_default/sddm/hyprland.lua" /usr/share/sddm/hyprland.lua

# Systemd units: the user services and paths the session expects, the sleep hook, and the
# faster-shutdown drop-in for user@.service.
install -d /usr/lib/systemd/user
cp -f "$omarchy_default"/systemd/user/*.service "$omarchy_default"/systemd/user/*.path \
  /usr/lib/systemd/user/
install -Dm755 "$omarchy_default/systemd/system-sleep/unmount-fuse" \
  /usr/lib/systemd/system-sleep/unmount-fuse
install -Dm644 "$omarchy_default/systemd/user@.service.d/faster-shutdown.conf" \
  /usr/lib/systemd/system/user@.service.d/faster-shutdown.conf

# Session environment drop-ins.
install -Dm644 "$omarchy_default/uwsm/env.d/10-omarchy" /usr/share/uwsm/env.d/10-omarchy
install -d /usr/lib/environment.d
cp -f "$omarchy_default"/environment.d/*.conf /usr/lib/environment.d/

# Fontconfig rule, enabled the way Fedora expects (conf.avail plus a symlink in conf.d).
install -Dm644 "$omarchy_default/fontconfig/conf.avail/50-omarchy.conf" \
  /usr/share/fontconfig/conf.avail/50-omarchy.conf
install -d /etc/fonts/conf.d
ln -sfn /usr/share/fontconfig/conf.avail/50-omarchy.conf /etc/fonts/conf.d/50-omarchy.conf

# Terminal preference list used by xdg-terminal-exec.
install -Dm644 "$omarchy_default/xdg-terminal-exec/hyprland-xdg-terminals.list" \
  /usr/share/xdg-terminal-exec/hyprland-xdg-terminals.list

# Plymouth boot theme. omarchy-refresh-plymouth copies into this directory without creating it, so
# creating it here is also what makes that command work later.
install -d /usr/share/plymouth/themes/omarchy
cp -RT "$omarchy_default/plymouth" /usr/share/plymouth/themes/omarchy

systemctl daemon-reload
