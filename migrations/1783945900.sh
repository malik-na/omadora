echo "Install the Flatpak apps that never made it onto the machine (Typora, LocalSend)"

# Every Fedora install so far ended up without Typora and LocalSend. The installer enables the
# Flathub remote in the user installation but then ran `flatpak install` without --user, so flatpak
# went looking for the system repository under /var/lib/flatpak - which dnf only creates on the next
# boot, not in the run that installs the flatpak package. The installs failed with
#
#   error: While opening repository /var/lib/flatpak/repo: ... No such file or directory
#
# and nothing checked the exit code, so the install reported success. This repairs the machines that
# were built that way. install/helpers/fedora-manual.sh now installs with --user for new machines.
#
# LocalSend is also what backs the "Send via LocalSend" entry in Nautilus: the extension hides itself
# when neither a localsend binary nor the Flatpak is present, so the entry has been missing too.

OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"

command -v flatpak >/dev/null 2>&1 || exit 0

flatpak remote-add --if-not-exists --user flathub https://dl.flathub.org/repo/flathub.flatpakrepo

install_flatpak() {
  local app="$1"

  flatpak info "$app" >/dev/null 2>&1 && return 0

  echo "[INFO] Installing $app from Flathub"
  flatpak install -y --user flathub "$app" || echo "[WARNING] Could not install $app - continuing"
}

command -v typora >/dev/null 2>&1 || install_flatpak io.typora.Typora
command -v localsend >/dev/null 2>&1 || install_flatpak org.localsend.localsend_app

# Redeploy the extension so the Nautilus entry appears without a reinstall. Nautilus only loads its
# Python extensions at startup, hence the restart.
if rpm -q nautilus-python >/dev/null 2>&1; then
  EXTENSIONS_DIR="$HOME/.local/share/nautilus-python/extensions"
  mkdir -p "$EXTENSIONS_DIR"
  cp "$OMARCHY_PATH/default/nautilus-python/extensions/localsend.py" "$EXTENSIONS_DIR/"
  nautilus -q 2>/dev/null || true
fi
