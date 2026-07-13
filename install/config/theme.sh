#!/bin/bash
# Set links for Nautilius action icons
if [[ -d /usr/share/icons/Yaru/scalable/actions ]]; then
  sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-previous-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-previous-symbolic.svg
  sudo ln -snf /usr/share/icons/Adwaita/symbolic/actions/go-next-symbolic.svg /usr/share/icons/Yaru/scalable/actions/go-next-symbolic.svg
else
  echo "[SKIP] Yaru icon directory not present"
fi

# Setup user theme folder
mkdir -p ~/.config/omarchy/themes

# Add managed policy directories for Chromium and Brave for theme changes.
# Must exist before the first omarchy-theme-set, which writes color.json into them.
sudo mkdir -p /etc/chromium/policies/managed
sudo chmod a+rw /etc/chromium/policies/managed

sudo mkdir -p /etc/brave/policies/managed
sudo chmod a+rw /etc/brave/policies/managed

# Set initial theme
omarchy-theme-set "Tokyo Night"

# Force GNOME defaults for Fedora installs
if command -v gsettings >/dev/null 2>&1; then
  gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface icon-theme 'breeze-dark' >/dev/null 2>&1 || true
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' >/dev/null 2>&1 || true
fi

rm -rf ~/.config/chromium/SingletonLock # otherwise archiso will own the chromium singleton

# Set specific app links for current theme
mkdir -p ~/.config/btop/themes
ln -snf ~/.config/omarchy/current/theme/btop.theme ~/.config/btop/themes/current.theme

mkdir -p ~/.config/mako
ln -snf ~/.config/omarchy/current/theme/mako.ini ~/.config/mako/config

mkdir -p ~/.config/eza
ln -snf ~/.config/omarchy/current/theme/eza.yml ~/.config/eza/theme.yml

# Add managed policy directories for browsers for theme changes
for dir in /etc/chromium/policies/managed /etc/chromium-browser/policies/managed /etc/brave/policies/managed /etc/opt/chrome/policies/managed /etc/opt/edge/policies/managed; do
  sudo mkdir -p "$dir"
  sudo chmod a+rw "$dir"
done
