#!/bin/bash

# Fedora Asahi Minimal can land with LANG unset or C. Omarchy needs UTF-8 for
# sorting, \u escapes, and anything that reads the locale for its encoding.
# Arch uses locale.gen + locale-gen; Fedora uses glibc-langpack-* + localedef.
# This runs in preflight before $OMARCHY_PATH/bin is reliably on PATH, so use
# dnf/rpm/localedef directly.

locale_conf="${OMARCHY_LOCALE_CONF:-/etc/locale.conf}"

# Repair only the stock state -- an unset LANG, or the bare C/POSIX the image
# ships. Any named locale is somebody's choice, C.UTF-8 included, so leave it.
current=$(sed -n 's/^LANG=//p' "$locale_conf" 2>/dev/null | tail -1 | tr -d '"') || current=""

case ${current:-C} in
  C | POSIX) ;;
  *)
    echo "Leaving the locale as $current"
    return 0 2>/dev/null || exit 0
    ;;
esac

if (( ${EUID:-$(id -u)} == 0 )); then
  as_root=()
else
  as_root=(sudo)
fi

echo "Setting up locale (en_US.UTF-8)..."

if ! locale -a 2>/dev/null | grep -qi "en_US.utf-\?8"; then
  if ! rpm -q glibc-langpack-en &>/dev/null; then
    "${as_root[@]}" dnf install -y glibc-langpack-en >/dev/null 2>&1 ||
      echo "Warning: could not install glibc-langpack-en; trying localedef" >&2
  fi

  if ! locale -a 2>/dev/null | grep -qi "en_US.utf-\?8"; then
    "${as_root[@]}" localedef -i en_US -f UTF-8 en_US.UTF-8 >/dev/null 2>&1 ||
      echo "Warning: localedef could not create en_US.UTF-8" >&2
  fi
fi

echo "LANG=en_US.UTF-8" | "${as_root[@]}" tee "$locale_conf" >/dev/null

# The session that ran this keeps its inherited LANG; everything after it here
# should see the new one.
export LANG=en_US.UTF-8

echo "Locale set to en_US.UTF-8"
