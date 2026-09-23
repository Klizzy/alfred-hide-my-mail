#!/usr/bin/env bash
# Builds HideMyMail.alfredworkflow (a zip). Alfred needs info.plist at the bundle root;
# the scripts keep their src/ path because info.plist references them as src/<name>.applescript.
set -euo pipefail
cd "$(dirname "$0")"

OUTPUT="HideMyMail.alfredworkflow"
rm -f "$OUTPUT"

chmod +x src/*.applescript
zip -q -j "$OUTPUT" info.plist icon.png alfred-command.png
zip -q "$OUTPUT" src/hide-my-mail.applescript src/diagnose.applescript

echo "Built $OUTPUT:"
zipinfo -1 "$OUTPUT"
