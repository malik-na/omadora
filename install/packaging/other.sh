#!/bin/bash
# Install the optional/build package set from omarchy-other.packages.fedora in a
# single transaction. Unlike base.sh's per-package loop, this list carries a dnf
# group (@development-tools) that a per-package availability check can't resolve,
# and nothing here is critical enough to fail the install over.
package_file="$OMARCHY_INSTALL/omarchy-other.packages.fedora"

packages=()
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  packages+=("$line")
done <"$package_file"

((${#packages[@]})) || exit 0

echo "[Omarchy] Installing optional and build packages..."
if ! sudo dnf install -y --skip-unavailable "${packages[@]}"; then
  echo "[WARNING] Some optional packages could not be installed - continuing"
fi
