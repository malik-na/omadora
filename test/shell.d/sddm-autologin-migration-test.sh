#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

migration=$(/usr/bin/grep -rl 'Migrating initial login to SDDM' "$ROOT/migrations" | head -n 1 || true)
[[ -n $migration ]] || fail "the SDDM login migration ships"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
autologin="$test_tmp/etc/sddm.conf.d/autologin.conf"
mkdir -p "$stub_bin"

# findmnt reports a btrfs root with its subvolume attached, and lsblk only
# resolves the device once that is stripped -- the case that decides whether an
# encrypted machine keeps logging itself in.
cat >"$stub_bin/findmnt" <<'SH'
#!/bin/bash

printf '%s\n' "$TEST_ROOT_SOURCE"
SH

cat >"$stub_bin/lsblk" <<'SH'
#!/bin/bash

device="${!#}"
[[ $device == "$TEST_RESOLVABLE_DEVICE" ]] || exit 1
printf '%s\n' "$TEST_ROOT_TYPE"
SH

cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash

"$@"
SH

chmod +x "$stub_bin"/*

run_migration() {
  local root_source="$1" device="$2" root_type="$3"
  mkdir -p "$(dirname "$autologin")"
  printf '[Autologin]\nUser=owner\n' >"$autologin"

  TEST_ROOT_SOURCE="$root_source" TEST_RESOLVABLE_DEVICE="$device" TEST_ROOT_TYPE="$root_type" \
    PATH="$stub_bin:$PATH" \
    bash -euo pipefail -c '
      migration=$1; autologin=$2
      # Redirect the one absolute path the migration writes into the sandbox.
      sed "s|/etc/sddm.conf.d/autologin.conf|$autologin|g" "$migration" >"$autologin.script"
      bash -euo pipefail "$autologin.script"
    ' bash "$migration" "$autologin" >/dev/null
}

# An encrypted btrfs root: the passphrase was typed at boot, so autologin stays.
run_migration '/dev/mapper/root[/@]' /dev/mapper/root crypt
[[ -f $autologin ]] ||
  fail "an encrypted btrfs root keeps its autologin" "the subvolume suffix has to be stripped before lsblk sees the device"
pass "an encrypted btrfs root keeps its autologin"

# Same machine shape without encryption: SDDM should ask who is logging in.
run_migration '/dev/mapper/root[/@]' /dev/mapper/root part
[[ ! -e $autologin ]] || fail "an unencrypted btrfs root drops autologin" "$(cat "$autologin")"
pass "an unencrypted btrfs root drops autologin"

# Plain partitions carry no subvolume suffix.
run_migration /dev/nvme0n1p2 /dev/nvme0n1p2 crypt
[[ -f $autologin ]] || fail "an encrypted plain root keeps its autologin"
run_migration /dev/nvme0n1p2 /dev/nvme0n1p2 part
[[ ! -e $autologin ]] || fail "an unencrypted plain root drops autologin"
pass "roots without a subvolume suffix are handled either way"
