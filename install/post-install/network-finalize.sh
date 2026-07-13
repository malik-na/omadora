#!/bin/bash
# Finalize Fedora network backend at the end of installer flow.
# This is intentionally late to avoid dropping Wi-Fi during package/build steps.

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"

if ! is_fedora; then
  exit 0
fi

ensure_iwd_backend() {
  local backend_conf="/etc/NetworkManager/conf.d/10-wifi-backend.conf"

  if ! command -v NetworkManager >/dev/null 2>&1 && ! rpm -q NetworkManager >/dev/null 2>&1; then
    echo "[WARN] NetworkManager is not installed; skipping iwd backend finalize"
    return 1
  fi

  if ! rpm -q iwd >/dev/null 2>&1; then
    echo "[INFO] Installing iwd backend package"
    sudo dnf install -y iwd || {
      echo "[WARN] Failed to install iwd"
      return 1
    }
  else
    echo "[OK] iwd already installed"
  fi

  sudo mkdir -p /etc/NetworkManager/conf.d
  if [[ ! -f "$backend_conf" ]] || ! grep -q '^\s*wifi\.backend\s*=\s*iwd\s*$' "$backend_conf"; then
    printf '[device]\nwifi.backend=iwd\n' | sudo tee "$backend_conf" >/dev/null || {
      echo "[WARN] Failed to write NetworkManager iwd backend config"
      return 1
    }
    echo "[OK] Set NetworkManager Wi-Fi backend to iwd"
  else
    echo "[OK] NetworkManager already configured with wifi.backend=iwd"
  fi

  # From here on the machine's only network link is being swapped underneath it. If iwd does not come
  # up, the config above would point NetworkManager at a backend that is not running - no Wi-Fi, on a
  # laptop whose owner may have no other way back online. So every failure rolls back to the working
  # wpa_supplicant setup instead of leaving the machine half-swapped.
  rollback_to_wpa_supplicant() {
    echo "[WARNING] Rolling back to the wpa_supplicant backend"
    sudo rm -f "$backend_conf"
    sudo systemctl disable --now iwd >/dev/null 2>&1 || true
    sudo systemctl enable --now wpa_supplicant >/dev/null 2>&1 || true
    sudo systemctl restart NetworkManager >/dev/null 2>&1 || true
  }

  if ! sudo systemctl enable --now iwd >/dev/null 2>&1; then
    echo "[WARN] Failed to enable iwd service"
    rollback_to_wpa_supplicant
    return 1
  fi

  if ! systemctl is-active --quiet iwd; then
    echo "[WARN] iwd did not start"
    rollback_to_wpa_supplicant
    return 1
  fi

  sudo systemctl disable --now wpa_supplicant >/dev/null 2>&1 || true

  if ! sudo systemctl restart NetworkManager >/dev/null 2>&1; then
    echo "[WARN] Failed to restart NetworkManager"
    rollback_to_wpa_supplicant
    return 1
  fi

  echo "[OK] iwd backend finalized"
}

echo "[Omarchy/Fedora] Finalizing network backend at end of install..."
ensure_iwd_backend || echo "[WARN] Network backend finalize failed"
