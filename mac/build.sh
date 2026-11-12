#!/bin/bash
# Builds ThaiPinyin.app and installs it to ~/Library/Input Methods.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/ThaiPinyin.app
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

swiftc -O -module-name ThaiPinyin \
  -framework Cocoa -framework InputMethodKit -framework JavaScriptCore \
  Sources/*.swift -o "$APP/Contents/MacOS/ThaiPinyin"

cp Info.plist "$APP/Contents/Info.plist"
node ../tools/chat_spellings.js # chat spellings like krung/tum/mua (no-op if current)
node ../tools/precompute_keys.js # sound keys for fast startup (no-op if current)
cp ../web/phonemes.js ../web/dict.js ../web/extra.js ../web/engine.js "$APP/Contents/Resources/"
[ -f ../web/personal.js ] && cp ../web/personal.js "$APP/Contents/Resources/"
[ -f ../web/names.js ] && cp ../web/names.js "$APP/Contents/Resources/"
# Engine tests must pass before installing.
node ../tests/mapping.test.js && node ../tests/edge.test.js && node ../tests/accuracy.test.js && node ../tests/roundtrip.test.js 3000
# Keyboard tests against a fake text field.
T=build/Tests.app; mkdir -p "$T/Contents/MacOS"
cp -R "$APP/Contents/Resources" "$T/Contents/" && cp Info.plist "$T/Contents/"
swiftc -O -module-name ThaiPinyin -framework Cocoa -framework InputMethodKit -framework JavaScriptCore \
  Sources/Engine.swift Sources/InputController.swift Sources/CandidateWindow.swift Tests/main.swift -o "$T/Contents/MacOS/Tests"
"$T/Contents/MacOS/Tests" | tail -1
swift make_icon.swift menu "$APP/Contents/Resources/icon.tiff"
# App icon (Finder, System Settings): the iPhone app's icon in the Mac icon shape.
swift make_icon.swift app ../ios/App/Assets.xcassets/AppIcon.appiconset/icon.png build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"

DEST="$HOME/Library/Input Methods"
mkdir -p "$DEST"
pkill -x ThaiPinyin 2>/dev/null || true # restart if an older copy is running
rm -rf "$DEST/ThaiPinyin.app"
cp -R "$APP" "$DEST/"
echo "Installed to $DEST/ThaiPinyin.app"
