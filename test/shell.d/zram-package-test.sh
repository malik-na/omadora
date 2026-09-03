#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

migration="$ROOT/migrations/1787669934.sh"
[[ -f $migration ]] || fail "the zram package repair migration exists"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
calls="$test_tmp/calls.log"
mkdir -p "$stub_bin"

cat >"$stub_bin/omarchy-pkg-missing" <<'STUB'
#!/bin/bash
printf 'missing %s\n' "$*" >>"$TEST_LOG"
(( ${OMARCHY_TEST_ZRAM_MISSING:-1} == 1 ))
STUB

cat >"$stub_bin/omarchy-pkg-add" <<'STUB'
#!/bin/bash
printf 'add %s\n' "$*" >>"$TEST_LOG"
STUB

cat >"$stub_bin/systemctl" <<'STUB'
#!/bin/bash
printf 'systemctl %s\n' "$*" >>"$TEST_LOG"
STUB

cat >"$stub_bin/sudo" <<'STUB'
#!/bin/bash
exec "$@"
STUB

chmod +x "$stub_bin"/*

assert_systemd_start_follows_reload() {
  local reload_line start_line

  reload_line=$(awk '$0 == "systemctl daemon-reload" { print NR; exit }' "$calls")
  start_line=$(awk '$0 == "systemctl start systemd-zram-setup@zram0.service" { print NR; exit }' "$calls")
  [[ -n $reload_line && -n $start_line ]] ||
    fail "the zram migration records both systemd calls"
  (( reload_line < start_line )) ||
    fail "the zram migration reloads systemd before starting zram"
}

run_migration() {
  : >"$calls"
  PATH="$stub_bin:$PATH" TEST_LOG="$calls" \
    OMARCHY_TEST_ZRAM_MISSING="$1" bash -euo pipefail "$migration" >/dev/null
}

run_migration 1
grep -Fx 'missing zram-generator' "$calls" >/dev/null ||
  fail "the zram migration checks whether zram-generator is installed"
grep -Fx 'add zram-generator' "$calls" >/dev/null ||
  fail "the zram migration installs a missing zram-generator"
grep -Fx 'systemctl daemon-reload' "$calls" >/dev/null ||
  fail "the zram migration reloads systemd after installing zram-generator"
grep -Fx 'systemctl start systemd-zram-setup@zram0.service' "$calls" >/dev/null ||
  fail "the zram migration starts the configured zram device"
assert_systemd_start_follows_reload
pass "the zram migration repairs an existing install without zram-generator"

run_migration 0
! grep -Fx 'add zram-generator' "$calls" >/dev/null ||
  fail "the zram migration does not reinstall an existing zram-generator"
grep -Fx 'systemctl start systemd-zram-setup@zram0.service' "$calls" >/dev/null ||
  fail "the zram migration starts zram when the package is already installed"
assert_systemd_start_follows_reload
pass "the zram migration is idempotent"
