#!/bin/bash

has_snapper_config() {
  local config_name="$1"
  sudo snapper --csvout list-configs 2>/dev/null | awk -F, 'NR>1 {print $1}' | grep -qx "$config_name"
}

if ! sudo test -x /etc/grub.d/41_snapshots-btrfs; then
  echo "[SKIP] grub-btrfs script is missing; skipping GRUB snapshot integration"
  exit 0
fi

if ! has_snapper_config root; then
  echo "[SKIP] snapper root config missing; skipping GRUB snapshot integration"
  exit 0
fi

echo "[INFO] Creating initial root snapshot for GRUB menu"
sudo snapper -c root create --description "omarchy installer bootstrap snapshot" --cleanup-algorithm number || \
  echo "[WARN] Failed to create bootstrap snapshot"

echo "[INFO] Regenerating GRUB snapshots menu"
sudo /etc/grub.d/41_snapshots-btrfs || {
  echo "[WARN] Failed to run /etc/grub.d/41_snapshots-btrfs"
  exit 0
}

if [[ -d /boot/grub2 ]]; then
  if [[ -d /boot/efi/EFI ]]; then
    efi_cfg=$(find /boot/efi/EFI -name grub.cfg 2>/dev/null | head -1 || true)
    if [[ -n ${efi_cfg:-} ]]; then
      sudo grub2-mkconfig -o "$efi_cfg" || echo "[WARN] Failed to regenerate $efi_cfg"
    fi
  fi
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg || {
    echo "[WARN] Failed to regenerate /boot/grub2/grub.cfg"
    exit 0
  }
else
  echo "[WARN] /boot/grub2 not found; skipping grub2-mkconfig"
  exit 0
fi

if systemctl list-unit-files 2>/dev/null | grep -q '^grub-btrfsd\.service'; then
  sudo systemctl enable --now grub-btrfsd || echo "[WARN] Failed to enable grub-btrfsd"
else
  echo "[WARN] grub-btrfsd.service not found"
fi

echo "[OK] GRUB snapshot integration complete"
