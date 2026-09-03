#!/bin/bash

# Resolve the full Omarchy package set against a real Fedora aarch64 system.
#
# This is the strongest evidence we can get without Apple hardware: it enables the same COPR
# repositories the installer enables, then asks dnf to resolve and download every package we ask for -
# on the real target architecture, against the real repositories. It catches retired packages, renamed
# packages, missing COPR chroots, and cross-repository conflicts that a name-index check cannot see.
#
# It downloads only. It installs nothing, builds nothing, and touches nothing outside the container.
#
# Requires: podman, and aarch64 user-mode emulation registered with binfmt_misc
#   sudo pacman -S --needed qemu-user-static qemu-user-static-binfmt
#   sudo systemctl restart systemd-binfmt.service
#
# Usage:
#   tests/verify-f44-container.sh              # Fedora 44
#   FEDORA_RELEASE=43 tests/verify-f44-container.sh
#
# Exit codes: 0 = the whole set resolves, non-zero = it does not.

set -euo pipefail

FEDORA_RELEASE="${FEDORA_RELEASE:-44}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v podman >/dev/null || { echo "podman is required" >&2; exit 1; }
grep -q . /proc/sys/fs/binfmt_misc/qemu-aarch64 2>/dev/null ||
  { echo "aarch64 emulation is not registered - see the header of this script" >&2; exit 1; }

# COPR projects the installer enables, "owner/project" per line, required ones first.
copr_projects() {
  sed -n '/^COPR_REPOS=(/,/^)/p; /^OPTIONAL_COPR_REPOS=(/,/^)/p' "$REPO_ROOT/install/helpers/fedora-copr.sh" |
    grep -o '"[^"]*/[^"]*"' | tr -d '"'
}

# Packages the installer requests. Comps groups (@name) are passed through - dnf resolves them.
package_list() {
  grep -vE '^\s*#|^\s*$' "$1" | tr -d '\r' | sed 's/^\s*//; s/\s*$//'
}

coprs="$(copr_projects | tr '\n' ' ')"
packages="$( {
  package_list "$REPO_ROOT/install/omarchy-base.packages.fedora"
  package_list "$REPO_ROOT/install/omarchy-other.packages.fedora"
} | sort -u | tr '\n' ' ')"

echo "Resolving $(wc -w <<<"$packages") packages against Fedora $FEDORA_RELEASE (aarch64, emulated)"
echo

podman run --rm --arch arm64 "fedora:$FEDORA_RELEASE" bash -euo pipefail -c "
  echo '== Enabling COPR repositories'
  dnf -q -y install dnf5-plugins >/dev/null

  failed_copr=''
  for repo in $coprs; do
    if dnf -y copr enable \"\$repo\" >/dev/null 2>&1; then
      echo \"  ok       \$repo\"
    else
      echo \"  FAILED   \$repo\"
      failed_copr=\"\$failed_copr \$repo\"
    fi
  done

  echo
  echo '== Resolving the package set'
  if dnf -y --setopt=install_weak_deps=False install --downloadonly $packages; then
    resolved=0
  else
    resolved=1
  fi

  echo
  if [[ -n \$failed_copr ]]; then
    echo \"[WARNING] COPR repositories that could not be enabled:\$failed_copr\"
  fi
  if (( resolved != 0 )); then
    echo 'FAIL: dnf could not resolve the package set'
    exit 1
  fi
  echo 'PASS: dnf resolved and downloaded the whole package set'
"
