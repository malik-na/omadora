#!/bin/bash


OMARCHY_INSTALL="${OMARCHY_INSTALL:-$HOME/.local/share/omarchy/install}"
source "$OMARCHY_INSTALL/helpers/distro.sh"


if ! is_fedora; then
  exit 0
fi


ensure_local_bin_path() {
  local path_before=":$PATH:"
  mkdir -p "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
  if [[ "$path_before" != *":$HOME/.local/bin:"* ]]; then
    if [[ -f "$HOME/.bashrc" ]] && ! grep -q 'PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
      echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
    fi
  fi
}


command_exists_or_linked() {
  local bin="$1"
  command -v "$bin" >/dev/null 2>&1 || [[ -x "$HOME/.cargo/bin/$bin" ]]
}


link_cargo_bin() {
  local bin="$1"
  ensure_local_bin_path
  if [[ -x "$HOME/.cargo/bin/$bin" ]]; then
    ln -snf "$HOME/.cargo/bin/$bin" "$HOME/.local/bin/$bin"
  fi
}


install_walker_from_source() {
  local version_ref="$1"
  local src_dir
  src_dir="$(mktemp -d /tmp/omarchy-walker-src.XXXXXX)"


  if [[ "${OMARCHY_DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY-RUN] Would clone/build walker source and install to ~/.local/bin/walker"
    rm -rf "$src_dir"
    return 0
  fi


  # Clone the tag directly. A --depth=1 clone followed by a tag fetch does not reliably have the
  # tagged commit's objects, so the ref must be selected at clone time.
  if ! clone_ref https://github.com/abenz1267/walker.git "$version_ref" "$src_dir"; then
    echo "[WARN] Failed to clone walker source (ref: ${version_ref:-default branch})"
    rm -rf "$src_dir"
    return 1
  fi


  if ! (cd "$src_dir" && cargo build --release); then
    echo "[WARN] Failed to build walker from source"
    rm -rf "$src_dir"
    return 1
  fi


  if [[ ! -x "$src_dir/target/release/walker" ]]; then
    echo "[WARN] Walker build completed without target/release/walker"
    rm -rf "$src_dir"
    return 1
  fi


  ensure_local_bin_path
  install -m 755 "$src_dir/target/release/walker" "$HOME/.local/bin/walker"
  rm -rf "$src_dir"
  echo "[OK] Installed walker via source build"
  return 0
}


ensure_rust_toolchain() {
  if command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1; then
    return 0
  fi
  sudo dnf install -y rust cargo
}


TEMP_BUILD_DEPS=()
install_temp_build_dep() {
  local pkg="$1"
  if rpm -q "$pkg" >/dev/null 2>&1; then
    return 0
  fi


  if sudo dnf install -y "$pkg"; then
    TEMP_BUILD_DEPS+=("$pkg")
    return 0
  fi


  return 1
}


cleanup_temp_build_deps() {
  if ((${#TEMP_BUILD_DEPS[@]} == 0)); then
    return 0
  fi


  echo "[INFO] Removing temporary walker/elephant build dependencies..."
  sudo dnf remove -y "${TEMP_BUILD_DEPS[@]}" || true
}


elephant_providers_present() {
  local providers_dir="$HOME/.config/elephant/providers"
  # dnfpackages is Elephant's own DNF provider (search and install packages from the launcher). It is
  # a plain Go plugin like the other nine and shells out to the dnf CLI, so it costs one more
  # `go build` out of the source tree we are already compiling - no extra toolchain, no extra clone.
  local providers=(
    providerlist
    desktopapplications
    calc
    menus
    clipboard
    symbols
    files
    websearch
    runner
    dnfpackages
  )


  local provider
  for provider in "${providers[@]}"; do
    [[ -f "$providers_dir/${provider}.so" ]] || return 1
  done


  return 0
}


install_elephant_go() {
  local version_ref="$1"
  local src_dir
  src_dir="$(mktemp -d /tmp/omarchy-elephant-src.XXXXXX)"


  local providers=(
    providerlist
    desktopapplications
    calc
    menus
    clipboard
    symbols
    files
    websearch
    runner
    dnfpackages
  )


  if [[ "${OMARCHY_DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY-RUN] Would clone/build elephant via Go and install providers to ~/.config/elephant/providers"
    rm -rf "$src_dir"
    return 0
  fi


  if ! clone_ref https://github.com/abenz1267/elephant.git "$version_ref" "$src_dir"; then
    echo "[WARN] Failed to clone elephant source (ref: ${version_ref:-default branch})"
    rm -rf "$src_dir"
    return 1
  fi


  ensure_local_bin_path
  mkdir -p "$HOME/.config/elephant/providers"


  if ! (cd "$src_dir/cmd/elephant" && go build -buildvcs=false -trimpath -o elephant); then
    echo "[WARN] Failed to build elephant binary"
    rm -rf "$src_dir"
    return 1
  fi
  install -m 755 "$src_dir/cmd/elephant/elephant" "$HOME/.local/bin/elephant"


  local provider
  for provider in "${providers[@]}"; do
    if ! (cd "$src_dir/internal/providers/$provider" && go build -buildvcs=false -buildmode=plugin -trimpath); then
      echo "[WARN] Failed to build elephant provider plugin: $provider"
      rm -rf "$src_dir"
      return 1
    fi
    install -m 755 "$src_dir/internal/providers/$provider/${provider}.so" "$HOME/.config/elephant/providers/${provider}.so"
  done


  rm -rf "$src_dir"
  echo "[OK] Installed elephant via Go with provider plugins"
  return 0
}


# Versions verified against this Omarchy release. Both are built from source on Fedora (neither is
# packaged for Fedora or in any COPR), so they are pinned rather than tracking the default branch:
# an unreleased HEAD is not something a user's launcher should be upgraded to during omarchy-update.
# Bump these when a new Omarchy release needs a newer launcher; the stamp file below makes existing
# installs pick the new version up on the next update.
WALKER_VERSION="${OMARCHY_WALKER_VERSION:-v2.16.2}"
ELEPHANT_VERSION="${OMARCHY_ELEPHANT_VERSION:-v2.21.0}"

WALKER_ELEPHANT_STAMP="$HOME/.local/state/omarchy/walker-elephant-version"
WALKER_ELEPHANT_STAMP_VALUE="walker=$WALKER_VERSION elephant=$ELEPHANT_VERSION"

stamp_matches() {
  [[ -f "$WALKER_ELEPHANT_STAMP" ]] &&
    [[ "$(cat "$WALKER_ELEPHANT_STAMP")" == "$WALKER_ELEPHANT_STAMP_VALUE" ]]
}

write_stamp() {
  if [[ "${OMARCHY_DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY-RUN] Would record installed versions: $WALKER_ELEPHANT_STAMP_VALUE"
    return 0
  fi

  mkdir -p "$(dirname "$WALKER_ELEPHANT_STAMP")"
  echo "$WALKER_ELEPHANT_STAMP_VALUE" >"$WALKER_ELEPHANT_STAMP"
}

# Clone a single ref shallowly. An empty ref means the default branch.
clone_ref() {
  local url="$1" ref="$2" dest="$3"

  if [[ -n "$ref" ]]; then
    git clone --depth=1 --branch "$ref" "$url" "$dest"
  else
    git clone --depth=1 "$url" "$dest"
  fi
}


BUILD_DEPS=(
  gcc
  gcc-c++
  make
  cmake
  pkgconf-pkg-config
  cairo-devel
  pango-devel
  poppler-glib-devel
  glib2-devel
  gtk4-devel
  gtk4-layer-shell-devel
  libxkbcommon-devel
  dbus-devel
  openssl-devel
  protobuf-compiler
  golang
  git
)


ensure_official_gtk_build_deps() {
  local gtk_build_deps=(
    gtk4-devel
    gtk4-layer-shell-devel
    pango-devel
    cairo-devel
  )


  if [[ "${OMARCHY_DRY_RUN:-0}" == "1" ]]; then
    echo "[DRY-RUN] Would run: sudo dnf install -y ${gtk_build_deps[*]} --allowerasing"
    return 0
  fi


  echo "[INFO] Ensuring official GTK/Pango/Cairo build dependencies..."
  sudo dnf install -y "${gtk_build_deps[@]}" --allowerasing
}


fail_walker_install() {
  local reason="$1"
  cleanup_temp_build_deps
  echo "[ERROR] Failed to install walker: $reason"
  echo "[ERROR] Next step: verify rust/cargo and GTK build deps, then rerun $OMARCHY_INSTALL/helpers/fedora-walker-elephant.sh"
  exit 1
}


# Both binaries live in ~/.local/bin, which is not on PATH in a non-interactive shell - and this
# script runs from omarchy-update. Without this the checks below would not see an existing build and
# would rebuild walker and elephant from source on every single update.
ensure_local_bin_path


# Already at the pinned versions - nothing to do. This is what makes the script safe to re-run from
# omarchy-update: it only rebuilds when the pinned version actually changed, or when a build is
# missing. Elephant's providers are Go plugins and are version-locked to the elephant binary, so
# they are always rebuilt together with it.
if stamp_matches && command_exists_or_linked walker && command_exists_or_linked elephant && elephant_providers_present; then
  echo "[OK] Walker $WALKER_VERSION and Elephant $ELEPHANT_VERSION already installed"
  link_cargo_bin walker
  exit 0
fi


# Build path. Neither walker nor elephant is packaged in Fedora or in any enabled COPR, so this is
# the only way onto the system.
ensure_official_gtk_build_deps || {
  fail_walker_install "Failed to install official GTK build dependencies"
}


ensure_rust_toolchain || {
  fail_walker_install "Rust toolchain unavailable"
}


for dep in "${BUILD_DEPS[@]}"; do
  install_temp_build_dep "$dep" || echo "[WARN] Missing build dependency: $dep"
done


# Reaching this point means the installed build is missing or is not the pinned version, so both are
# rebuilt - an existing older walker must be replaced, not kept.
install_walker_from_source "$WALKER_VERSION" || fail_walker_install "source build failed"


if ! command -v walker >/dev/null 2>&1; then
  fail_walker_install "walker binary missing from PATH"
fi


if ! walker --version >/dev/null 2>&1; then
  fail_walker_install "walker --version failed"
fi


echo "[OK] Walker verification passed: $(command -v walker)"


elephant_ok=1
install_elephant_go "$ELEPHANT_VERSION" || elephant_ok=0


if ((elephant_ok)); then
  write_stamp
else
  echo "[WARN] Elephant build failed - leaving the version stamp unwritten so the next update retries"
fi


cleanup_temp_build_deps


echo "[Omarchy/Fedora] Walker + Elephant provisioning step completed."
