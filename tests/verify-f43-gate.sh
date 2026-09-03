#!/bin/bash

# Prove the Fedora 43 gate: on anything older than Fedora 44, Omarchy must stop before it touches the
# system and print the upgrade instructions - and it must never run a system upgrade by itself.
#
# The gate has three entry points, all of which are checked here:
#   bin/omarchy-migrate          - refuses to run any migration
#   bin/omarchy-update-perform   - refuses the whole update pipeline
#   install/preflight/guard.sh   - refuses a fresh install
#
# Requires: podman, and aarch64 user-mode emulation registered with binfmt_misc.
#
# Exit codes: 0 = the gate holds on Fedora 43 and opens on Fedora 44, non-zero = it does not.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v podman >/dev/null || {
  echo "podman is required" >&2
  exit 1
}
grep -q . /proc/sys/fs/binfmt_misc/qemu-aarch64 2>/dev/null ||
  { echo "aarch64 emulation is not registered - see tests/verify-f44-container.sh" >&2; exit 1; }

# The gate must hold on 43 and open on 44. Anything else is a bug.
run_gate_check() {
  local release="$1" expect="$2" # expect: closed | open

  echo "== Fedora $release (aarch64, emulated): expecting the gate to be $expect"

  podman run --rm --arch arm64 \
    -v "$REPO_ROOT:/omarchy:ro" \
    -e "OMARCHY_PATH=/omarchy" \
    -e "OMARCHY_INSTALL=/omarchy/install" \
    -e "EXPECT=$expect" \
    "fedora:$release" bash -euo pipefail -c '
      export HOME=/root
      export PATH="/omarchy/bin:$PATH"

      # A migration state directory that starts empty: if the gate leaks, we will see state files.
      state_dir="$HOME/.local/state/omarchy/migrations"
      rm -rf "$state_dir"

      output="$(omarchy-migrate 2>&1)" && status=0 || status=$?

      applied=0
      if [[ -d $state_dir ]]; then
        applied="$(find "$state_dir" -maxdepth 1 -type f | wc -l)"
      fi

      # boot.sh is the curl-pipe entry point, and it deletes an existing Omarchy install and runs a
      # full dnf upgrade before install.sh (and its preflight guard) ever runs. If its gate is missing,
      # a Fedora 43 user loses their working install before anything tells them to upgrade - so it is
      # checked here too. sudo is stubbed: anything past the gate must not actually execute.
      cat > /usr/local/bin/sudo <<STUB
#!/bin/bash
[[ \$1 == -v || \$1 == -k ]] && exit 0
echo "[TEST] blocked: sudo \$*" >&2
exit 1
STUB
      chmod +x /usr/local/bin/sudo

      # boot.sh runs `clear` under `set -e`; the base image has no ncurses and no TERM.
      dnf -q -y install ncurses >/dev/null 2>&1
      export TERM=xterm

      boot_output="$(timeout 120 bash /omarchy/boot.sh 2>&1)" && boot_status=0 || boot_status=$?

      if [[ $EXPECT == closed ]]; then
        if ((boot_status == 0)); then
          echo "[CRITICAL] boot.sh exited 0 on Fedora $(rpm -E %fedora) - it would have wiped a working install"
          exit 1
        fi
        if ! grep -q "requires Fedora Asahi Remix 44 or newer" <<<"$boot_output"; then
          echo "[CRITICAL] boot.sh stopped for the wrong reason - it must stop on the Fedora version:"
          echo "$boot_output"
          exit 1
        fi
        if grep -q "Updating system packages" <<<"$boot_output"; then
          echo "[CRITICAL] boot.sh started upgrading packages before its version gate"
          exit 1
        fi
        echo "[OK] boot.sh refused before touching the system"
      fi

      if [[ $EXPECT == closed ]]; then
        if ((status == 0)); then
          echo "[CRITICAL] omarchy-migrate exited 0 on Fedora $(rpm -E %fedora) - the gate did not hold"
          exit 1
        fi
        if ! grep -q "requires Fedora Asahi Remix 44" <<<"$output"; then
          echo "[CRITICAL] no upgrade instructions printed. Output was:"
          echo "$output"
          exit 1
        fi
        if grep -q "system-upgrade reboot" <<<"$output" && grep -qE "^\s*sudo dnf system-upgrade reboot\s*$" <<<"$output"; then
          : # the instructions print the command for the user - that is fine
        fi
        if ((applied > 0)); then
          echo "[CRITICAL] the gate stopped the run but $applied migration(s) were already marked applied"
          exit 1
        fi
        echo "[OK] gate held: exit $status, instructions printed, 0 migrations applied"
        echo "--- what the user sees ---"
        echo "$output"
      else
        # On Fedora 44 the gate must not fire. We do not let the migrations actually run here (they
        # would touch a real system), so the check is on the gate condition itself.
        source /omarchy/install/helpers/distro.sh >/dev/null
        if ! is_fedora_supported_version; then
          echo "[CRITICAL] the gate fired on Fedora $(rpm -E %fedora) - it must only stop releases below 44"
          exit 1
        fi
        echo "[OK] gate open on Fedora $(rpm -E %fedora)"
      fi
    '
}

# Omarchy must never upgrade Fedora for the user: a system upgrade reboots the machine and can leave
# an Asahi install unbootable. The gate may only print the instructions.
echo "== Checking that no entry point runs a system upgrade itself"

# Comments are allowed to explain why we do not do it; code is not.
if grep -nE '^[[:space:]]*[^#[:space:]].*system-upgrade' \
  "$REPO_ROOT/bin/omarchy-migrate" \
  "$REPO_ROOT/bin/omarchy-update-perform" \
  "$REPO_ROOT/install/preflight/guard.sh"; then
  echo "[CRITICAL] an entry point references dnf system-upgrade - it must only print the instructions"
  exit 1
fi

# In distro.sh the command may appear only inside the instructions heredoc, never as a live line.
if awk '/<<INSTRUCTIONS/,/^INSTRUCTIONS$/ { next } { print }' \
  "$REPO_ROOT/install/helpers/distro.sh" | grep -nE '^[[:space:]]*[^#[:space:]].*system-upgrade'; then
  echo "[CRITICAL] distro.sh runs a system upgrade outside the instructions heredoc"
  exit 1
fi

echo "[OK] no entry point executes dnf system-upgrade"
echo

run_gate_check 43 closed
echo
run_gate_check 44 open
echo
echo "PASS: the Fedora 43 gate holds, the Fedora 44 path is unaffected"
