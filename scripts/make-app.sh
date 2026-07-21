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

# --- Make the bundle self-contained (relocatable) ---------------------------
# The binary links libfff_c.dylib by an absolute path into Vendor/. Embed the
# dylib in Contents/Frameworks and rewrite the load command to @rpath so the
# app runs on any machine (required for distribution / Homebrew).
mkdir -p "$CONTENTS/Frameworks"
DYLIB_SRC="$ROOT/Vendor/fff/target/release/libfff_c.dylib"
cp "$DYLIB_SRC" "$CONTENTS/Frameworks/libfff_c.dylib"
OLD_REF="$(otool -L "$CONTENTS/MacOS/Pathfinder" | awk '/libfff_c\.dylib/{print $1; exit}')"
install_name_tool -id "@rpath/libfff_c.dylib" "$CONTENTS/Frameworks/libfff_c.dylib"
if [[ -n "$OLD_REF" ]]; then
  install_name_tool -change "$OLD_REF" "@rpath/libfff_c.dylib" "$CONTENTS/MacOS/Pathfinder"
fi
install_name_tool -add_rpath "@executable_path/../Frameworks" "$CONTENTS/MacOS/Pathfinder" 2>/dev/null || true
# Drop the machine-local dev rpath if present (harmless if absent).
install_name_tool -delete_rpath "$ROOT/Vendor/fff/target/release" "$CONTENTS/MacOS/Pathfinder" 2>/dev/null || true
# Re-sign ad-hoc: install_name_tool invalidates the signature; unsigned code
# won't launch on Apple Silicon. (For real distribution, sign with a Developer
# ID and notarize instead — see README.)
codesign --force --sign - --timestamp=none "$CONTENTS/Frameworks/libfff_c.dylib" >/dev/null 2>&1 || true
codesign --force --deep --sign - --timestamp=none "$APP" >/dev/null 2>&1 || true

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
