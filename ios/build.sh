#!/bin/bash
# Builds the iPhone/iPad keyboard for the simulator, after checking that the Swift engine
# gives exactly the same guesses as the web engine. To put it on your iPhone/iPad, open
# ios/ThaiPinyin.xcodeproj in Xcode afterwards, pick your device and press Run.
set -euo pipefail
cd "$(dirname "$0")"

# Word list: same steps as the Mac build, then the smaller mobile list (iOS caps keyboard memory).
node ../tools/chat_spellings.js
node ../tools/precompute_keys.js
node ../tools/mobile_dict.js 25000 90000 45000 8000

# Swift engine vs web engine on ~4,400 inputs; stops here if any guess differs.
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
node ../tools/ios_parity.js > "$T/expected.json"
swiftc -O ParityTests/main.swift Keyboard/ThaiEngine.swift -o "$T/parity"
"$T/parity" ../web/dict.mobile.txt "$T/expected.json"

xcodegen generate --quiet
xcodebuild -project ThaiPinyin.xcodeproj -scheme ThaiPinyin -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet build
echo "Built: ios/build/Build/Products/Debug-iphonesimulator/ThaiPinyin.app"
