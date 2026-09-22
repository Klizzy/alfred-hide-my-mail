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

echo "ALL HEADLESS CHECKS PASSED"
