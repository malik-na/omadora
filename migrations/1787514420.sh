echo "Migrating initial login to SDDM"

# findmnt reports a btrfs root as /dev/mapper/x[/@]; the subvolume has to come
# off or lsblk cannot resolve it and an encrypted machine reads as unencrypted.

root_source=$(findmnt -no SOURCE / | sed 's/\[.*\]//')

if [[ $(lsblk -no TYPE "$root_source") != "crypt" ]]; then
  sudo rm -f /etc/sddm.conf.d/autologin.conf
fi
