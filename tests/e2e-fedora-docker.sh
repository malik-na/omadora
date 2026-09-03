#!/bin/bash

# End-to-end install rehearsal in a native Fedora 44 aarch64 Docker container.
#
# Closest automated substitute for Fedora Asahi Minimal without metal: same arch,
# same release, same dnf/COPR path. OMARCHY_ASSUME_ASAHI=1 satisfies the Asahi
# kernel guard (see install/helpers/distro.sh).
#
# Requires: docker on aarch64/arm64 (Apple Silicon) or qemu-user binfmt for arm64.
#
# Usage:
#   tests/e2e-fedora-docker.sh                 # full install.sh
#   tests/e2e-fedora-docker.sh --packages-only # resolve+download package set
#   tests/e2e-fedora-docker.sh --guard-only    # preflight guards only
#   FEDORA_RELEASE=44 tests/e2e-fedora-docker.sh
#
# Logs land under /tmp/omarchy-e2e-fedora-* on the host.

set -euo pipefail

FEDORA_RELEASE="${FEDORA_RELEASE:-44}"
MODE="full"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Docker Desktop on macOS only bind-mounts shared paths (e.g. $HOME). Keep
# logs and the ephemeral run script under the repo, not host /tmp.
HOST_LOG_DIR="${HOST_LOG_DIR:-$REPO_ROOT/.e2e-logs}"
CONTAINER_NAME="omarchy-fedora-e2e-$$"
IMAGE="fedora:${FEDORA_RELEASE}"
WORK_DIR=""

while (($# > 0)); do
  case "$1" in
    --packages-only) MODE="packages" ;;
    --guard-only) MODE="guard" ;;
    --full) MODE="full" ;;
    --help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done

command -v docker >/dev/null || {
  echo "docker is required" >&2
  exit 1
}

arch="$(uname -m)"
if [[ $arch != "arm64" && $arch != "aarch64" ]]; then
  echo "Warning: host is $arch; pulling linux/arm64 and relying on emulation" >&2
fi

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$HOST_LOG_DIR"
LOG_FILE="$HOST_LOG_DIR/omarchy-e2e-fedora-${MODE}-${STAMP}.log"
INSTALL_LOG="$HOST_LOG_DIR/omarchy-e2e-fedora-install-${STAMP}.log"
WORK_DIR="$(mktemp -d "$HOST_LOG_DIR/omarchy-e2e-work-${STAMP}.XXXXXX")"
: >"$LOG_FILE"
: >"$INSTALL_LOG"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "== Omarchy Fedora e2e ($MODE) =="
echo "Image:       $IMAGE (platform linux/arm64)"
echo "Repo:        $REPO_ROOT"
echo "Console log: $LOG_FILE"
echo "Install log: $INSTALL_LOG"
echo

docker pull --platform linux/arm64 "$IMAGE" >/dev/null

write_packages_script() {
  cat >"$WORK_DIR/run.sh" <<'EOS'
#!/bin/bash
set -euo pipefail

echo "== Bootstrap dnf plugins"
dnf -y install dnf5-plugins
cd /omarchy-src

mapfile -t coprs < <(
  sed -n '/^COPR_REPOS=(/,/^)/p; /^OPTIONAL_COPR_REPOS=(/,/^)/p' install/helpers/fedora-copr.sh |
    grep -o '"[^"]*/[^"]*"' | tr -d '"'
)
mapfile -t packages < <(
  grep -h -vE '^\s*#|^\s*$' install/omarchy-base.packages.fedora install/omarchy-other.packages.fedora |
    tr -d '\r' | sed 's/^\s*//; s/\s*$//' | sort -u
)

echo
echo "== Enabling ${#coprs[@]} COPR repositories"
failed_copr=""
for repo in "${coprs[@]}"; do
  if dnf -y copr enable "$repo"; then
    echo "  ok       $repo"
  else
    echo "  FAILED   $repo"
    failed_copr+=" $repo"
  fi
done

echo
echo "== Resolving package set (${#packages[@]} packages, download only)"
if ! dnf -y --setopt=install_weak_deps=False install --downloadonly "${packages[@]}"; then
  echo "FAIL: dnf could not resolve the package set" | tee -a /var/log/omarchy-install.log
  exit 1
fi

if [[ -n $failed_copr ]]; then
  echo "[WARNING] COPR repositories that could not be enabled:$failed_copr"
fi
echo "PASS: package set resolved and downloaded"
EOS
  chmod +x "$WORK_DIR/run.sh"
}

write_guard_script() {
  cat >"$WORK_DIR/run.sh" <<'EOS'
#!/bin/bash
set -euo pipefail

echo "== Bootstrap user tools"
dnf -y install sudo passwd shadow-utils util-linux
useradd -m -G wheel omarchy
echo 'omarchy:omarchy' | chpasswd
cat >/etc/sudoers.d/omarchy <<'SUDO'
omarchy ALL=(ALL) NOPASSWD: ALL
Defaults:omarchy !requiretty
Defaults:omarchy !authenticate
SUDO
chmod 440 /etc/sudoers.d/omarchy

mkdir -p /home/omarchy/.local/share
cp -a /omarchy-src /home/omarchy/.local/share/omarchy
chown -R omarchy:omarchy /home/omarchy

runuser -u omarchy -- env \
  OMARCHY_ASSUME_ASAHI=1 \
  OMARCHY_PATH=/home/omarchy/.local/share/omarchy \
  OMARCHY_INSTALL=/home/omarchy/.local/share/omarchy/install \
  HOME=/home/omarchy \
  bash /home/omarchy/.local/share/omarchy/install/preflight/guard.sh

echo "PASS: guards OK under OMARCHY_ASSUME_ASAHI=1"
EOS
  chmod +x "$WORK_DIR/run.sh"
}

write_full_script() {
  cat >"$WORK_DIR/run.sh" <<'EOS'
#!/bin/bash
set -euo pipefail

export OMARCHY_INSTALL_LOG_FILE=/var/log/omarchy-install.log

echo "== Bootstrap container user and tools"
# gum from Fedora avoids the installer's GitHub release fallback (often 404).
dnf -y install sudo passwd shadow-utils util-linux git which findutils \
  procps-ng systemd systemd-udev dbus-daemon gum

useradd -m -G wheel -s /bin/bash omarchy
# Containers often lack usable PAM account state; NOPASSWD never runs if PAM
# account fails first. Permit sudo auth/account for this e2e image only.
echo 'omarchy:omarchy' | chpasswd
cat >/etc/pam.d/sudo <<'PAM'
auth       sufficient   pam_permit.so
account    sufficient   pam_permit.so
password   sufficient   pam_permit.so
session    sufficient   pam_permit.so
PAM
cat >/etc/sudoers.d/omarchy <<'SUDO'
omarchy ALL=(ALL) NOPASSWD: ALL
Defaults:omarchy !requiretty
Defaults:omarchy !authenticate
SUDO
chmod 440 /etc/sudoers.d/omarchy
# Prove passwordless sudo works before install.sh asks for it.
runuser -u omarchy -- sudo -n true
runuser -u omarchy -- sudo -n id -u

mkdir -p /home/omarchy/.local/share
cp -a /omarchy-src /home/omarchy/.local/share/omarchy
touch "$OMARCHY_INSTALL_LOG_FILE"
chmod 666 "$OMARCHY_INSTALL_LOG_FILE"
chown -R omarchy:omarchy /home/omarchy

# Soften systemctl failures when no real init is PID 1.
if [[ -x /usr/bin/systemctl && ! -e /usr/bin/systemctl.real ]]; then
  mv /usr/bin/systemctl /usr/bin/systemctl.real
  cat >/usr/bin/systemctl <<'WRAP'
#!/bin/bash
if /usr/bin/systemctl.real "$@" 2>/tmp/systemctl-err.$$; then
  rm -f /tmp/systemctl-err.$$
  exit 0
fi
status=$?
if grep -Eqi 'Failed to connect to bus|System has not been booted with systemd' /tmp/systemctl-err.$$ 2>/dev/null; then
  echo "[e2e] systemctl unavailable ($*): continuing" >&2
  cat /tmp/systemctl-err.$$ >&2 || true
  rm -f /tmp/systemctl-err.$$
  exit 0
fi
cat /tmp/systemctl-err.$$ >&2 || true
rm -f /tmp/systemctl-err.$$
exit $status
WRAP
  chmod +x /usr/bin/systemctl
fi

echo "== Running install.sh as omarchy"
runuser -u omarchy -- env \
  OMARCHY_ASSUME_ASAHI=1 \
  OMARCHY_SKIP_REBOOT_PROMPT=1 \
  OMARCHY_ONLINE_INSTALL=true \
  OMARCHY_USER_NAME="${OMARCHY_USER_NAME:-Omarchy Tester}" \
  OMARCHY_USER_EMAIL="${OMARCHY_USER_EMAIL:-tester@omarchy.local}" \
  OMARCHY_PATH=/home/omarchy/.local/share/omarchy \
  OMARCHY_INSTALL=/home/omarchy/.local/share/omarchy/install \
  OMARCHY_INSTALL_LOG_FILE=/var/log/omarchy-install.log \
  HOME=/home/omarchy \
  USER=omarchy \
  PATH="/home/omarchy/.local/share/omarchy/bin:/usr/local/bin:/usr/bin:/bin" \
  bash -euo pipefail -c 'cd "$OMARCHY_PATH" && bash install.sh' </dev/null

echo
echo "PASS: install.sh completed in container"
EOS
  chmod +x "$WORK_DIR/run.sh"
}

run_container() {
  if [[ ! -f $WORK_DIR/run.sh ]]; then
    echo "Internal error: $WORK_DIR/run.sh was not written" >&2
    exit 1
  fi

  docker run --name "$CONTAINER_NAME" --rm \
    --platform linux/arm64 \
    --privileged \
    -e OMARCHY_ASSUME_ASAHI=1 \
    -e OMARCHY_SKIP_REBOOT_PROMPT=1 \
    -e OMARCHY_ONLINE_INSTALL=true \
    -e OMARCHY_USER_NAME="${OMARCHY_USER_NAME:-Omarchy Tester}" \
    -e OMARCHY_USER_EMAIL="${OMARCHY_USER_EMAIL:-tester@omarchy.local}" \
    -v "$REPO_ROOT:/omarchy-src:ro" \
    -v "$WORK_DIR:/e2e:ro" \
    -v "$INSTALL_LOG:/var/log/omarchy-install.log" \
    "$IMAGE" bash /e2e/run.sh
}

case "$MODE" in
  packages) write_packages_script ;;
  guard) write_guard_script ;;
  full) write_full_script ;;
esac

run_container 2>&1 | tee -a "$LOG_FILE"

echo
echo "Done."
echo "  Console: $LOG_FILE"
echo "  Install: $INSTALL_LOG"
