#!/bin/bash
#
# Fedora Asahi Remix (aarch64) git-clone installer for omarchy-mac-fedora.
#
# Upstream quattro installs from an ISO: the image installs packages and creates
# the user, then runs `omarchy-setup-system` and `omarchy-finalize-user` in the
# target chroot. The fork ships by git clone instead, so this script does the
# same work on an already-running Fedora Asahi system.
#
# It runs as the target user and escalates with sudo only for the few
# root-context steps (run_root). Everything else either needs no privilege or
# escalates itself.

export ANSI_HIDE_CURSOR="\033[?25l"
export ANSI_SHOW_CURSOR="\033[?25h"

# Locations.
export OMARCHY_PATH="${OMARCHY_PATH:-$HOME/.local/share/omarchy}"
export OMARCHY_INSTALL="${OMARCHY_INSTALL:-$OMARCHY_PATH/install}"
export OMARCHY_INSTALL_LOG_FILE="${OMARCHY_INSTALL_LOG_FILE:-/var/log/omarchy-install.log}"
export OMARCHY_INSTALL_USER="${OMARCHY_INSTALL_USER:-$USER}"
export OMARCHY_FIRST_INSTALL=1
export OMARCHY_ONLINE_INSTALL="${OMARCHY_ONLINE_INSTALL:-true}"
export PATH="$OMARCHY_PATH/bin:$PATH"

# Must run from a clone.
if [[ ! -d "$OMARCHY_INSTALL" ]]; then
  echo "❌ $OMARCHY_INSTALL not found." >&2
  echo "Run this from a cloned omarchy-mac-fedora repo in $OMARCHY_PATH, or use boot.sh." >&2
  exit 1
fi

# Requirement gate first: before sudo, before any change, so a machine that
# fails a check is left exactly as it was.
bash "$OMARCHY_INSTALL/preflight/guard.sh" || exit 1

# Administrator access. One prompt up front; passwordless-installer.sh then drops
# a temporary NOPASSWD sudoers rule so the rest of the install doesn't re-ask.
# The password has to be entered at a real `sudo <command>`, never at a bare
# `sudo -v`: on a real M1/M2 console `sudo -v` as the session's first sudo call
# hangs at (or without) the password prompt, while the 3.8.x line - which always
# took the password at a `sudo dnf` command - never did. So gum is installed
# first with the terminal attached, exactly where 3.8.x ran it: on a fresh
# system its `sudo dnf install gum` is where the password goes in. `sudo true`
# then covers re-runs where gum is already present and no dnf call happens.
echo "🔐 omarchy-mac-fedora installation requires administrator access..."
bash "$OMARCHY_INSTALL/helpers/fedora-gum.sh"
if ! sudo true; then
  echo "❌ Could not obtain sudo access." >&2
  echo "   Run this as a regular user in the 'wheel' group - not with 'sudo bash install.sh'." >&2
  echo "   If an earlier run left a broken rule behind, clear it and re-check:" >&2
  echo "     sudo rm -f /etc/sudoers.d/99-omarchy-installer && sudo visudo -c" >&2
  exit 1
fi

# Logo, gum styling, and the live log view (3.8.x look). Needs gum, so it
# loads right after the gum bootstrap above.
source "$OMARCHY_INSTALL/helpers/presentation.sh"

# Name/email prompts (git config, XCompose). Interactive by design, so it must
# run here with the terminal - under run_logged, gum renders its prompt into
# the log file while reading /dev/tty, which freezes the install right after
# the password with nothing on screen. Sourcing also keeps its exports, which
# a run_logged subshell would lose.
source "$OMARCHY_INSTALL/preflight/identification.sh"

printf "%b" "$ANSI_HIDE_CURSOR"

keep_sudo_alive() {
  while true; do
    sudo -n -v >/dev/null 2>&1
    sleep 50
  done
}
keep_sudo_alive &
SUDO_KEEPALIVE_PID=$!

cleanup_install() {
  declare -F stop_log_output >/dev/null && stop_log_output
  printf "%b" "$ANSI_SHOW_CURSOR"
  sudo rm -f /etc/sudoers.d/99-omarchy-installer 2>/dev/null || true
  kill "${SUDO_KEEPALIVE_PID:-}" 2>/dev/null || true
}
trap cleanup_install EXIT
# Without the exit, an INT trap only kills the current child and the script
# stumbles on to the next step; Ctrl+C must abort the whole install.
trap 'exit 130' INT TERM

# The log lives in /var/log (setup-system's location too); create it as root but
# world-writable so the user-context and root-context steps can both append.
sudo mkdir -p "$(dirname "$OMARCHY_INSTALL_LOG_FILE")"
sudo touch "$OMARCHY_INSTALL_LOG_FILE"
sudo chmod 666 "$OMARCHY_INSTALL_LOG_FILE"

source "$OMARCHY_INSTALL/helpers/logging.sh"
start_install_log

# The 3.8.x install view: logo on top, then a live tail of the install log so
# the long dnf steps are visibly making progress instead of looking hung.
clear_logo
gum style --foreground 3 --padding "1 0 0 $PADDING_LEFT" "Installing..."
echo
start_log_output

# run_user: source a script in-process as the current user (self-escalating and
# user-level scripts). run_root: run a root-context script (no internal sudo)
# under sudo, threading the OMARCHY_* environment through explicitly so it does
# not depend on sudo's env policy.
run_user() { run_logged "$1"; }

run_root() {
  local script="$1" exit_code
  omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting (root): $script"

  if omarchy_log_to_stdout; then
    sudo bash -eE -c 'export OMARCHY_INSTALL="$1" OMARCHY_PATH="$2" OMARCHY_INSTALL_USER="$3" OMARCHY_FIRST_INSTALL="$4" PATH="$2/bin:$PATH"; shift 4; source "$1"' \
      _ "$OMARCHY_INSTALL" "$OMARCHY_PATH" "$OMARCHY_INSTALL_USER" "$OMARCHY_FIRST_INSTALL" "$script" </dev/null 2>&1
  else
    sudo bash -eE -c 'export OMARCHY_INSTALL="$1" OMARCHY_PATH="$2" OMARCHY_INSTALL_USER="$3" OMARCHY_FIRST_INSTALL="$4" PATH="$2/bin:$PATH"; shift 4; source "$1"' \
      _ "$OMARCHY_INSTALL" "$OMARCHY_PATH" "$OMARCHY_INSTALL_USER" "$OMARCHY_FIRST_INSTALL" "$script" </dev/null >>"$OMARCHY_INSTALL_LOG_FILE" 2>&1
  fi
  exit_code=$?

  if ((exit_code == 0)); then
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Completed (root): $script"
  else
    omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Failed (root): $script (exit code: $exit_code)"
  fi
  return $exit_code
}

abort_install() {
  stop_log_output
  printf "%b" "$ANSI_SHOW_CURSOR"
  echo "❌ Install failed at: $1 (see $OMARCHY_INSTALL_LOG_FILE)" >&2
  exit 1
}

# --- Preflight ---------------------------------------------------------------
run_user "$OMARCHY_INSTALL/preflight/passwordless-installer.sh"
run_user "$OMARCHY_INSTALL/preflight/locale.sh"
run_user "$OMARCHY_INSTALL/preflight/dnf.sh" || abort_install "preflight/dnf.sh (COPR + repos)"

# --- Packaging ---------------------------------------------------------------
run_user "$OMARCHY_INSTALL/helpers/fedora-hyprland.sh"
run_user "$OMARCHY_INSTALL/packaging/base.sh"
run_user "$OMARCHY_INSTALL/packaging/other.sh"
run_user "$OMARCHY_INSTALL/packaging/fonts.sh"
run_user "$OMARCHY_INSTALL/helpers/fedora-manual.sh"
run_user "$OMARCHY_INSTALL/helpers/fedora-first-party.sh"
run_user "$OMARCHY_INSTALL/helpers/fedora-grub-btrfs.sh"

# --- System configuration ----------------------------------------------------
run_root "$OMARCHY_INSTALL/config/system-files.sh"
run_root "$OMARCHY_INSTALL/config/etc-files.sh"
run_root "$OMARCHY_INSTALL/config/theme-system.sh"
run_user "$OMARCHY_INSTALL/config/increase-lockout-limit.sh"
run_root "$OMARCHY_INSTALL/config/lockscreen-pam.sh"
run_user "$OMARCHY_INSTALL/config/fix-powerprofilesctl-shebang.sh"
run_root "$OMARCHY_INSTALL/config/docker.sh"
run_user "$OMARCHY_INSTALL/config/btrfs-snapper.sh"
run_user "$OMARCHY_INSTALL/config/grub-btrfs.sh"
run_root "$OMARCHY_INSTALL/config/enable-services.sh"
run_root "$OMARCHY_INSTALL/config/firewall.sh"
run_user "$OMARCHY_INSTALL/config/console-font.sh"

# --- Hardware (Asahi/aarch64; self-gating and idempotent) --------------------
omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting (root): omarchy-setup-hardware"
sudo bash -eE -c 'export OMARCHY_PATH="$1" OMARCHY_INSTALL="$2" OMARCHY_INSTALL_USER="$3"; export PATH="$OMARCHY_PATH/bin:$PATH"; exec omarchy-setup-hardware --install-user "$3"' \
  _ "$OMARCHY_PATH" "$OMARCHY_INSTALL" "$OMARCHY_INSTALL_USER" >>"$OMARCHY_INSTALL_LOG_FILE" 2>&1 ||
  omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: omarchy-setup-hardware reported an error (continuing)"

# --- User configs and finalization -------------------------------------------
run_user "$OMARCHY_INSTALL/config/config.sh"
run_user "$OMARCHY_INSTALL/config/xdg-user-dirs.sh"
run_user "$OMARCHY_INSTALL/config/timezone-detection.sh"
run_user "$OMARCHY_INSTALL/config/zsh.sh"
run_user "$OMARCHY_INSTALL/config/lazyvim.sh"
omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Starting: omarchy-finalize-user"
omarchy-finalize-user --first-install </dev/null >>"$OMARCHY_INSTALL_LOG_FILE" 2>&1 ||
  omarchy_log_line "[$(date '+%Y-%m-%d %H:%M:%S')] Warning: omarchy-finalize-user reported an error (continuing)"

# --- Login (SDDM + initramfs) ------------------------------------------------
run_user "$OMARCHY_INSTALL/login/sddm.sh"
run_user "$OMARCHY_INSTALL/login/dracut.sh"

# --- Post-install ------------------------------------------------------------
run_user "$OMARCHY_INSTALL/post-install/network-finalize.sh"
run_root "$OMARCHY_INSTALL/post-install/udev.sh"
run_root "$OMARCHY_INSTALL/post-install/localdb.sh"

stop_log_output
stop_install_log

printf "%b" "$ANSI_SHOW_CURSOR"
source "$OMARCHY_INSTALL/post-install/finished.sh"
