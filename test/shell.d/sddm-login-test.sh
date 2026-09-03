#!/bin/bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

pam_file="$test_tmp/etc/pam.d/sddm"
state_file="$test_tmp/var/lib/sddm/state.conf"

run_sddm_setup() {
  OMARCHY_SDDM_PAM_FILE="$pam_file" \
    OMARCHY_SDDM_STATE_FILE="$state_file" \
    OMARCHY_FIRST_INSTALL="${OMARCHY_FIRST_INSTALL:-0}" \
    OMARCHY_INSTALL_USER="${OMARCHY_INSTALL_USER:-}" \
    bash -e "$ROOT/install/login/sddm.sh"
}

OMARCHY_FIRST_INSTALL=1 OMARCHY_INSTALL_USER=owner run_sddm_setup
[[ -f $state_file ]] ||
  fail "first install seeds SDDM's last user"
[[ $(cat "$state_file") == $'[Last]\nUser=owner' ]] ||
  fail "SDDM state names the install user" "$(cat "$state_file")"
pass "first install seeds SDDM's last user"

printf '[Last]\nSession=custom.desktop\nUser=existing\n' >"$state_file"
OMARCHY_FIRST_INSTALL=1 OMARCHY_INSTALL_USER=owner run_sddm_setup
[[ $(cat "$state_file") == $'[Last]\nSession=custom.desktop\nUser=existing' ]] ||
  fail "first install preserves existing SDDM state" "$(cat "$state_file")"
pass "first install preserves existing SDDM state"

rm -f "$state_file"
OMARCHY_FIRST_INSTALL=0 OMARCHY_INSTALL_USER=owner run_sddm_setup
[[ ! -e $state_file ]] ||
  fail "upgrade does not create SDDM state"
pass "upgrade does not create SDDM state"

OMARCHY_FIRST_INSTALL=1 OMARCHY_INSTALL_USER="" run_sddm_setup
[[ ! -e $state_file ]] ||
  fail "deferred provisioning does not create SDDM state without a user"
pass "deferred provisioning does not create SDDM state without a user"
