#!/bin/bash
# Build a distributable, self-contained Pathfinder.app and zip it for a
# GitHub Release (the artifact a Homebrew Cask downloads).
#
# Usage: scripts/make-release.sh [version]   (default 1.0)
# Output: dist/Pathfinder-<version>.zip  + its sha256 (paste into the cask).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
VERSION="${1:-1.0}"

"$ROOT/scripts/make-app.sh" release

mkdir -p dist
ZIP="dist/Pathfinder-$VERSION.zip"
rm -f "$ZIP"
# ditto keeps the bundle structure, resource forks, and code signature intact.
ditto -c -k --sequesterRsrc --keepParent "$ROOT/Pathfinder.app" "$ZIP"

SHA="$(shasum -a 256 "$ZIP" | awk '{print $1}')"
echo ""
echo "==> artifact: $ZIP"
echo "==> sha256:   $SHA"
echo ""
echo "Update Casks/pathfinder.rb:"
echo "    version \"$VERSION\""
echo "    sha256  \"$SHA\""
echo "then attach $ZIP to a GitHub Release tagged v$VERSION."
