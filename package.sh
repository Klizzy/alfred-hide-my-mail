#!/usr/bin/env bash
# Packages the workflow into a .alfredworkflow bundle (a renamed zip).
#
# Usage: ./package.sh
# Output: HideMyMail.alfredworkflow in the repo root.
set -euo pipefail
cd "$(dirname "$0")"

OUTPUT="HideMyMail.alfredworkflow"
rm -f "$OUTPUT"

# Flat files at the bundle root...
zip -j "$OUTPUT" info.plist icon.png HideMyMail.scpt diagnose.scpt
# ...and the ui-maps directory preserving its path (no -j) so pwd-relative reads resolve.
zip "$OUTPUT" ui-maps/sequoia-15.plist ui-maps/tahoe-26.plist

echo "Built $OUTPUT"
