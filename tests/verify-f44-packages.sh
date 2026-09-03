#!/bin/bash

# Verify every package in the Fedora package lists resolves against a real repository.
#
# Evidence tool, not an installer: it never touches the system. It builds an offline index of
# package names from the official Fedora repodata plus every COPR project the installer enables,
# then reports any package that no repository provides.
#
# Usage:
#   tests/verify-f44-packages.sh              # check against Fedora 44 aarch64
#   FEDORA_RELEASE=43 tests/verify-f44-packages.sh
#   FEDORA_ARCH=x86_64 tests/verify-f44-packages.sh
#
# Exit codes: 0 = every package resolves, 1 = at least one package is unresolvable.

set -euo pipefail

FEDORA_RELEASE="${FEDORA_RELEASE:-44}"
FEDORA_ARCH="${FEDORA_ARCH:-aarch64}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/omarchy-verify/f$FEDORA_RELEASE-$FEDORA_ARCH"
MIRROR="https://dl.fedoraproject.org/pub/fedora/linux"

mkdir -p "$CACHE_DIR"

for tool in curl zstd gzip; do
  command -v "$tool" >/dev/null || { echo "Missing required tool: $tool" >&2; exit 1; }
done

# Package names served by a yum repository, one per line, read from its repodata.
#
# This asks the repository what it actually serves. Asking COPR's /package/list instead would
# answer a different question - what the project builds - and the two disagree: a project can
# list a package whose build for this chroot failed, and a chroot can still serve a package from
# an older successful build. Only the repodata is authoritative.
fetch_repo_names() {
  local url="$1" out="$2"
  [[ -s $out ]] && return 0

  local href
  href="$(curl -fsS --max-time 60 "$url/repodata/repomd.xml" 2>/dev/null |
    grep -o 'href="repodata/[^"]*primary\.xml[^"]*"' | head -1 | sed 's/href="//; s/"$//')" || true
  [[ -n $href ]] || return 1

  local decompress
  case "$href" in
    *.zst) decompress="zstd -d" ;;
    *.gz) decompress="gzip -d" ;;
    *) decompress="cat" ;;
  esac

  curl -fsS --max-time 300 "$url/$href" | $decompress |
    grep -o '<name>[^<]*</name>' | sed 's|<name>||; s|</name>||' | sort -u >"$out"
}

# What a COPR project serves for this release+arch. A project without the chroot serves nothing -
# which is exactly the failure we are hunting, so say so loudly rather than silently passing.
fetch_copr_project() {
  local owner="$1" project="$2" out="$3"
  [[ -s $out ]] && return 0

  local chroot="fedora-$FEDORA_RELEASE-$FEDORA_ARCH"
  local url="https://download.copr.fedorainfracloud.org/results/$owner/$project/$chroot"

  if ! fetch_repo_names "$url" "$out"; then
    echo "  [WARNING] COPR $owner/$project serves nothing for $chroot" >&2
    : >"$out"
  fi
}

# COPR projects the installer enables, "owner/project" per line.
copr_projects() {
  sed -n '/^COPR_REPOS=(/,/^)/p; /^OPTIONAL_COPR_REPOS=(/,/^)/p' "$REPO_ROOT/install/helpers/fedora-copr.sh" |
    grep -o '"[^"]*/[^"]*"' | tr -d '"'
}

# Packages the installer requests, one per line, comments and blanks stripped.
package_list() {
  grep -vE '^\s*#|^\s*$' "$1" | tr -d '\r' | sed 's/^\s*//; s/\s*$//'
}

echo "Verifying package lists against Fedora $FEDORA_RELEASE ($FEDORA_ARCH)"
echo

echo "Indexing official Fedora repositories..."
fetch_repo_names "$MIRROR/releases/$FEDORA_RELEASE/Everything/$FEDORA_ARCH/os" "$CACHE_DIR/release.txt"
fetch_repo_names "$MIRROR/updates/$FEDORA_RELEASE/Everything/$FEDORA_ARCH" "$CACHE_DIR/updates.txt"

echo "Indexing COPR projects..."
: >"$CACHE_DIR/copr.txt"
while read -r project; do
  owner="${project%%/*}"
  name="${project##*/}"
  echo "  $project"
  fetch_copr_project "$owner" "$name" "$CACHE_DIR/copr-$owner-$name.txt"
  cat "$CACHE_DIR/copr-$owner-$name.txt" >>"$CACHE_DIR/copr.txt"
done < <(copr_projects)

sort -u "$CACHE_DIR/release.txt" "$CACHE_DIR/updates.txt" "$CACHE_DIR/copr.txt" >"$CACHE_DIR/all.txt"
echo
echo "Index: $(wc -l <"$CACHE_DIR/all.txt") package names available"
echo

missing=0
for list in "$REPO_ROOT/install/omarchy-base.packages.fedora" "$REPO_ROOT/install/omarchy-other.packages.fedora"; do
  echo "== $(basename "$list")"
  while read -r pkg; do
    # Group installs (@name) are resolved by dnf against comps, not the package index.
    if [[ $pkg == @* ]]; then
      echo "  [SKIP]    $pkg (comps group - verify in the container run)"
      continue
    fi

    if grep -qxF "$pkg" "$CACHE_DIR/all.txt"; then
      continue
    fi

    echo "  [MISSING] $pkg"
    ((missing += 1))
  done < <(package_list "$list")
  echo
done

if ((missing > 0)); then
  echo "FAIL: $missing package(s) resolve against no repository for Fedora $FEDORA_RELEASE $FEDORA_ARCH"
  exit 1
fi

echo "PASS: every package resolves"
