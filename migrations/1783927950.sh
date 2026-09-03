echo "Replace the packages Fedora 44 retired or renamed"

# A machine that came up from Fedora 43 still carries the retired packages as orphans, and a fresh
# Fedora 44 install has none of them. Both end in the same place here. Every step is guarded, so this
# is a no-op on a system that is already correct.

add_package() {
  local pkg="$1"

  rpm -q "$pkg" >/dev/null 2>&1 && return 0

  echo "[INFO] Installing $pkg"
  sudo dnf install -y "$pkg"
}

drop_package() {
  local pkg="$1"

  rpm -q "$pkg" >/dev/null 2>&1 || return 0

  echo "[INFO] Removing $pkg (gone from Fedora 44)"
  sudo dnf remove -y --noautoremove "$pkg"
}

# This guarantees the end state instead of only performing a swap. Some of these old names were never
# real packages even on Fedora 43 (gst-plugin-pipewire and wget resolved through Provides tags), so
# rpm never sees them installed - and a swap-only migration would silently leave the successor
# uninstalled.
replace_package() {
  local old="$1" new="$2"

  if rpm -q "$old" >/dev/null 2>&1; then
    echo "[INFO] Replacing $old with $new"
    # A swap, not an install: the pair can own the same files (wget and wget2-wget both own
    # /usr/bin/wget), so installing the new one alongside the old would be a file conflict.
    sudo dnf swap -y "$old" "$new" ||
      { sudo dnf remove -y --noautoremove "$old" && sudo dnf install -y "$new"; }
    return
  fi

  add_package "$new"
}

# The Java pin is what broke on Fedora 44 in the first place. java-latest-openjdk tracks whatever the
# current JDK is, so this cannot break again on Fedora 45. Omarchy only uses it for a mimetype
# association, so the JDK version itself does not matter.
replace_package java-21-openjdk java-latest-openjdk
replace_package gst-plugin-pipewire pipewire-gstreamer
replace_package wget wget2-wget

# No GTK2 theme in Fedora 44, and no webp gdk-pixbuf loader either - nothing ships one any more.
# glycin is what decodes images for GTK4 apps now, so glycin-loaders is what keeps webp rendering.
drop_package yaru-gtk2-theme
drop_package webp-pixbuf-loader
add_package glycin-loaders

# socat backs omarchy-hyprland-monitor-watch; mesa-vulkan-drivers is the Vulkan driver for the Apple
# GPU on Fedora (Fedora 44 retired the vendored Asahi Mesa).
add_package socat
add_package mesa-vulkan-drivers
