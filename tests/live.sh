#!/usr/bin/env bash
# LIVE smoke test — maintainer / volunteer testers only. Never run in CI or from an automation agent.
# Needs: a Mac signed into iCloud+ and Accessibility granted to your terminal app.
# It creates ONE real Hide My Email address labelled "hmm-live-<timestamp>". Delete it afterwards in
# System Settings → Apple Account → iCloud → Hide My Email.
set -uo pipefail
cd "$(dirname "$0")/.."

label="hmm-live-$(date +%Y%m%d-%H%M%S)"
before=$(pbpaste 2>/dev/null || true)

echo "=== Hide My Mail live test ==="
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)), locale $(defaults read -g AppleLocale 2>/dev/null), script v$(osascript src/hide-my-mail.applescript --version)"
echo "label: $label"
start=$(date +%s)
out=$(osascript src/hide-my-mail.applescript "$label" 2>&1); rc=$?
echo "took $(( $(date +%s) - start ))s, osascript exit $rc"
echo "output: $out"
after=$(pbpaste 2>/dev/null || true)

if [[ "$out" == Created* && "$after" == *@* && "$after" != "$before" ]]; then
  echo "LIVE PASS — clipboard now: $after"
  echo "Now delete the '$label' address in System Settings."
  exit 0
fi
echo "LIVE FAIL"
if [ -f "$HOME/Desktop/hide-my-mail-diagnosis.txt" ]; then
  echo "diagnosis written: ~/Desktop/hide-my-mail-diagnosis.txt ($(wc -l < "$HOME/Desktop/hide-my-mail-diagnosis.txt" | tr -d ' ') lines) — attach it to the issue"
fi
exit 1
