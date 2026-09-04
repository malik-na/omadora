# Install the Omarchy Plymouth theme and hide verbose boot logs.
# Arch does this via Limine/alt-bootloaders + install/login/plymouth.sh; Fedora
# Asahi boots m1n1 -> u-boot -> GRUB, so we set quiet/splash through grubby,
# /etc/default/grub, and /etc/kernel/cmdline, then rebuild initramfs with dracut.

echo "Configuring Omarchy Plymouth theme and quiet boot"

if ! command -v plymouth-set-default-theme >/dev/null 2>&1; then
  echo "[WARN] plymouth not installed; skipping boot splash setup"
  return 0 2>/dev/null || exit 0
fi

# Install theme files and select them. Initramfs rebuild is left to
# install/login/dracut.sh (fresh install) or omarchy-refresh-plymouth (manual).
theme_src="${OMARCHY_PATH}/default/plymouth"
theme_dst="/usr/share/plymouth/themes/omarchy"
sudo mkdir -p "$theme_dst"
sudo cp -RT "$theme_src" "$theme_dst"
sudo plymouth-set-default-theme omarchy

# Ensure plymouthd.conf selects omarchy (etc-files also ships this).
if [[ -f ${OMARCHY_PATH}/etc/plymouth/plymouthd.conf ]]; then
  sudo install -Dm644 "${OMARCHY_PATH}/etc/plymouth/plymouthd.conf" /etc/plymouth/plymouthd.conf
fi

append_cmdline_args() {
  local current="$1"
  # Drop duplicate tokens first (repeat runs used to stack quiet/splash/rootflags).
  current=$(awk '{
    for (i = 1; i <= NF; i++) if (!seen[$i]++) out = (out ? out " " : "") $i
    print out
  }' <<<"$current")
  local args=("quiet" "splash")
  local arg
  for arg in "${args[@]}"; do
    if [[ " $current " != *" $arg "* ]]; then
      current="${current:+$current }$arg"
    fi
  done
  echo "$current" | awk '{$1=$1; print}'
}

# /etc/default/grub — used when regenerating grub.cfg and by some tooling.
if [[ -f /etc/default/grub ]]; then
  for key in GRUB_CMDLINE_LINUX_DEFAULT GRUB_CMDLINE_LINUX; do
    if grep -q "^${key}=" /etc/default/grub; then
      current=$(grep "^${key}=" /etc/default/grub | head -1 | cut -d= -f2- | sed 's/^"//;s/"$//')
      new=$(append_cmdline_args "$current")
      sudo sed -i "s|^${key}=.*|${key}=\"${new}\"|" /etc/default/grub
    else
      echo "${key}=\"quiet splash\"" | sudo tee -a /etc/default/grub >/dev/null
    fi
  done
fi

# /etc/kernel/cmdline — Fedora BLS / kernel-install source of truth for new kernels.
cmdline_file=/etc/kernel/cmdline
if [[ -f $cmdline_file ]]; then
  current=$(tr -s '[:space:]' ' ' <"$cmdline_file" | sed 's/^ //;s/ $//')
  new=$(append_cmdline_args "$current")
  printf '%s\n' "$new" | sudo tee "$cmdline_file" >/dev/null
else
  printf 'quiet splash\n' | sudo tee "$cmdline_file" >/dev/null
fi

# Existing kernels: grubby updates BLS entries that GRUB actually boots.
if command -v grubby >/dev/null 2>&1; then
  sudo grubby --update-kernel=ALL --args="quiet splash" ||
    echo "[WARN] grubby could not add quiet/splash to existing kernels"
fi

# Regenerate grub.cfg when present so menu/cmdline stay in sync.
if [[ -d /boot/grub2 ]] && command -v grub2-mkconfig >/dev/null 2>&1; then
  if [[ -d /boot/efi/EFI ]]; then
    # Prefer the EFI grub.cfg Asahi/Fedora usually boots when writable.
    efi_cfg=$(find /boot/efi/EFI -name grub.cfg 2>/dev/null | head -1 || true)
    if [[ -n $efi_cfg ]]; then
      sudo grub2-mkconfig -o "$efi_cfg" || echo "[WARN] grub2-mkconfig failed for $efi_cfg"
    fi
  fi
  if [[ -e /boot/grub2/grub.cfg ]] || [[ ! -d /boot/efi/EFI ]]; then
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg || echo "[WARN] grub2-mkconfig failed for /boot/grub2/grub.cfg"
  fi
fi

echo "[OK] Plymouth theme set; quiet splash applied (reboot to see the splash)"
