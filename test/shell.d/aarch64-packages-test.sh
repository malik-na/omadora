#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

# Fedora Asahi installs from the .fedora package lists via dnf/COPR. The Arch
# omarchy-base.packages file is retained for upstream sync parity, but the
# authoritative aarch64 set on this fork is the Fedora list.
fedora_base="$ROOT/install/omarchy-base.packages.fedora"
fedora_other="$ROOT/install/omarchy-other.packages.fedora"
base_packages="$ROOT/install/omarchy-base.packages"
unavailable="$ROOT/install/omarchy-aarch64-unavailable.packages"

if [[ -f $fedora_base ]]; then
  grep -qxF zram-generator "$fedora_other" || grep -qxF zram-generator "$fedora_base" ||
    fail "fresh Fedora installs include zram-generator in the package set"
  pass "fresh Fedora installs include zram-generator in the package set"

  grep -qxF wf-recorder "$fedora_base" ||
    fail "fresh Fedora installs include wf-recorder for Apple Silicon capture"
  pass "fresh Fedora installs include wf-recorder for Apple Silicon capture"

  grep -qxF wpa_supplicant "$fedora_other" || grep -qxF wpa_supplicant "$fedora_base" ||
    fail "fresh Fedora installs include wpa_supplicant for NetworkManager Wi-Fi"
  pass "fresh Fedora installs include wpa_supplicant for NetworkManager Wi-Fi"
else
  grep -qxF zram-generator "$base_packages" ||
    fail "fresh installs include zram-generator in the default package set"
  pass "fresh installs include zram-generator in the default package set"
fi

# Arch-only unavailable list / pacman ARM repo coverage applies when those
# files still ship. On the Fedora fork they may be absent by design.
if [[ -f $unavailable && ! -f $fedora_base ]]; then
  mapfile -t unavailable_packages < <(grep -vE '^[[:space:]]*(#|$)' "$unavailable")
  (( ${#unavailable_packages[@]} )) || fail "the aarch64 unavailable list names at least one package"

  for package in "${unavailable_packages[@]}"; do
    grep -qxF "$package" "$base_packages" ||
      fail "every unavailable entry is in the default package set" "not in the set: $package"
  done
  pass "every unavailable entry is in the default package set"
fi

shopt -s nullglob
pacman_configs=("$ROOT"/default/pacman/pacman*.conf)
shopt -u nullglob
if ((${#pacman_configs[@]} > 0)); then
  for config in "${pacman_configs[@]}"; do
    grep -qF '[omarchy-aarch64]' "$config" ||
      fail "every shipped pacman config offers the Omarchy ARM repo" "missing in: $(basename "$config")"
    grep -A3 -F '[omarchy-aarch64]' "$config" | grep -qE '^Server[[:space:]]*=' ||
      fail "the ARM repo is reached by Server, not an Include" "in: $(basename "$config")"
  done
  pass "every shipped pacman config offers the Omarchy ARM repo"
else
  pass "Fedora fork ships no pacman configs (dnf/COPR instead)"
fi
