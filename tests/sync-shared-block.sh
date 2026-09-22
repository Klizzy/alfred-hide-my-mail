#!/usr/bin/env bash
# Copies the SHARED NAVIGATION block from src/hide-my-mail.applescript into src/diagnose.applescript.
# Edit the block in hide-my-mail.applescript only, then run this. tests/headless.sh fails when the copies differ.
set -euo pipefail
cd "$(dirname "$0")/.."

src=src/hide-my-mail.applescript
dst=src/diagnose.applescript
begin='-- BEGIN SHARED NAVIGATION'
end='-- END SHARED NAVIGATION'

grep -qxF -- "$begin" "$src" && grep -qxF -- "$end" "$src" || { echo "FAIL: $src has no shared block markers" >&2; exit 1; }
grep -qxF -- "$begin" "$dst" && grep -qxF -- "$end" "$dst" || { echo "FAIL: $dst has no shared block markers — add both marker lines where the block should live" >&2; exit 1; }

block=$(mktemp); out=$(mktemp)
trap 'rm -f "$block" "$out"' EXIT
awk -v b="$begin" -v e="$end" 'index($0,b)==1{p=1} p{print} index($0,e)==1{p=0}' "$src" > "$block"
awk -v b="$begin" -v e="$end" -v f="$block" '
  index($0,b)==1 { while ((getline l < f) > 0) print l; close(f); skip=1; next }
  index($0,e)==1 { skip=0; next }
  !skip { print }' "$dst" > "$out"
cat "$out" > "$dst"
echo "synced shared block: $(wc -l < "$block" | tr -d ' ') lines → $dst"
