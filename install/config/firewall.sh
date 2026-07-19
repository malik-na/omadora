# Configure the firewall the Fedora way (firewalld), not UFW. Runs as root from
# omarchy-setup-system / install.sh, so no internal sudo.
if ! command -v firewall-cmd >/dev/null 2>&1; then
  echo "[WARN] firewalld is not available; skipping firewall setup"
  exit 0
fi

# Enable firewalld for the installed system. Don't --now it: inside an ISO chroot
# there is no running systemd to start it, and on a live git-clone install it is
# already running, so the reload at the end is what applies the rules.
if ! systemctl is-enabled firewalld >/dev/null 2>&1; then
  systemctl enable firewalld
fi

# LocalSend discovery and transfer ports.
firewall-cmd --permanent --add-port=53317/udp
firewall-cmd --permanent --add-port=53317/tcp

# Let Docker containers reach the host's DNS resolver on the docker0 bridge.
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="172.16.0.0/12" destination address="172.17.0.1" port protocol="udp" port="53" accept'

# Apply the permanent rules now if firewalld is running (live install). In a
# chroot it isn't, and the rules take effect when the installed system boots.
if systemctl is-active firewalld >/dev/null 2>&1; then
  firewall-cmd --reload
fi
