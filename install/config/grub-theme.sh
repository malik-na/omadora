# Install Omarchy-branded GRUB theme and shorten the menu timeout.
# Arch uses Limine for this polish; Fedora Asahi boots GRUB.

echo "Configuring Omarchy GRUB theme"

if [[ ! -d /boot/grub2 ]]; then
  echo "[SKIP] /boot/grub2 missing; not a GRUB2 install"
  return 0 2>/dev/null || exit 0
fi

if command -v omarchy-refresh-grub >/dev/null 2>&1; then
  omarchy-refresh-grub || echo "[WARN] omarchy-refresh-grub failed"
  return 0 2>/dev/null || exit 0
fi

# Early install fallback before bin/ is on PATH.
theme_src="${OMARCHY_PATH}/default/grub/themes/omarchy"
theme_dst="/boot/grub2/themes/omarchy"
sudo mkdir -p "$theme_dst"
sudo cp -RT "$theme_src" "$theme_dst"

grub_default=/etc/default/grub
set_grub_key() {
  local key="$1" value="$2"
  if sudo grep -q "^${key}=" "$grub_default" 2>/dev/null; then
    sudo sed -i "s|^${key}=.*|${key}=${value}|" "$grub_default"
  else
    printf '%s=%s\n' "$key" "$value" | sudo tee -a "$grub_default" >/dev/null
  fi
}

set_grub_key GRUB_THEME "\"${theme_dst}/theme.txt\""
set_grub_key GRUB_TIMEOUT 3
set_grub_key GRUB_TIMEOUT_STYLE hidden
set_grub_key GRUB_DISTRIBUTOR "\"Omarchy\""

if [[ -d /boot/efi/EFI ]]; then
  efi_cfg=$(find /boot/efi/EFI -name grub.cfg 2>/dev/null | head -1 || true)
  [[ -n ${efi_cfg:-} ]] && sudo grub2-mkconfig -o "$efi_cfg" || true
fi
sudo grub2-mkconfig -o /boot/grub2/grub.cfg || echo "[WARN] grub2-mkconfig failed"

echo "[OK] Omarchy GRUB theme configured"
