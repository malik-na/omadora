#!/bin/bash
# Fedora first-party tool installs for Omarchy quattro (aarch64 only).
#
# These are Omarchy's own tools. None ships a Fedora or COPR package for aarch64, so each comes from
# an upstream release binary or a source build. Versions are pinned; a matching stamp under
# ~/.local/state/omarchy/first-party makes re-runs (and omarchy-update-manual-pkgs) no-ops until the
# pin changes. A single tool failing only warns - it never aborts the install.

OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"

is_fedora || exit 0

if [[ "$(uname -m)" != "aarch64" ]]; then
  echo "[first-party] not aarch64 - skipping first-party tool installs"
  exit 0
fi

# Version pins (bump here; the stamp comparison then rebuilds/redownloads on the next update).
AETHER_VER="4.27.2"
CLIAMP_VER="1.57.1"
TENSAKU_VER="0.26.6"
VOXTYPE_VER="0.7.5"
OMACUT_VER="0.1.2"
OMAWRITE_VER="0.2.0"
SHARE_PICKER_VER="0.2.1"
SHARE_PICKER_PROTO="3a5c2bda1c1a4e55cc1330c782547695a93f05b2"
# tobi-try is a Ruby script pulled from github.com/tobi/try at a pinned commit (its own release tag).
TOBI_TRY_VER="1.8.1"
TOBI_TRY_COMMIT="d1bc484cc31a34db3d287550f4800e9a6e56bacd"

STATE_DIR="$HOME/.local/state/omarchy/first-party"
mkdir -p "$STATE_DIR"

# stamped <tool> <version> - true when the installed stamp already matches the pin.
stamped() { [[ -f "$STATE_DIR/$1" && "$(cat "$STATE_DIR/$1" 2>/dev/null)" == "$2" ]]; }
stamp() { echo "$2" >"$STATE_DIR/$1"; }
warn() { echo "[first-party] [WARN] $*" >&2; }

# install_bin <url> <dest-name> [mode] - download a single binary into /usr/local/bin.
install_bin() {
  local url="$1" name="$2" mode="${3:-755}" tmp
  tmp="$(mktemp)"
  if curl -fL "$url" -o "$tmp"; then
    sudo install -Dm"$mode" "$tmp" "/usr/local/bin/$name"
    rm -f "$tmp"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# install_share <src-file> <dest-path> [mode] - install a support file (desktop/icon) under /usr/share.
install_share() {
  local src="$1" dest="$2" mode="${3:-644}"
  [[ -f "$src" ]] || return 0
  sudo install -Dm"$mode" "$src" "$dest"
}

need_build_deps() {
  # Install build dependencies once; they stay so omarchy-update-manual-pkgs can rebuild on a bump.
  sudo dnf install -y -q "$@" >/dev/null 2>&1
}

# --- aether: wallpaper-driven theming app (release binaries + desktop/icon from the source tag) ---
install_aether() {
  stamped aether "$AETHER_VER" && return 0
  echo "Installing aether $AETHER_VER (release binary)..."
  local base="https://github.com/bjarneo/aether/releases/download/v${AETHER_VER}"
  install_bin "$base/aether-linux-arm64" aether || { warn "aether download failed"; return 1; }
  install_bin "$base/aether-wp-linux-arm64" aether-wp || warn "aether-wp download failed"

  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/bjarneo/aether/archive/refs/tags/v${AETHER_VER}.tar.gz" | tar -xz -C "$tmp"; then
    install_share "$tmp/aether-${AETHER_VER}/build/linux/aether.desktop" /usr/share/applications/aether.desktop
    install_share "$tmp/aether-${AETHER_VER}/icon.png" /usr/share/pixmaps/aether.png
  fi
  rm -rf "$tmp"
  stamp aether "$AETHER_VER"
}

# --- cliamp: terminal music player (release binary with statically linked codecs) ---
install_cliamp() {
  stamped cliamp "$CLIAMP_VER" && return 0
  echo "Installing cliamp $CLIAMP_VER (release binary)..."
  install_bin "https://github.com/bjarneo/cliamp/releases/download/v${CLIAMP_VER}/cliamp-linux-arm64" cliamp \
    || { warn "cliamp download failed"; return 1; }
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/bjarneo/cliamp/archive/refs/tags/v${CLIAMP_VER}.tar.gz" | tar -xz -C "$tmp"; then
    install_share "$tmp/cliamp-${CLIAMP_VER}/cliamp.desktop" /usr/share/applications/cliamp.desktop
    install_share "$tmp/cliamp-${CLIAMP_VER}/Cliamp.png" /usr/share/pixmaps/cliamp.png
  fi
  rm -rf "$tmp"
  stamp cliamp "$CLIAMP_VER"
}

# --- tensaku: Wayland screenshot annotation (prebuilt aarch64 tarball) ---
install_tensaku() {
  stamped tensaku "$TENSAKU_VER" && return 0
  echo "Installing tensaku $TENSAKU_VER (release tarball)..."
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/jondkinney/tensaku/releases/download/v${TENSAKU_VER}/tensaku-v${TENSAKU_VER}-aarch64.tar.gz" | tar -xz -C "$tmp"; then
    local dir
    dir="$(find "$tmp" -maxdepth 2 -name tensaku -type f -exec dirname {} \; | head -1)"
    dir="${dir:-$tmp}"
    sudo install -Dm755 "$dir/tensaku" /usr/local/bin/tensaku
    sudo install -Dm755 "$dir/tensaku-edit" /usr/local/bin/tensaku-edit
    stamp tensaku "$TENSAKU_VER"
  else
    warn "tensaku download failed"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

# --- voxtype: push-to-talk dictation (prebuilt aarch64 CPU binary; v1.0+ dropped Linux aarch64) ---
install_voxtype() {
  stamped voxtype "$VOXTYPE_VER" && return 0
  echo "Installing voxtype $VOXTYPE_VER (release binary, aarch64-cpu)..."
  install_bin "https://github.com/peteonrails/voxtype/releases/download/v${VOXTYPE_VER}/voxtype-${VOXTYPE_VER}-linux-aarch64-cpu" voxtype \
    || { warn "voxtype download failed"; return 1; }
  stamp voxtype "$VOXTYPE_VER"
}

# --- tobi-try: `try` ephemeral-workspace command (Ruby script from tobi/try at a pinned commit) ---
install_tobi_try() {
  stamped tobi-try "$TOBI_TRY_VER" && return 0
  echo "Installing tobi-try $TOBI_TRY_VER (Ruby script)..."
  local raw="https://raw.githubusercontent.com/tobi/try/${TOBI_TRY_COMMIT}" tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "$raw/try.rb" -o "$tmp/try.rb" &&
    curl -fsSL "$raw/lib/fuzzy.rb" -o "$tmp/fuzzy.rb" &&
    curl -fsSL "$raw/lib/tui.rb" -o "$tmp/tui.rb"; then
    sed -i '1c#!/usr/bin/ruby' "$tmp/try.rb"
    sudo install -Dm755 "$tmp/try.rb" /usr/lib/tobi-try/try.rb
    sudo install -Dm644 "$tmp/tui.rb" /usr/lib/tobi-try/lib/tui.rb
    sudo install -Dm644 "$tmp/fuzzy.rb" /usr/lib/tobi-try/lib/fuzzy.rb
    sudo ln -sf /usr/lib/tobi-try/try.rb /usr/local/bin/try
    stamp tobi-try "$TOBI_TRY_VER"
  else
    warn "tobi-try download failed"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

# --- omacut: Qt6 video trimmer (source build) ---
install_omacut() {
  stamped omacut "$OMACUT_VER" && return 0
  echo "Building omacut $OMACUT_VER (Qt6 source)..."
  need_build_deps gcc gcc-c++ make qt6-qtbase-devel qt6-qtdeclarative-devel qt6-qtmultimedia-devel
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/omacom-io/omacut/archive/refs/tags/v${OMACUT_VER}.tar.gz" | tar -xz -C "$tmp" &&
    (cd "$tmp/omacut-${OMACUT_VER}" && ./bin/build) &&
    [[ -f "$tmp/omacut-${OMACUT_VER}/build/omacut" ]]; then
    local src="$tmp/omacut-${OMACUT_VER}"
    sudo install -Dm755 "$src/build/omacut" /usr/local/bin/omacut
    install_share "$src/pkgbuild/omacut.desktop" /usr/share/applications/omacut.desktop
    install_share "$src/pkgbuild/omacut.svg" /usr/share/icons/hicolor/scalable/apps/omacut.svg
    stamp omacut "$OMACUT_VER"
  else
    warn "omacut build failed"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

# --- omawrite: Qt6 Markdown writing app (source build) ---
install_omawrite() {
  stamped omawrite "$OMAWRITE_VER" && return 0
  echo "Building omawrite $OMAWRITE_VER (Qt6 source)..."
  need_build_deps gcc gcc-c++ make qt6-qtbase-devel qt6-qtdeclarative-devel
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/omacom-io/omawrite/archive/refs/tags/v${OMAWRITE_VER}.tar.gz" | tar -xz -C "$tmp" &&
    (cd "$tmp/omawrite-${OMAWRITE_VER}" && ./bin/build) &&
    [[ -f "$tmp/omawrite-${OMAWRITE_VER}/build/omawrite" ]]; then
    local src="$tmp/omawrite-${OMAWRITE_VER}"
    sudo install -Dm755 "$src/build/omawrite" /usr/local/bin/omawrite
    install_share "$src/pkgbuild/omawrite.desktop" /usr/share/applications/omawrite.desktop
    install_share "$src/pkgbuild/omawrite.svg" /usr/share/icons/hicolor/scalable/apps/omawrite.svg
    stamp omawrite "$OMAWRITE_VER"
  else
    warn "omawrite build failed"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

# --- hyprland-preview-share-picker: xdg-desktop-portal-hyprland custom picker (cargo source build) ---
install_share_picker() {
  stamped share-picker "$SHARE_PICKER_VER" && return 0
  echo "Building hyprland-preview-share-picker $SHARE_PICKER_VER (cargo source)..."
  need_build_deps cargo rust gtk4-devel gtk4-layer-shell-devel libadwaita-devel
  local tmp
  tmp="$(mktemp -d)"
  if curl -fsSL "https://github.com/WhySoBad/hyprland-preview-share-picker/archive/refs/tags/v${SHARE_PICKER_VER}.tar.gz" | tar -xz -C "$tmp" &&
    curl -fsSL "https://github.com/hyprwm/hyprland-protocols/archive/${SHARE_PICKER_PROTO}.tar.gz" | tar -xz -C "$tmp"; then
    local src="$tmp/hyprland-preview-share-picker-${SHARE_PICKER_VER}"
    rmdir "$src/lib/hyprland-protocols" 2>/dev/null || true
    ln -sf "$tmp/hyprland-protocols-${SHARE_PICKER_PROTO}" "$src/lib/hyprland-protocols"
    # The upstream build.rs shells out to git for a version string; the release tarball is not a git
    # checkout, so replace it with the fixed string the PKGBUILD uses.
    printf 'fn main() {\n    println!("cargo::rustc-env=GIT_VERSION=v%s-r0-release");\n}\n' "$SHARE_PICKER_VER" >"$src/build.rs"
    if (cd "$src" && cargo build --release) && [[ -f "$src/target/release/hyprland-preview-share-picker" ]]; then
      sudo install -Dm755 "$src/target/release/hyprland-preview-share-picker" /usr/local/bin/hyprland-preview-share-picker
      stamp share-picker "$SHARE_PICKER_VER"
    else
      warn "hyprland-preview-share-picker build failed"
      rm -rf "$tmp"
      return 1
    fi
  else
    warn "hyprland-preview-share-picker source download failed"
    rm -rf "$tmp"
    return 1
  fi
  rm -rf "$tmp"
}

install_aether || true
install_cliamp || true
install_tensaku || true
install_voxtype || true
install_tobi_try || true
install_omacut || true
install_omawrite || true
install_share_picker || true

echo "[first-party] done"
