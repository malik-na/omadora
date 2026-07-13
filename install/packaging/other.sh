#!/bin/bash
source "$OMARCHY_INSTALL/helpers/packages.sh"

# base.sh only ever reads omarchy-base.packages.fedora, so nothing installed this list - the optional
# and build-time half of the package set. A clean install came up with no `wget` at all and no
# GStreamer PipeWire plugin, while a machine that upgraded got both from the Fedora 44 package
# migration. The two paths now end in the same place.

package_file="$OMARCHY_INSTALL/omarchy-other.packages.fedora"

packages=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  packages+=("$line")
done <"$package_file"

((${#packages[@]})) || exit 0

# One transaction with --skip-unavailable, rather than base.sh's per-package loop: the list carries a
# dnf group (@development-tools) that a per-package `dnf list --available` check cannot resolve, and
# nothing in here is critical enough to fail an install over.
echo "[Omarchy] Installing optional and build packages..."
if ! sudo dnf install -y --skip-unavailable "${packages[@]}"; then
  echo "[WARNING] Some optional packages could not be installed - continuing"
fi
