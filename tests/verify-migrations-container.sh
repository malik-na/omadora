#!/bin/bash

# Run this release's new migrations in an emulated Fedora 44 aarch64 container, twice, and prove they
# are idempotent: the second run must succeed, change nothing, and produce no second-run effect.
#
# Scope limit: dnf and bash only, never a compile. The walker/elephant migration is checked on its
# no-op path (pinned version already installed) - building Rust and Go under emulation proves nothing
# about packaging and takes forever. The build itself belongs on the target machine.
#
# Requires: podman, and aarch64 user-mode emulation registered with binfmt_misc.
#
# Exit codes: 0 = every migration is idempotent, non-zero = one is not.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FEDORA_RELEASE="${FEDORA_RELEASE:-44}"

# The migrations this release adds. Upstream's 63 arrive with the merge and are covered by the
# conflict audit; these are the ones written for the Fedora 44 move.
MIGRATIONS=(
  1783927940.sh # remove dead COPRs, re-apply the Hyprland repo protections
  1783927950.sh # replace the packages Fedora 44 retired or renamed
  1783927960.sh # rebuild walker + elephant at the pinned versions
)

command -v podman >/dev/null || {
  echo "podman is required" >&2
  exit 1
}
grep -q . /proc/sys/fs/binfmt_misc/qemu-aarch64 2>/dev/null ||
  { echo "aarch64 emulation is not registered - see tests/verify-f44-container.sh" >&2; exit 1; }

echo "Running ${#MIGRATIONS[@]} migrations twice against Fedora $FEDORA_RELEASE (aarch64, emulated)"
echo

podman run --rm --arch arm64 \
  -v "$REPO_ROOT:/omarchy:ro" \
  -e "MIGRATIONS=${MIGRATIONS[*]}" \
  "fedora:$FEDORA_RELEASE" bash -euo pipefail -c '
    export HOME=/root
    export OMARCHY_PATH=/omarchy
    export OMARCHY_INSTALL=/omarchy/install
    export PATH="/omarchy/bin:$HOME/.local/bin:$PATH"

    echo "== Container prerequisites"
    dnf -q -y install dnf5-plugins sudo diffutils >/dev/null
    echo "  ok       dnf5-plugins, sudo, diffutils"

    # The source-built packages must look already-current, so the migration takes its no-op path
    # instead of compiling Rust and Go under emulation (which proves nothing about packaging and
    # takes hours). Fake exactly what "already at the pinned version" means on a real machine: the
    # binaries, the elephant provider plugins, the version stamp, and the cargo install list.
    mkdir -p "$HOME/.local/bin" "$HOME/.config/elephant/providers" "$HOME/.local/state/omarchy"

    for bin in walker elephant; do
      printf "#!/bin/bash\necho fake-$bin\n" > "$HOME/.local/bin/$bin"
      chmod +x "$HOME/.local/bin/$bin"
    done

    # The provider list, the version pins and the cargo pins all come from the scripts themselves -
    # if someone adds a provider or bumps a version and forgets this test, the test must not silently
    # keep passing against a stale expectation.
    providers="$(sed -n "/^elephant_providers_present/,/^}/p" /omarchy/install/helpers/fedora-walker-elephant.sh |
      sed -n "/local providers=(/,/)/p" | grep -oE "^\s+[a-z]+$" | tr -d " ")"
    for provider in $providers; do
      : > "$HOME/.config/elephant/providers/$provider.so"
    done

    walker_version="$(grep -oP "OMARCHY_WALKER_VERSION:-\K[^}]+" /omarchy/install/helpers/fedora-walker-elephant.sh)"
    elephant_version="$(grep -oP "OMARCHY_ELEPHANT_VERSION:-\K[^}]+" /omarchy/install/helpers/fedora-walker-elephant.sh)"
    echo "walker=$walker_version elephant=$elephant_version" > "$HOME/.local/state/omarchy/walker-elephant-version"
    echo "  ok       providers: $(wc -w <<<"$providers"), stamp: walker $walker_version / elephant $elephant_version"

    # cargo is faked, not installed: a real `cargo install` is a compile, and compiling under
    # emulation is exactly what this harness must never do. The shim reports the pinned versions as
    # already installed, which is the path a healthy machine takes on every update.
    cargo_pins="$(grep -oE "^install_cargo_tool [a-z]+ [0-9.]+" /omarchy/install/helpers/fedora-rust-tuis.sh |
      awk "{ print \$2 \" v\" \$3 \":\" }")"
    {
      echo "#!/bin/bash"
      echo "if [[ \$1 == install && \$2 == --list ]]; then"
      while IFS= read -r pin; do echo "  echo \"$pin\""; done <<<"$cargo_pins"
      echo "  exit 0"
      echo "fi"
      echo "echo \"[CRITICAL] a migration tried to run a real cargo build: cargo \$*\" >&2"
      echo "exit 1"
    } > /usr/local/bin/cargo
    chmod +x /usr/local/bin/cargo
    printf "#!/bin/bash\necho fake-rustc\n" > /usr/local/bin/rustc
    chmod +x /usr/local/bin/rustc
    echo "  ok       cargo shim reports: $(tr "\n" " " <<<"$cargo_pins")"
    echo

    # Fingerprint everything a migration is allowed to touch, so a second-run effect cannot hide.
    fingerprint() {
      rpm -qa | sort
      echo "---repos---"
      find /etc/yum.repos.d -type f | sort | while read -r f; do echo "== $f"; cat "$f"; done
      echo "---state---"
      find "$HOME/.local/state/omarchy" -type f | sort | while read -r f; do echo "== $f"; cat "$f"; done
    }

    status=0

    for migration in $MIGRATIONS; do
      echo "== $migration"

      # A migration must never compile anything here. The 10-minute cap turns an accidental
      # source build under emulation into a visible failure instead of an hours-long hang.
      if ! timeout 600 bash "/omarchy/migrations/$migration" >"/tmp/$migration.run1" 2>&1; then
        echo "  [CRITICAL] first run failed"
        sed "s/^/      /" "/tmp/$migration.run1"
        status=1
        continue
      fi
      echo "  ok       first run"

      fingerprint > "/tmp/$migration.state1"

      if ! bash "/omarchy/migrations/$migration" >"/tmp/$migration.run2" 2>&1; then
        echo "  [CRITICAL] second run failed - the migration is not idempotent"
        sed "s/^/      /" "/tmp/$migration.run2"
        status=1
        continue
      fi
      echo "  ok       second run"

      fingerprint > "/tmp/$migration.state2"

      if ! diff -q "/tmp/$migration.state1" "/tmp/$migration.state2" >/dev/null; then
        echo "  [CRITICAL] the second run changed the system - not idempotent:"
        diff "/tmp/$migration.state1" "/tmp/$migration.state2" | sed "s/^/      /"
        status=1
        continue
      fi
      echo "  ok       second run changed nothing"
    done

    # The runs above could not exercise a single swap: a clean Fedora 44 has none of the retired
    # packages installed, so every swap is a guarded no-op. The machine this migration actually has to
    # repair is one that came up from Fedora 43 and still carries them as orphans. Stage exactly that
    # state - the real Fedora 43 packages, pulled with --releasever=43 - and let the migration work.
    echo
    echo "== Upgraded-from-Fedora-43 simulation (the swap paths)"

    staged=""
    for pkg in java-21-openjdk gst-plugin-pipewire wget yaru-gtk2-theme webp-pixbuf-loader; do
      if dnf -y --releasever=43 --setopt=install_weak_deps=False install "$pkg" >/dev/null 2>&1 &&
        rpm -q "$pkg" >/dev/null 2>&1; then
        staged="$staged $pkg"
      else
        echo "  [WARNING] could not stage $pkg from Fedora 43 - not covered by this run"
      fi
    done
    echo "  ok       staged Fedora 43 leftovers:$staged"

    if ! timeout 900 bash /omarchy/migrations/1783927950.sh >/tmp/swap.run1 2>&1; then
      echo "  [CRITICAL] the package migration failed against an upgraded-from-43 system"
      sed "s/^/      /" /tmp/swap.run1
      exit 1
    fi
    echo "  ok       migration ran"

    swap_status=0
    for pkg in $staged; do
      if rpm -q "$pkg" >/dev/null 2>&1; then
        echo "  [CRITICAL] $pkg is still installed - the swap did not happen"
        swap_status=1
      fi
    done
    for pkg in java-latest-openjdk pipewire-gstreamer wget2-wget glycin-loaders socat mesa-vulkan-drivers; do
      if ! rpm -q "$pkg" >/dev/null 2>&1; then
        echo "  [CRITICAL] $pkg is missing - the replacement was not installed"
        swap_status=1
      fi
    done
    (( swap_status == 0 )) && echo "  ok       every retired package replaced by its Fedora 44 successor"

    fingerprint >/tmp/swap.state1
    if ! timeout 900 bash /omarchy/migrations/1783927950.sh >/tmp/swap.run2 2>&1; then
      echo "  [CRITICAL] the second run failed on the migrated system"
      sed "s/^/      /" /tmp/swap.run2
      swap_status=1
    fi
    fingerprint >/tmp/swap.state2
    if ! diff -q /tmp/swap.state1 /tmp/swap.state2 >/dev/null; then
      echo "  [CRITICAL] re-running against an already-migrated system changed it:"
      diff /tmp/swap.state1 /tmp/swap.state2 | sed "s/^/      /"
      swap_status=1
    else
      echo "  ok       re-run against the already-migrated system is a no-op"
    fi

    (( swap_status != 0 )) && status=1

    echo
    if (( status != 0 )); then
      echo "FAIL: at least one migration is not idempotent"
      exit 1
    fi
    echo "PASS: every migration ran twice, succeeded twice, changed nothing on the second run, and the"
    echo "      package migration repairs an upgraded-from-43 system and is a no-op afterwards"
  '
