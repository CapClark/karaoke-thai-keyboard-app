#!/bin/bash
# Builds the Mac keyboard for other people's Macs: universal (Apple silicon + Intel),
# signed with a Developer ID, without your personal words, zipped for notarization.
# Usage: mac/release.sh            then notarize the zip (see README).
set -euo pipefail
cd "$(dirname "$0")"
IDENTITY="${IDENTITY:-Developer ID Application: Nipon Sugsavanvit (V4YMT449CL)}"

./build.sh >/dev/null   # runs every test; stops here if one fails

OUT=build/release
APP="$OUT/KaraokeThai.app"
rm -rf "$OUT"; mkdir -p "$OUT"
cp -R build/ThaiPinyin.app "$APP"
rm -f "$APP/Contents/Resources/personal.js"   # your own words stay on your Mac

# Universal binary.
for arch in arm64 x86_64; do
  swiftc -O -module-name ThaiPinyin -target "$arch-apple-macos13.0" \
    -framework Cocoa -framework InputMethodKit -framework JavaScriptCore \
    Sources/*.swift -o "$OUT/ThaiPinyin-$arch"
done
lipo -create "$OUT/ThaiPinyin-arm64" "$OUT/ThaiPinyin-x86_64" -output "$APP/Contents/MacOS/ThaiPinyin"
rm "$OUT"/ThaiPinyin-*

# Hardened runtime (required for notarization); JavaScriptCore needs the JIT entitlement.
cat > "$OUT/entitlements.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>com.apple.security.cs.allow-jit</key><true/>
</dict></plist>
PLIST
codesign --force --options runtime --timestamp --entitlements "$OUT/entitlements.plist" --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"

ZIP="$OUT/KaraokeThai-mac.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "Signed: $ZIP"
echo "Next: xcrun notarytool submit \"$PWD/$ZIP\" --keychain-profile karaoke-notary --wait && xcrun stapler staple \"$PWD/$APP\""
