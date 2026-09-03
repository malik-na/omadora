# NetworkManager enablement is centralized in enable-services.sh.
#
# Retire iwd and hand Wi-Fi to wpa_supplicant, NetworkManager's default and only
# non-experimental backend (NetworkManager.conf(5) marks iwd "(experimental)").
# Fedora Asahi Minimal can arrive with iwd driving Wi-Fi and a wifi.backend=iwd
# drop-in in place; left alone, NetworkManager hands connections to iwd, which
# rejects them with "net.connman.iwd.Failed: Operation failed" once its own
# credential store no longer matches the saved profile - the correct password is
# refused, with nothing in the UI explaining why. Disabling iwd without starting
# wpa_supplicant is worse still: NetworkManager is then left with no backend at
# all and every password prompt hangs, so both halves happen here, in order.
rm -f /etc/NetworkManager/conf.d/10-wifi-backend.conf
systemctl disable --now iwd.service 2>/dev/null || true
systemctl unmask wpa_supplicant.service 2>/dev/null || true
systemctl enable --now wpa_supplicant.service 2>/dev/null ||
  echo "[WARNING] Could not start wpa_supplicant - Wi-Fi may be unavailable"

# Asahi Alarm points NetworkManager at iwd in /etc/NetworkManager/conf.d, so
# disabling iwd alone leaves NetworkManager with a backend that never starts
# and no Wi-Fi devices at all. Hand the radio back to wpa_supplicant, which is
# also what install/hardware/apple/fix-brcmfmac-supplicant.sh assumes.
for network_manager_conf in /etc/NetworkManager/conf.d/*.conf; do
  [[ -f $network_manager_conf ]] || continue
  grep -qE '^[[:space:]]*wifi\.backend[[:space:]]*=[[:space:]]*iwd' "$network_manager_conf" || continue
  sed -i 's/^\([[:space:]]*wifi\.backend[[:space:]]*=[[:space:]]*\)iwd/\1wpa_supplicant/' "$network_manager_conf"
done

# Fresh Omarchy uses NetworkManager. Archinstall's legacy "copy ISO network"
# mode enabled systemd-networkd and dropped DHCP .network files that compete
# with NetworkManager, so retire that state whenever hardware setup runs.
for unit in \
  systemd-networkd.service \
  systemd-networkd.socket \
  systemd-networkd-varlink.socket \
  systemd-networkd-varlink-metrics.socket \
  systemd-networkd-resolve-hook.socket; do
  systemctl disable "$unit" 2>/dev/null || true
done

# Prevent systemd-networkd-wait-online timeout on boot.
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

stock_networkd_file() {
  local file="$1"

  [[ -f $file ]] || return 1
  case "$(basename "$file")" in
    20-ethernet.network|20-wlan.network|20-wwan.network) ;;
    *) return 1 ;;
  esac

  grep -Eq '^[[:space:]]*DHCP=yes[[:space:]]*$' "$file" || return 1
  grep -Eq '^[[:space:]]*Name=(en\*|eth\*|wl\*|ww\*)[[:space:]]*$' "$file" || return 1
}

backup_dir="/etc/systemd/network/omarchy-networkd-retired-$(date +%Y%m%d%H%M%S)"
for file in /etc/systemd/network/20-ethernet.network /etc/systemd/network/20-wlan.network /etc/systemd/network/20-wwan.network; do
  if stock_networkd_file "$file"; then
    install -d -m 0755 "$backup_dir"
    mv "$file" "$backup_dir/"
  fi
done

if systemctl is-active --quiet NetworkManager.service 2>/dev/null; then
  systemctl stop systemd-networkd.service 2>/dev/null || true
fi

# Prefer systemd-resolved's stub when it is already available. During a live
# install enable-services.sh only enables daemons; it deliberately does not
# start them before reboot. Do not replace a working resolver with a dangling
# stub link in that window, or later hardware setup loses network access.
if [[ -e /run/systemd/resolve/stub-resolv.conf ]]; then
  ln -sfn ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
elif [[ -e /run/NetworkManager/resolv.conf ]]; then
  ln -sfn ../run/NetworkManager/resolv.conf /etc/resolv.conf
fi
