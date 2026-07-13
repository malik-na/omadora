#!/bin/bash

# Every omarchy-* command that a script or a Hyprland config actually invokes must exist in bin/.
#
# This is not hypothetical. Upstream renames commands (omarchy-cmd-share -> omarchy-menu-share,
# omarchy-lock-screen -> omarchy-system-lock, omarchy-cmd-screenshot -> omarchy-capture-screenshot),
# and when a merge keeps the fork's side of a file that calls the old name, the result is a menu entry
# that silently does nothing and a lock screen that never appears. Nothing else catches that: the
# scripts are syntactically fine, shellcheck is happy, and the failure only shows up when a user
# clicks the entry.
#
# Only invocations are checked - a command name inside a comment, a URL or a grep pattern is not one.
#
# Exit codes: 0 = every invoked command exists, non-zero = something calls a command that is not there.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Commands that live outside bin/ (shipped by the desktop session, or defined inline).
KNOWN_EXTERNAL=(
  omarchy-webapp-handler # matched inside a grep pattern in omarchy-webapp-remove, not invoked
)

is_known_external() {
  local candidate="$1" known
  for known in "${KNOWN_EXTERNAL[@]}"; do
    [[ "$candidate" == "$known" ]] && return 0
  done
  return 1
}

status=0

while read -r cmd; do
  [[ -n "$cmd" ]] || continue
  [[ -f "bin/$cmd" ]] && continue
  is_known_external "$cmd" && continue

  echo "[CRITICAL] $cmd is invoked but does not exist in bin/"
  grep -rn "\b$cmd\b" bin/ default/ config/ 2>/dev/null | grep -vE "^\S+:[0-9]+:\s*#" | head -3 | sed 's/^/    /'
  status=1
done < <(
  for file in bin/* default/hypr/*.conf config/hypr/*.conf; do
    [[ -f "$file" ]] || continue
    # Drop URLs and comments first: neither is an invocation.
    sed -e 's|https\?://[^ "'\'']*||g' -e 's/#.*$//' "$file" |
      # A command position: start of line, after a case arm, a separator, exec, exec-once, or one of
      # the menu's own wrappers. The name must end there - omarchy-restart-$foo is an interpolation.
      grep -ohE '(^|[;&|(`]|\)[[:space:]]|\bexec\b[[:space:]]|\bexec-once[[:space:]]*=[[:space:]]*|\bpresent_terminal\b[[:space:]]|\bterminal\b[[:space:]]|\bcommand -v\b[[:space:]]|bash -c "|bash -lc .)[[:space:]]*omarchy-[a-z0-9-]*[a-z0-9]([[:space:]]|$|["'\'';)&|])' |
      grep -ohE 'omarchy-[a-z0-9-]*[a-z0-9]'
  done | sort -u
)

if ((status == 0)); then
  echo "PASS: every omarchy-* command that is invoked exists in bin/"
fi

exit $status
