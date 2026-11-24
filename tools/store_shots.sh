#!/bin/bash
# Raw App Store screenshots from the Practice screen, free week on, light mode, clean status bar.
#   tools/store_shots.sh SIM_UDID OUTDIR [TEST_RUNNER_DEMO_ROWS=... TEST_RUNNER_DEMO_SPACE=... for iPad]
# iPhone 17 Pro: DRAG1=190 DRAG2=60. iPad Pro 13": DRAG1=0 DRAG2=0 plus the iPad key rows (see DemoUITests).
# Copy raw_1/raw_2 to ios/appstore/shots (iPad: raw_2 as ipad_13_1.png), then run tools/caption_shots.py.

set -u
D=$1; OUT=$2; shift 2; B=com.kenpeeranat.KaraokeThai
mkdir -p "$OUT"; cd "/Users/kenpeeranat/Documents/pinyin for thai/ios"
xcrun simctl boot $D 2>/dev/null; xcrun simctl bootstatus $D -b >/dev/null
xcodebuild -project ThaiPinyin.xcodeproj -scheme ThaiPinyin -sdk iphonesimulator -destination "platform=iOS Simulator,id=$D" -derivedDataPath build CODE_SIGNING_ALLOWED=NO -quiet build 2>&1 | grep -E " error" && exit 1
xcodebuild build-for-testing -project ThaiPinyin.xcodeproj -scheme Demo -destination "platform=iOS Simulator,id=$D" -derivedDataPath build -quiet 2>&1 | grep -E " error" && exit 1
xcrun simctl uninstall $D $B 2>/dev/null
xcrun simctl install $D build/Build/Products/Debug-iphonesimulator/ThaiPinyin.app
xcrun simctl keychain $D reset 2>/dev/null
for k in gate.firstUse gate.lastSeen gate.day gate.count gate.unlocked; do xcrun simctl spawn $D defaults delete com.kenpeeranat.KaraokeThai.Keyboard $k 2>/dev/null; done
xcrun simctl spawn $D defaults write com.kenpeeranat.KaraokeThai.Keyboard chat.style -bool NO
xcrun simctl spawn $D defaults write -g AppleKeyboards -array "com.kenpeeranat.KaraokeThai.Keyboard" "emoji@sw=Emoji"
xcrun simctl ui $D appearance light
OLDLOC=$(xcrun simctl spawn $D defaults read -g AppleLocale 2>/dev/null || echo en_US)
xcrun simctl spawn $D defaults write -g AppleLocale en_US
xcrun simctl spawn $D defaults write -g AppleICUForce12HourTime -bool YES
xcrun simctl shutdown $D; xcrun simctl boot $D; xcrun simctl bootstatus $D -b >/dev/null; sleep 3
xcrun simctl status_bar $D override --time "9:41" --batteryState discharging --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3
launch() { xcrun simctl terminate $D $B 2>/dev/null; xcrun simctl launch $D $B >/dev/null; sleep 4; }
launch; xcrun simctl terminate $D $B
G=$(ls -t "$HOME"/Library/Developer/CoreSimulator/Devices/$D/data/Containers/Shared/AppGroup/*/Library/Preferences/group.com.kenpeeranat.KaraokeThai.plist | head -1)
iso() { date -u -v"$1" "+%Y-%m-%d %H:%M:%S +0000"; }
xcrun simctl spawn $D defaults write "$G" shared.kb.seenAt -date "$(iso -1M)"
xcrun simctl spawn $D defaults write "$G" shared.kb.trialEnds -date "$(iso +6d)"
xcrun simctl spawn $D defaults write "$G" shared.kb.wordsLeft -int -1
xcrun simctl spawn $D defaults write "$G" shared.kb.day "$(date -u +%Y-%m-%d)"
xcrun simctl spawn $D defaults write "$G" shared.usage.words -int 40
EXTRA=("$@" "X_UNUSED=1")
shot1() { local n=$1 p=$2 dr=${3:-0}; set -- "${EXTRA[@]}"; for try in 1 2; do launch
    env TEST_RUNNER_DEMO_APP=$B TEST_RUNNER_DEMO_PHRASES="$p" TEST_RUNNER_DEMO_LEAVE_LAST=1 TEST_RUNNER_DEMO_NO_GAP=1 TEST_RUNNER_DEMO_SHOT="$OUT/$n.png" TEST_RUNNER_DEMO_DRAG=$dr "$@" \
      xcodebuild test-without-building -project ThaiPinyin.xcodeproj -scheme Demo -destination "platform=iOS Simulator,id=$D" -derivedDataPath build -only-testing:DemoUITests/DemoUITests/testDemo 2>&1 | grep -qE "Test Case.*passed" && return
  done; echo "FAILED $n"; }
shot1 raw_1 "${PH1:-sawatdee krap}" ${DRAG1:-184}
shot1 raw_2 "sawatdeekrap kinkhao" ${DRAG2:-60}
xcrun simctl terminate $D $B
xcrun simctl spawn $D defaults write -g AppleLocale $OLDLOC
xcrun simctl spawn $D defaults delete -g AppleICUForce12HourTime
ls -la "$OUT"
