#!/bin/bash

source "$(dirname "${BASH_SOURCE[0]}")/base-test.sh"

export PATH="$ROOT/bin:$PATH"

require_command jq
require_command node

copy_url_id=$(node - <<'JS' "$ROOT/default/chromium/extensions/copy-url/manifest.json"
const crypto = require('crypto')
const fs = require('fs')

const manifest = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))
const hash = crypto.createHash('sha256').update(Buffer.from(manifest.key, 'base64')).digest()
const alphabet = 'abcdefghijklmnop'
let id = ''

for (const byte of hash.subarray(0, 16)) {
  id += alphabet[byte >> 4]
  id += alphabet[byte & 0x0f]
}

process.stdout.write(id)
JS
)

[[ $copy_url_id == "bgpiichlckmfanooecilcjemknkcpngb" ]] ||
  fail "copy-url extension manifest has the stable id" "$copy_url_id"
pass "copy-url extension manifest has the stable id"

jq -e '
  .manifest_version == 3 and
  (.permissions | index("clipboardWrite")) and
  (.permissions | index("offscreen")) and
  (.background.service_worker | startswith("background-"))
' "$ROOT/default/chromium/extensions/copy-url/manifest.json" >/dev/null ||
  fail "copy-url extension uses an offscreen clipboard document"
[[ -f $ROOT/default/chromium/extensions/copy-url/offscreen.html &&
  -f $ROOT/default/chromium/extensions/copy-url/offscreen.js ]] ||
  fail "copy-url extension ships its offscreen clipboard document"
pass "copy-url extension uses an offscreen clipboard document"

jq -e '.action != null' "$ROOT/default/chromium/extensions/copy-url/manifest.json" >/dev/null &&
  grep -q 'action.onClicked' "$ROOT/default/chromium/extensions/copy-url/"background-*.js ||
  fail "copy-url extension is clickable from the toolbar"
pass "copy-url extension is clickable from the toolbar"
