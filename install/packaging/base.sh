#!/bin/bash
# Install the base package set from omarchy-base.packages.fedora. Runs as the
# user; dnf is invoked through the package helpers, which sudo internally.
source "$OMARCHY_INSTALL/helpers/packages.sh"

package_file="$OMARCHY_INSTALL/omarchy-base.packages.fedora"

core_packages=()
optional_packages=()
in_optional=0
while IFS= read -r line; do
  [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
  if [[ "$line" == "OPTIONAL:" ]]; then
    in_optional=1
    continue
  fi
  if ((in_optional)); then
    optional_packages+=("$line")
  else
    core_packages+=("$line")
  fi
done <"$package_file"

# Let the user pick from the optional packages when gum and a TTY are available;
# otherwise take them all (unattended / curl installs).
if command -v gum &>/dev/null && ((${#optional_packages[@]} > 0)) && [[ -t 0 ]]; then
  echo -e "\e[34m[Omarchy] Select optional packages (space to toggle, enter to confirm):\e[0m"
  selected_optional=$(printf '%s\n' "${optional_packages[@]}" | gum choose --no-limit --height 20)
  mapfile -t selected_optional_pkgs <<<"$selected_optional"
else
  selected_optional_pkgs=("${optional_packages[@]}")
fi

packages=("${core_packages[@]}" "${selected_optional_pkgs[@]}")

# Install each package, skipping ones already present and collecting failures so
# a single missing package never aborts the whole base install.
failed_packages=()
for pkg in "${packages[@]}"; do
  [[ -z "$pkg" ]] && continue
  if omarchy_package_installed "$pkg"; then
    echo "[SKIPPED] $pkg (already installed)"
    continue
  fi

  if omarchy_install_package "$pkg"; then
    echo "[OK] $pkg"
  else
    echo "[FAILED] $pkg"
    if dnf list --available "$pkg" &>/dev/null; then
      failed_packages+=("$pkg")
    else
      failed_packages+=("$pkg (not found in dnf)")
    fi
  fi
done

echo
if ((${#failed_packages[@]} > 0)); then
  echo "==============================="
  echo "The following base packages could not be installed:"
  for pkg in "${failed_packages[@]}"; do
    echo "  - $pkg"
  done
  echo "==============================="
else
  echo -e "\e[32mAll base packages installed successfully!\e[0m"
fi
