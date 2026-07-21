#!/bin/bash
# Assemble Pathfinder.app — a proper macOS bundle with an Info.plist (bundle
# identifier), so the app has a real identity: Dock/taskbar icon, no
# "missing main bundle identifier" warning, and window/tab state indexing.
#
# Usage: scripts/make-app.sh [debug|release]   (default: release)
# Drop a 1024x1024 PNG at Sources/PathfinderApp/Resources/AppIcon.png to embed
# the app icon; without it the app builds fine with the default icon.
set -euo pipefail

# Usage:
#   scripts/make-app.sh [debug|release]   build the bundle (default release)
#   scripts/make-app.sh install           build release, copy to /Applications
#                                          (or ~/Applications) and pin to the Dock
CMD="${1:-release}"
if [ "$CMD" = "install" ]; then CONFIG="release"; DO_INSTALL=1; else CONFIG="$CMD"; DO_INSTALL=0; fi
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

if [[ "$DO_INSTALL" == "1" ]]; then
  # Prefer /Applications (visible to everyone); fall back to ~/Applications if
  # it isn't writable without sudo.
  if [[ -w /Applications ]]; then DEST_DIR="/Applications"; else DEST_DIR="$HOME/Applications"; fi
  mkdir -p "$DEST_DIR"
  DEST="$DEST_DIR/Pathfinder.app"
  echo "==> installing to $DEST"
  rm -rf "$DEST"
  cp -R "$APP" "$DEST"

  # Pin to the Dock (skip if already present), then restart the Dock.
  PINNED=0
  defaults read com.apple.dock persistent-apps 2>/dev/null | grep -q "$DEST" && PINNED=1 || true
  if [[ "$PINNED" == "0" ]]; then
    defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$DEST</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
    killall Dock 2>/dev/null || true
    echo "==> pinned to Dock"
  else
    echo "==> already pinned to Dock"
  fi
  echo "==> installed. Open from Launchpad/Spotlight/Dock as \"Pathfinder\"."
fi

exit 0
