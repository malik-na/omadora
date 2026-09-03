#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

mock_bin="$test_tmp/bin"
launch_log="$test_tmp/launch.log"
mkdir -p "$mock_bin"

cat >"$mock_bin/hyprctl" <<'SH'
#!/bin/bash
printf '[]\n'
SH

cat >"$mock_bin/setsid" <<'SH'
#!/bin/bash
printf '%s\n' "$@" >"$LAUNCH_LOG"
SH

chmod +x "$mock_bin/hyprctl" "$mock_bin/setsid"

run_and_read_args() {
  : >"$launch_log"
  PATH="$mock_bin:$ROOT/bin:$PATH" LAUNCH_LOG="$launch_log" "$@"

  local attempt
  for ((attempt = 0; attempt < 100; attempt++)); do
    [[ -s $launch_log ]] && break
    sleep 0.01
  done

  mapfile -t launch_args <"$launch_log"
}

url='https://example.test/?a=1&b=two words;next=three'
run_and_read_args "$ROOT/bin/omarchy-launch-or-focus-webapp" example "$url"
[[ ${launch_args[0]} == "omarchy-launch-webapp" ]] ||
  fail "webapp wrapper keeps the launch command"
[[ ${launch_args[1]} == "$url" ]] ||
  fail "webapp wrapper preserves URL shell metacharacters and spaces" \
    "expected: $url\nactual: ${launch_args[1]:-<missing>}"
pass "webapp wrapper preserves URL shell metacharacters and spaces"

tui_arg='query & value; keep this together'
run_and_read_args "$ROOT/bin/omarchy-launch-or-focus-tui" \
  --app-id=org.omarchy.test example-tui "$tui_arg"
[[ ${launch_args[0]} == "omarchy-launch-tui" ]] ||
  fail "TUI wrapper keeps the launch command"
[[ ${launch_args[1]} == "--app-id=org.omarchy.test" ]] ||
  fail "TUI wrapper preserves its app-id option"
[[ ${launch_args[2]} == "example-tui" ]] ||
  fail "TUI wrapper preserves the command"
[[ ${launch_args[3]} == "$tui_arg" ]] ||
  fail "TUI wrapper preserves argument shell metacharacters and spaces" \
    "expected: $tui_arg\nactual: ${launch_args[3]:-<missing>}"
pass "TUI wrapper preserves argument shell metacharacters and spaces"
