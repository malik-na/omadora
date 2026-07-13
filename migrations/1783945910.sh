echo "Enable the Ghostty COPR on machines that upgraded rather than reinstalled"

# A fresh install enables scottames/ghostty as an optional COPR, so `omarchy-install-terminal ghostty`
# has somewhere to install from. A machine that upgraded never ran that step: the Fedora 44 migration
# removed the dead pgdev/ghostty repo and added lionheartp, but nothing put the working Ghostty repo
# in its place. Picking Ghostty from the Omarchy menu then failed with nothing providing the package.
#
# Optional, exactly as in the installer: the default terminal is alacritty, and a Ghostty repo that is
# unreachable must never turn into a failed migration.

OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"

source "$OMARCHY_INSTALL/helpers/distro.sh"

is_fedora || exit 0

if [[ -f /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:scottames:ghostty.repo ]]; then
  exit 0
fi

echo "[INFO] Enabling COPR repository: scottames/ghostty"
sudo dnf copr enable -y scottames/ghostty ||
  echo "[WARNING] Ghostty COPR unavailable for this Fedora release - continuing"
