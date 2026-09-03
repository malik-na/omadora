#!/bin/bash
set -uo pipefail

FORM="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/install/provisioning/setup-form.sh"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
pass=0
failures=0

check() {
  local label="$1"
  shift
  if "$@"; then
    echo "✓ $label"
    ((++pass))
  else
    echo "✗ $label"
    ((++failures))
  fi
}

# shellcheck source=/dev/null
source "$FORM"

table_rows_are_complete() {
  printf '%s\n' "$OMARCHY_KEYBOARD_LAYOUTS" |
    awk -F'|' 'NF != 4 { print "bad row: " $0; exit 1 }'
}

labels_are_unique() {
  [[ $(printf '%s\n' "$OMARCHY_KEYBOARD_LAYOUTS" | cut -d'|' -f1 | sort | uniq -d | wc -l) -eq 0 ]]
}

shared_console_keymaps_diverge_on_xkb() {
  printf '%s\n' "$OMARCHY_KEYBOARD_LAYOUTS" |
    awk -F'|' 'seen[$2]++ && $3 $4 == prev[$2] { print "collision: " $0; exit 1 } { prev[$2] = $3 $4 }'
}

pick() {
  local selection="$1"
  rm -rf "$WORK/bin"
  mkdir -p "$WORK/bin"
  # The prompt pipes the layout list into gum, so the stub has to drain stdin:
  # exiting first kills cut with SIGPIPE, and pipefail reads that as a failed
  # prompt, which returns before any of the variables below are set.
  cat >"$WORK/bin/gum" <<STUB
#!/bin/bash
cat >/dev/null
printf '%s\n' '$selection'
STUB
  chmod +x "$WORK/bin/gum"

  keyboard="" keyboard_label="" keyboard_xkb_layout="" keyboard_xkb_variant=""
  PATH="$WORK/bin:$PATH" omarchy_prompt_keyboard
}

picked_keymaps() {
  printf '%s|%s|%s' "$keyboard" "$keyboard_xkb_layout" "$keyboard_xkb_variant"
}

expect_picked() {
  [[ $(picked_keymaps) == "$1" ]]
}

check "every layout row has label, console keymap, xkb layout and xkb variant" \
  table_rows_are_complete

check "no layout label appears twice" labels_are_unique

check "rows sharing a console keymap differ in their XKB pair" \
  shared_console_keymaps_diverge_on_xkb

pick "English (UK)"
check "English (UK) applies uk with XKB layout gb" \
  expect_picked "uk|gb|"

pick "English (US)"
check "English (US) applies us with an empty variant" \
  expect_picked "us|us|"

pick "Greek"
check "Greek applies gr" \
  expect_picked "gr|gr|"

pick "French (Switzerland)"
check "French (Switzerland) carries its fr variant" \
  expect_picked "fr_CH|ch|fr"

pick "Serbian"
check "Serbian (Latin) carries its latin variant" \
  expect_picked "sr-latin|rs|latin"

pick "English (US, Dvorak)"
check "US Dvorak maps onto the us layout with the dvorak variant" \
  expect_picked "dvorak|us|dvorak"

echo
echo "=== $pass checks passed, $failures failed ==="
(( failures == 0 ))
