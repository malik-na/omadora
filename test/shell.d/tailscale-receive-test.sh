#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

WORKDIR=$(mktemp -d)
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

downloads="$WORKDIR/downloads"
mkdir -p "$WORKDIR/bin" "$downloads" "$WORKDIR/outbox"
printf 'mine' >"$downloads/unrelated.txt"

# Stands in for the daemon handing over whatever is waiting in the inbox. A
# decoy is whatever else drops into the downloads directory while Taildrop is
# still blocking on the next delivery.
cat >"$WORKDIR/bin/tailscale" <<SH
#!/bin/bash
target="\${*: -1}"
[[ -n \${DECOY:-} ]] && printf 'iso' >"$downloads/\$DECOY"
mv "$WORKDIR/outbox/"* "\$target/"
SH

cat >"$WORKDIR/bin/omarchy-notification-send" <<SH
#!/bin/bash
printf '%s\n' "\$*" >>"$WORKDIR/notifications"
SH

chmod +x "$WORKDIR/bin/"*

receive() {
  local expected="$1"
  shift

  : >"$WORKDIR/notifications"
  PATH="$WORKDIR/bin:$PATH" "$@" "$ROOT/bin/omarchy-tailscale-receive" --once "$downloads"

  for _ in {1..50}; do
    (($(wc -l <"$WORKDIR/notifications") >= expected)) && break
    sleep 0.1
  done
}

printf 'png' >"$WORKDIR/outbox/photo.png"
printf 'pdf' >"$WORKDIR/outbox/notes with space.pdf"
receive 2 env

notifications=$(<"$WORKDIR/notifications")

[[ -f $downloads/photo.png && -f "$downloads/notes with space.pdf" ]] ||
  fail "taildrop receive saves incoming files" "$(ls "$downloads")"
pass "taildrop receive saves incoming files"

grep -qF -- "Received photo.png Saved to $downloads -u critical --image $downloads/photo.png" <<<"$notifications" ||
  fail "taildrop receive previews received images" "$notifications"
pass "taildrop receive previews received images"

while IFS= read -r line; do
  [[ $line == *"-u critical"* ]] || fail "taildrop receive announcements wait to be answered" "$line"
done <<<"$notifications"
pass "taildrop receive announcements wait to be answered"

grep -q "^Received notes with space.pdf .* -g " <<<"$notifications" ||
  fail "taildrop receive announces other files with a glyph" "$notifications"
pass "taildrop receive announces other files with a glyph"

# The shell keeps the click command with the toast, so receiving does not have
# to sit blocked on an answer -- and the toast still opens the file after a shell
# restart. The path rides as its own discrete --exec argument, so the shell runs
# it as literal data with no quoting for a name with spaces to get wrong.
grep -qF -- "--exec xdg-open $downloads/photo.png" <<<"$notifications" ||
  fail "taildrop receive attaches the open command to the notification" "$notifications"
grep -qF -- "--exec xdg-open $downloads/notes with space.pdf" <<<"$notifications" ||
  fail "taildrop receive carries spaced names as a literal open argument" "$notifications"
pass "taildrop receive lets a click open the received file"

grep -q "unrelated.txt" <<<"$notifications" &&
  fail "taildrop receive leaves the rest of the downloads directory alone" "$notifications"
pass "taildrop receive leaves the rest of the downloads directory alone"

# A second delivery of the same name, alongside a download that arrives while
# Taildrop is waiting.
printf 'png' >"$WORKDIR/outbox/photo.png"
receive 1 env DECOY=browser-download.iso

notifications=$(<"$WORKDIR/notifications")

[[ -f $downloads/photo-1.png ]] || fail "taildrop receive keeps both files on a name clash" "$(ls "$downloads")"
grep -q "^Received photo-1.png " <<<"$notifications" ||
  fail "taildrop receive keeps both files on a name clash" "$notifications"
pass "taildrop receive keeps both files on a name clash"

# ln treats an existing directory as a container unless the name is rejected
# before the link. The received file must get the numbered name beside it, not
# disappear inside a directory that happens to share its filename.
mkdir -p "$downloads/album.png"
printf 'png' >"$WORKDIR/outbox/album.png"
receive 1 env

[[ -f $downloads/album-1.png && ! -e "$downloads/album.png/album.png" ]] ||
  fail "taildrop receive does not put a file inside a same-named directory" "$(find "$downloads/album.png" -maxdepth 2 -print)"
pass "taildrop receive skips a same-named directory"

# -e follows symlinks, so a dangling link is another occupied name that has to
# be treated as a collision rather than leaving the transfer in staging.
ln -s ./missing-target "$downloads/dangling.txt"
printf 'text' >"$WORKDIR/outbox/dangling.txt"
receive 1 env

[[ -f $downloads/dangling-1.txt && -L $downloads/dangling.txt ]] ||
  fail "taildrop receive skips a dangling same-named symlink" "$(find "$downloads" -maxdepth 2 -name 'dangling*' -print)"
pass "taildrop receive skips a dangling same-named symlink"

# find's default newline delimiter splits a legal filename into two paths and
# strands the staged file. The receiver has to enumerate the inbox by NUL.
newline_name=$'line\nbreak.txt'
printf 'text' >"$WORKDIR/outbox/$newline_name"
receive 1 env

[[ -f "$downloads/$newline_name" ]] ||
  fail "taildrop receive preserves filenames containing newlines" "$(find "$downloads/.omarchy-taildrop" -maxdepth 1 -print)"
pass "taildrop receive preserves filenames containing newlines"

grep -q "browser-download.iso" <<<"$notifications" &&
  fail "taildrop receive ignores downloads that arrive while it waits" "$notifications"
pass "taildrop receive ignores downloads that arrive while it waits"

[[ -z $(ls -A "$downloads/.omarchy-taildrop") ]] ||
  fail "taildrop receive empties its staging directory" "$(ls -A "$downloads/.omarchy-taildrop")"
pass "taildrop receive empties its staging directory"
