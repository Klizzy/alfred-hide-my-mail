#!/usr/bin/env bash
# Packages the workflow files into a .alfredworkflow bundle (a renamed zip).
#
# Usage: ./package.sh
# Output: HideMyMail.alfredworkflow in the repo root.

set -euo pipefail

cd "$(dirname "$0")"

OUTPUT="HideMyMail.alfredworkflow"

rm -f "$OUTPUT"
zip -j "$OUTPUT" info.plist icon.png

echo "Built $OUTPUT"
