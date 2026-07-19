#!/bin/bash

# Fedora-Asahi requirement gate for the git-clone install. Runs as the target
# user before anything is installed or changed, so a machine that fails a check
# is left exactly as it was.

source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/distro.sh"

fail() {
  echo -e "\e[31m[Omarchy] Requirement not met: $1\e[0m" >&2
  exit 1
}

# Fedora Asahi Remix only.
is_fedora || fail "Unsupported distro (Fedora Asahi Remix required)"

# Fedora 44+ is a hard stop, not a soft warning: half-installing quattro on an
# older release would leave the machine broken. Bail before any change and print
# the upgrade steps (we never upgrade Fedora for the user).
if ! is_fedora_supported_version; then
  fedora_upgrade_instructions
  exit 1
fi

# aarch64 (Apple Silicon) only. The fork drops every x86 hardware path.
arch="$(uname -m)"
[[ "$arch" == "aarch64" ]] || fail "Fedora Asahi Remix requires aarch64 hardware. Detected: $arch"

# Asahi kernel.
is_fedora_asahi || fail "Fedora Asahi kernel not detected"

# install.sh escalates with sudo where it needs to; running the whole thing as
# root would seed configs into root's home instead of the user's.
if ((EUID == 0)); then
  fail "Run the installer as your regular user, not root (it uses sudo when needed)"
fi

echo "Guards: OK"
