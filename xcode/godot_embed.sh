#!/bin/bash
# Xcode build phase: puts the Godot engine and the game's pack inside Vepxis.app.
# Xcode then signs the whole bundle (sandbox entitlements) and Archive uploads it.
#   Debug build  -> Godot debug template;  Release / Archive -> release template.
#   The pack (xcode/build/Vepxis.pck) is exported fresh on Archive, or when missing,
#   or when VEPXIS_EXPORT=always is set (Scheme > Run > Environment).
set -euo pipefail

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
GAME="$(cd "$SRCROOT/.." && pwd)"
CACHE="$SRCROOT/build"
mkdir -p "$CACHE"

[ -x "$GODOT" ] || { echo "error: Godot not found at $GODOT (set GODOT=...)"; exit 1; }

VER="$("$GODOT" --version | awk -F. '{print $1"."$2"."$3"."$4}')"
TPL="$HOME/Library/Application Support/Godot/export_templates/$VER/macos.zip"
[ -f "$TPL" ] || { echo "error: export templates $VER missing: $TPL"; exit 1; }

if [ "$CONFIGURATION" = "Debug" ]; then KIND=debug; else KIND=release; fi
BIN="$CACHE/godot_macos_$KIND.universal"
if [ ! -f "$BIN" ] || [ "$TPL" -nt "$BIN" ]; then
  echo "Godot: unpacking $KIND template from $VER"
  unzip -p "$TPL" "macos_template.app/Contents/MacOS/godot_macos_$KIND.universal" > "$BIN.tmp"
  mv "$BIN.tmp" "$BIN"; chmod +x "$BIN"
fi

PCK="$CACHE/Vepxis.pck"
if [ ! -f "$PCK" ] || [ "$ACTION" = "install" ] || [ "${VEPXIS_EXPORT:-}" = "always" ]; then
  echo "Godot: exporting the game pack (preset macOS) — takes a few minutes"
  rm -f "$PCK.tmp.pck"
  env -i HOME="$HOME" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
    "$GODOT" --headless --path "$GAME" --export-pack "macOS" "$PCK.tmp.pck"
  [ -s "$PCK.tmp.pck" ] || { echo "error: Godot pack export failed"; exit 1; }
  mv "$PCK.tmp.pck" "$PCK"
fi

APP="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH"
mkdir -p "$APP/MacOS" "$APP/Resources"
rm -f "$APP/MacOS/$EXECUTABLE_NAME" "$APP/Resources/$EXECUTABLE_NAME.pck"
cp -c "$BIN" "$APP/MacOS/$EXECUTABLE_NAME" 2>/dev/null || cp "$BIN" "$APP/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP/MacOS/$EXECUTABLE_NAME"
cp -c "$PCK" "$APP/Resources/$EXECUTABLE_NAME.pck" 2>/dev/null || cp "$PCK" "$APP/Resources/$EXECUTABLE_NAME.pck"
# TestFlight wants a new build number on every upload: Archive stamps date.time.
if [ "$ACTION" = "install" ]; then
  BUILD="$(date +%y%m%d.%H%M)"
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$APP/Info.plist"
  echo "Godot: build number $BUILD"
fi
echo "Godot: $KIND engine + $(du -h "$PCK" | cut -f1) pack in $APP"
