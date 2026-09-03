#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

leaf="$ROOT/install/hardware/apple/fix-asahi-hid-race.sh"
all="$ROOT/install/hardware/all.sh"
migration="$ROOT/migrations/1787433315.sh"
touchpad="$ROOT/bin/omarchy-hw-touchpad"

require_command jq

grep -q 'apple/fix-asahi-hid-race.sh' "$all" ||
  fail "the HID early-load runs during hardware setup"
pass "the HID early-load runs during hardware setup"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

stub_bin="$test_tmp/bin"
calls="$test_tmp/calls.log"
conf="$test_tmp/etc/dracut.conf.d/omarchy-apple-hid.conf"
compatible="$test_tmp/device-tree-compatible"
mkdir -p "$stub_bin"

# The leaf reads the architecture and the device tree from absolute paths, so
# every case has to say which machine it runs on rather than inherit the one
# the suite happens to be running on.
cat >"$stub_bin/uname" <<'SH'
#!/bin/bash

if [[ ${1:-} == "-m" ]]; then
  echo "${ARCH:-aarch64}"
elif [[ ${1:-} == "-r" ]]; then
  echo "6.0.0-test"
else
  exec /usr/bin/uname "$@"
fi
SH

cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash

printf 'sudo' >>"$TEST_LOG"
printf '\t%s' "$@" >>"$TEST_LOG"
printf '\n' >>"$TEST_LOG"
"$@"
SH

cat >"$stub_bin/dracut" <<'SH'
#!/bin/bash

printf 'dracut' >>"$TEST_LOG"
printf '\t%s' "$@" >>"$TEST_LOG"
printf '\n' >>"$TEST_LOG"
exit "${DRACUT_STATUS:-0}"
SH

# Stubbed rather than run: the real one would write the running user's state.
cat >"$stub_bin/omarchy-state" <<'SH'
#!/bin/bash

printf 'omarchy-state' >>"$TEST_LOG"
printf '\t%s' "$@" >>"$TEST_LOG"
printf '\n' >>"$TEST_LOG"
SH

# MODULES_PRESENT names the modules this kernel builds, so a kernel missing one
# can be tested on a machine that has both.
cat >"$stub_bin/modinfo" <<'SH'
#!/bin/bash

module="${!#}"
[[ " ${MODULES_PRESENT-hid_apple hid_magicmouse} " == *" $module "* ]]
SH

chmod +x "$stub_bin"/*

# Redirect the two absolute paths the leaf touches into the sandbox.
sandboxed_leaf="$test_tmp/leaf.sh"
sed -e "s|/etc/dracut.conf.d|$test_tmp/etc/dracut.conf.d|g" \
    -e "s|/proc/device-tree/compatible|$compatible|g" \
    "$leaf" >"$sandboxed_leaf"

run_leaf() {
  local arch="${1:-aarch64}" model="${2:-apple,j413}"
  rm -rf "$test_tmp/etc"
  : >"$calls"
  printf '%s' "$model" >"$compatible"

  ARCH="$arch" TEST_LOG="$calls" PATH="$stub_bin:$PATH" \
    MODULES_PRESENT="${MODULES_PRESENT-hid_apple hid_magicmouse}" \
    bash -eE -o pipefail -c 'source "$1"' bash "$sandboxed_leaf" </dev/null
}

run_leaf aarch64 'apple,j413' >/dev/null
[[ -f $conf ]] || fail "an Apple Silicon Mac gets the drop-in" "$(ls -R "$test_tmp/etc" 2>&1)"
grep -Fq 'force_drivers+=' "$conf" ||
  fail "the drop-in uses dracut force_drivers" "$(cat "$conf")"
grep -Fq 'hid_apple' "$conf" || fail "hid_apple is early-loaded" "$(cat "$conf")"
grep -Fq 'hid_magicmouse' "$conf" || fail "hid_magicmouse is early-loaded" "$(cat "$conf")"
pass "an Apple Silicon Mac gets the drop-in"

# The T2 Macs have their own leaf, and it writes hid_apple into an initramfs
# that has no dockchannel-hid to race with.
run_leaf x86_64 'apple,macbookpro' >/dev/null
[[ ! -f $conf ]] || fail "an Intel Mac is left alone" "$(cat "$conf")"
pass "an Intel Mac is left alone"

run_leaf aarch64 'raspberrypi,4-model-b' >/dev/null
[[ ! -f $conf ]] || fail "other aarch64 hardware is left alone" "$(cat "$conf")"
pass "other aarch64 hardware is left alone"

# A kernel with one of them built in, or gone: naming it anyway would pull a
# missing module into the image; leave absent drivers out.
MODULES_PRESENT="hid_apple" run_leaf >/dev/null
grep -Fq 'hid_apple' "$conf" || fail "a present driver is still early-loaded" "$(cat "$conf")"
! grep -Fq 'hid_magicmouse' "$conf" ||
  fail "a driver the kernel does not build is left out" "$(cat "$conf")"
pass "a driver the kernel does not build is left out"

MODULES_PRESENT="" run_leaf >/dev/null
[[ ! -f $conf ]] || fail "neither driver is named when the kernel builds none" "$(cat "$conf")"
pass "a kernel building neither driver still sources cleanly"

# Installs that predate the leaf never ran it, so the migration has to reach
# them. omarchy-migrate runs migrations under bash -euo pipefail.
run_migration() {
  local arch="${1:-aarch64}" model="${2:-apple,j413}" dracut_status="${3:-0}"
  : >"$calls"
  printf '%s' "$model" >"$compatible"

  ARCH="$arch" TEST_LOG="$calls" PATH="$stub_bin:$PATH" \
    DRACUT_STATUS="$dracut_status" \
    MODULES_PRESENT="${MODULES_PRESENT-hid_apple hid_magicmouse}" \
    OMARCHY_PATH="$test_tmp/omarchy" OMARCHY_APPLE_HID_CONF="$conf" \
    bash -euo pipefail "$migration"
}

# The migration runs the leaf out of OMARCHY_PATH, so the sandbox needs it
# where an install keeps it.
mkdir -p "$test_tmp/omarchy/install/hardware/apple"
cp "$sandboxed_leaf" "$test_tmp/omarchy/install/hardware/apple/fix-asahi-hid-race.sh"

rm -rf "$test_tmp/etc"
run_migration >/dev/null
[[ -f $conf ]] || fail "the migration fixes an install that never ran the leaf" "$(ls -R "$test_tmp/etc" 2>&1)"
grep -Fq $'dracut\t-f' "$calls" ||
  fail "the migration rebuilds the initramfs that carries force_drivers" "$(cat "$calls")"
grep -Fq $'omarchy-state\tset\treboot-required' "$calls" ||
  fail "the migration asks for the reboot that applies it" "$(cat "$calls")"
pass "the migration fixes an install that never ran the leaf"

run_migration >/dev/null
[[ ! -s $calls ]] || fail "a repaired install is left untouched" "$(cat "$calls")"
pass "the migration is idempotent"

# A failed rebuild leaves the running initramfs as it was, so there is nothing
# for a reboot to apply.
rm -rf "$test_tmp/etc"
run_migration aarch64 'apple,j413' 1 >/dev/null 2>&1
grep -Fq $'dracut\t-f' "$calls" || fail "a failed rebuild is still attempted" "$(cat "$calls")"
! grep -Fq 'omarchy-state' "$calls" ||
  fail "a failed rebuild does not ask for a reboot" "$(cat "$calls")"
pass "a failed rebuild does not ask for a reboot"

rm -rf "$test_tmp/etc"
run_migration x86_64 'apple,macbookpro' >/dev/null
[[ ! -e $conf ]] || fail "the migration skips an Intel Mac" "$(cat "$conf")"
! grep -Fq 'dracut' "$calls" ||
  fail "the migration rebuilds nothing on an Intel Mac" "$(cat "$calls")"
pass "the migration skips hardware without the race"

# Hyprland names the internal trackpad after its MTP HID interface, so the
# device the menu gates on says neither touchpad nor trackpad.
cat >"$stub_bin/hyprctl" <<'SH'
#!/bin/bash

jq -n --arg name "${MOUSE_NAME:-}" \
  '{mice: (if $name == "" then [] else [{name: $name}] end), keyboards: []}'
SH
chmod +x "$stub_bin/hyprctl"

detected() {
  MOUSE_NAME="$1" PATH="$stub_bin:$PATH" bash "$touchpad"
}

[[ $(detected "apple-mtp-multi-touch") == "apple-mtp-multi-touch" ]] ||
  fail "the Apple Silicon trackpad is detected" "$(detected "apple-mtp-multi-touch")"
pass "the Apple Silicon trackpad is detected"

# omarchy-toggle-input-device passes the name straight to hl.device, so a name
# that does not match leaves the menu entry hidden and the toggle dead.
for name in "elan-touchpad" "apple-magic-trackpad-2"; do
  [[ $(detected "$name") == "$name" ]] || fail "the touchpads that already worked still do" "$name"
done
pass "the touchpads that already worked still do"

[[ -z $(detected "logitech-mx-master-3") ]] ||
  fail "an ordinary mouse is not mistaken for a touchpad" "$(detected "logitech-mx-master-3")"
pass "an ordinary mouse is not mistaken for a touchpad"
