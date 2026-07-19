#!/bin/bash

# Run this release's new migrations in an emulated Fedora 44 aarch64 container, twice, and prove they
# are idempotent: the second run must succeed, change nothing, and produce no second-run effect.
#
# Scope limit: dnf and bash only, never a compile.
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

    mkdir -p "$HOME/.local/bin" "$HOME/.local/state/omarchy"

    # A compile must never happen in this harness. If a migration reaches for cargo, that is a bug
    # this shim turns into a loud failure instead of an hours-long emulated build.
    {
      echo "#!/bin/bash"
      echo "echo \"[CRITICAL] a migration tried to run a real cargo build: cargo \$*\" >&2"
      echo "exit 1"
    } > /usr/local/bin/cargo
    chmod +x /usr/local/bin/cargo
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
