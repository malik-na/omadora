#!/bin/bash
# Enable required COPR repositories before package installation.
source "${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}/helpers/fedora-copr.sh"

if [[ -n ${OMARCHY_ONLINE_INSTALL:-} ]]; then
  # Install build tools. dnf5 dropped `groupinstall`; the group is installed by name with an @
  # prefix, the same form omarchy-other.packages.fedora already uses for it.
  sudo dnf install -y @development-tools

  # No need to configure mirrors for dnf (handled automatically)

  # Refresh all repos
  sudo dnf upgrade -y --refresh
fi
