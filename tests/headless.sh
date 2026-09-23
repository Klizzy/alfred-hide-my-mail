#!/usr/bin/env bash
# Headless checks — safe to run anywhere (no GUI, no iCloud, no Accessibility). Runs locally and in CI.
set -euo pipefail
cd "$(dirname "$0")/.."

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "ok   $*"; }

plutil -lint info.plist >/dev/null || fail "info.plist does not lint"
ok "info.plist lints"

for f in src/hide-my-mail.applescript src/diagnose.applescript; do
  [ -f "$f" ] || fail "$f missing"
  head -1 "$f" | grep -q '^#!/usr/bin/osascript$' || fail "$f: first line must be #!/usr/bin/osascript"
  [ -x "$f" ] || fail "$f is not executable"
  osacompile -o /dev/null "$f" || fail "$f does not compile"
  ok "$f: shebang, executable, compiles"
done

# Terminology guard: an identifier that collides with System Events terminology (e.g. a parameter named
# `container`) compiles fine but resolves to the application's term at runtime. osacompile→osadecompile
# round-trips the source through the compiler's terminology, so a collision shows up as the raw term.
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
for f in src/hide-my-mail.applescript src/diagnose.applescript; do
  scpt="$tmpdir/$(basename "$f" .applescript).scpt"
  osacompile -o "$scpt" "$f" || fail "$f does not compile to $scpt"
  if osadecompile "$scpt" | grep -qE ' of container|container of '; then
    fail "$f: identifier resolves to System Events' 'container' terminology — rename it (e.g. axContainer)"
  fi
  ok "$f: no System Events terminology collision after compile/decompile round-trip"
done
rm -rf "$tmpdir"
trap - EXIT

# Shared navigation block: edited in hide-my-mail.applescript, copied by tests/sync-shared-block.sh.
extract_shared() { awk 'index($0,"-- BEGIN SHARED NAVIGATION")==1{p=1} p{print} index($0,"-- END SHARED NAVIGATION")==1{p=0}' "$1"; }
[ -n "$(extract_shared src/hide-my-mail.applescript)" ] || fail "hide-my-mail.applescript: shared navigation block markers missing"
[ -n "$(extract_shared src/diagnose.applescript)" ] || fail "diagnose.applescript: shared navigation block markers missing"
diff <(extract_shared src/hide-my-mail.applescript) <(extract_shared src/diagnose.applescript) >/dev/null \
  || fail "shared navigation block differs between the scripts — run: bash tests/sync-shared-block.sh"
ok "shared navigation block identical in both scripts"

# Apple's German card id contains U+2011 NON-BREAKING HYPHEN. An editor that normalises it breaks the match silently.
for f in src/hide-my-mail.applescript src/diagnose.applescript; do
  grep -q $'six-pack-card-E\xe2\x80\x91Mail-Adresse verbergen' "$f" || fail "$f: German Hide My Email card id lost its U+2011 hyphen"
done
ok "German Hide My Email card id keeps U+2011"

# The tile index drifted twice (2 → 5 → 6). Cards are selected by AXIdentifier; no bare positional click may return.
for f in src/hide-my-mail.applescript src/diagnose.applescript; do
  if grep -nE 'click UI element [0-9]+$' "$f"; then fail "$f: positional grid click found — use the shared pressHideMyEmailTile"; fi
done
ok "no positional grid clicks"

! grep -q "entire contents of" src/diagnose.applescript || fail "diagnose.applescript uses 'entire contents' (unbounded, stalled 5 s per probe) — use batched per-parent reads"
ok "no 'entire contents' in diagnose.applescript"

out=$(osascript src/hide-my-mail.applescript --selftest)
echo "$out" | sed 's/^/     /'
echo "$out" | tail -1 | grep -q '^SELFTEST PASS' || fail "hide-my-mail self-test"
ok "hide-my-mail self-test"

out=$(osascript src/diagnose.applescript --selftest)
echo "$out" | sed 's/^/     /'
echo "$out" | tail -1 | grep -q '^SELFTEST PASS' || fail "diagnose self-test"
ok "diagnose self-test"

[ "$(osascript src/hide-my-mail.applescript --version)" = "2.0" ] || fail "--version is not 2.0"
[ "$(osascript src/hide-my-mail.applescript)" = "Failed: no label given. Usage: hide <label>" ] || fail "no-argument message changed"
ok "CLI contract (--version, no-arg message)"

python3 tests/check_info_plist.py || fail "info.plist structure"

v_plist=$(plutil -extract version raw info.plist)
v_changelog=$(grep -m1 -E '^## v' CHANGELOG.md | sed 's/^## v//')
[ "$v_plist" = "$v_changelog" ] || fail "version mismatch: info.plist=$v_plist CHANGELOG=$v_changelog"
ok "version $v_plist consistent between info.plist and CHANGELOG"

./package.sh >/dev/null
for want in info.plist icon.png alfred-command.png src/hide-my-mail.applescript src/diagnose.applescript; do
  zipinfo -1 HideMyMail.alfredworkflow | grep -qx "$want" || fail "bundle missing $want"
done
[ "$(zipinfo -1 HideMyMail.alfredworkflow | wc -l | tr -d ' ')" = "5" ] || fail "bundle has unexpected extra files: $(zipinfo -1 HideMyMail.alfredworkflow | tr '\n' ' ')"
[ "$(zipinfo HideMyMail.alfredworkflow | grep -cE '^-rwx.*src/.*\.applescript$')" = "2" ] || fail "bundled scripts lost their executable bit"
ok "bundle: exactly the 5 expected files, scripts executable"

git check-ignore -q hide-my-mail-diagnosis.txt || fail "hide-my-mail-diagnosis*.txt must be gitignored (maintainer copies dumps into the repo root)"
ok "diagnosis dumps are gitignored"

echo "ALL HEADLESS CHECKS PASSED"
