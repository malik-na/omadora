systemctl enable bluetooth.service

# Power the adapter on at boot. This used to set AutoEnable=false to "persist the last power
# state", but nothing in the fork ever powers the adapter back on: on a clean install the
# controller came up Powered: no / Pairable: no every boot, so the Bluetooth panel scanned with a
# dead radio (org.bluez.Error.NotReady) and found nothing, on hardware that was otherwise fine -
# hci0 present, neither soft- nor hard-blocked, bluetoothd running with its endpoints registered.
#
# Rewriting the line in place is not enough: bluez 5.87 on Fedora 44 ships main.conf without any
# AutoEnable line at all, commented or otherwise, so a sed substitution matched nothing and left
# the adapter off. Append the setting under [Policy] when it is missing.
if [[ -f /etc/bluetooth/main.conf ]]; then
  if grep -q '^#\?AutoEnable=' /etc/bluetooth/main.conf; then
    sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
  elif grep -q '^\[Policy\]' /etc/bluetooth/main.conf; then
    sed -i '/^\[Policy\]/a AutoEnable=true' /etc/bluetooth/main.conf
  else
    printf '\n[Policy]\nAutoEnable=true\n' >>/etc/bluetooth/main.conf
  fi
fi
