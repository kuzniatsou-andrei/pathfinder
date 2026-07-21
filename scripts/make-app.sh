#!/bin/bash
# Assemble Pathfinder.app — a proper macOS bundle with an Info.plist (bundle
# identifier), so the app has a real identity: Dock/taskbar icon, no
# "missing main bundle identifier" warning, and window/tab state indexing.
#
# Usage: scripts/make-app.sh [debug|release]   (default: release)
# Drop a 1024x1024 PNG at Sources/PathfinderApp/Resources/AppIcon.png to embed
# the app icon; without it the app builds fine with the default icon.
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> swift build -c $CONFIG"
swift build -c "$CONFIG" --product PathfinderApp
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

APP="$ROOT/Pathfinder.app"
CONTENTS="$APP/Contents"
echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN_DIR/PathfinderApp" "$CONTENTS/MacOS/Pathfinder"
cp "$ROOT/Sources/PathfinderApp/Info.plist" "$CONTENTS/Info.plist"

# App icon: build AppIcon.icns from a single PNG if one was provided.
ICON_PNG="$ROOT/Sources/PathfinderApp/Resources/AppIcon.png"
if [[ -f "$ICON_PNG" ]]; then
  echo "==> generating AppIcon.icns from $ICON_PNG"
  ICONSET="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET"
  for size in 16 32 128 256 512; do
    sips -z "$size" "$size"        "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png"      >/dev/null
    sips -z $((size*2)) $((size*2)) "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"
  rm -rf "$(dirname "$ICONSET")"
else
  echo "==> no AppIcon.png found; skipping icon (default app icon will be used)"
fi

# Refresh Launch Services / Dock so a re-generated icon is picked up.
touch "$APP"

echo "==> done: $APP"
echo "    launch with: open \"$APP\""
