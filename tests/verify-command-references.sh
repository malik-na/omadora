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
# quattro drives Hyprland from Lua (default/hypr/**/*.lua, config/hypr/*.lua), not the old .conf
# files, so the Lua bindings are scanned too: a binding pointing at a command the merge dropped is
# exactly this class of bug.
#
# Only invocations are checked - a command name inside a comment, a URL or a grep pattern is not one.
#
# Exit codes: 0 = every invoked command exists, non-zero = something calls a command that is not there.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Commands that are not bin/ scripts and are known-good references, with the reason each is not a bug.
KNOWN_EXTERNAL=(
  omarchy-webapp-handler # matched inside a grep pattern in omarchy-webapp-remove, not invoked
  omarchy-nvim-refresh   # omarchy-reinstall-configs guards it with omarchy-cmd-present; shipped only
  omarchy-nvim-setup     # by the optional upstream nvim package, which Fedora replaces with lazyvim
  omarchy-settings       # an Arch package name in omarchy-dev-pkg-test's PKGS array, not a command
  omarchy-settings-dev   # likewise a package name, not a command
)

# No files are skipped. Upstream's Arch-only omarchy-upgrade-to-quattro used to be excluded here
# (its body listed Arch package names as data); this fork upgrades through omarchy-update and the
# migration runner, so that command was removed.
SKIP_FILES=()

is_skipped_file() {
  local candidate="$1" skip
  for skip in "${SKIP_FILES[@]}"; do
    [[ "$candidate" == "$skip" ]] && return 0
  done
  return 1
}

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
  {
    # Shell scripts in bin/: an invocation sits at a command position (line start, after a separator,
    # exec/exec-once, or one of the menu wrappers), and the name ends there (omarchy-restart-$foo is
    # an interpolation, not a fixed command). Strip URLs and # comments first.
    for file in bin/*; do
      [[ -f "$file" ]] || continue
      is_skipped_file "$file" && continue
      sed -e 's|https\?://[^ "'\'']*||g' -e 's/#.*$//' "$file" |
        grep -ohE '(^|[;&|(`]|\)[[:space:]]|\bexec\b[[:space:]]|\bexec-once[[:space:]]*=[[:space:]]*|\bpresent_terminal\b[[:space:]]|\bterminal\b[[:space:]]|\bcommand -v\b[[:space:]]|bash -c "|bash -lc .)[[:space:]]*omarchy-[a-z0-9-]*[a-z0-9]([[:space:]]|$|["'\'';)&|])' |
        grep -ohE 'omarchy-[a-z0-9-]*[a-z0-9]'
    done

    # Hyprland Lua drives commands from double-quoted string literals: o.bind(..., "omarchy-foo bar"),
    # hl.exec_cmd("omarchy-foo"), o.launch("omarchy-foo"). Strip -- comments, then take the command
    # word of each complete "omarchy-..." string - one the quote closes ("omarchy-foo") or a space
    # separates from its args ("omarchy-foo bar"). A string that instead runs straight into a Lua
    # concatenation ("omarchy-launch-" .. name) is a dynamic prefix, not a command, and is skipped.
    for file in default/hypr/*.lua default/hypr/bindings/*.lua default/hypr/apps/*.lua config/hypr/*.lua; do
      [[ -f "$file" ]] || continue
      sed -e 's/--.*$//' "$file" |
        grep -ohE '"omarchy-[a-z0-9-]*[a-z0-9]("|[[:space:]])' |
        sed -e 's/^"//' -e 's/["[:space:]]$//'
    done
  } | sort -u
)

if ((status == 0)); then
  echo "PASS: every omarchy-* command that is invoked exists in bin/"
fi

exit $status
