systemctl enable bluetooth.service

# Power the adapter on at boot. This used to set AutoEnable=false to "persist the last power
# state", but nothing in the fork ever powers the adapter back on: on a clean install the
# controller came up Powered: no / Pairable: no every boot, so the Bluetooth panel scanned with a
# dead radio and found nothing, on hardware that was otherwise fine (hci0 present, unblocked,
# bluetoothd running). AutoEnable=true is the bluez default and what the pre-quattro forks rely on.
if [[ -f /etc/bluetooth/main.conf ]]; then
  sed -i 's/^#\?AutoEnable=.*/AutoEnable=true/' /etc/bluetooth/main.conf
fi
