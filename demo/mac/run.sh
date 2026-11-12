#!/bin/zsh
# Records the Mac demo: Karaoke Thai typing in TextEdit (demo/public/mac-recording.mp4).
# Needs the input method installed (mac/build.sh) and Accessibility + Screen Recording
# permission for your terminal. Click the TextEdit window when asked; don't touch anything while it types.
set -e
cd "$(dirname "$0")"
mkdir -p build
for t in type win waitfront tis; do swiftc -O $t.swift -o build/$t; done
cp demo.rtf build/rec.rtf
open -a TextEdit build/rec.rtf
sleep 1.5
build/win 244 180 1024 576 >/dev/null
echo "Click the TextEdit window to start."
build/waitfront
sleep 0.8
build/tis com.kenpeeranat.inputmethod.ThaiPinyin >/dev/null
build/win 244 180 1024 576 >/dev/null
sleep 0.5
rm -f build/rec.mov
screencapture -v -x -V 22 -R 244,180,1024,576 build/rec.mov &
REC=$!
sleep 1.5
# Letters at a steady pace; "|" pauses, " " is Space (picks the first guess), "R" is Return.
build/type "sawatdeekrap| R|kinkhaoreuyang| R|khobkhunmakkrap| R|pomrakkun| R||"
wait $REC
build/tis com.apple.keylayout.ABC >/dev/null
ffmpeg -y -loglevel error -i build/rec.mov -t 19 -an -c:v libx264 -crf 18 -pix_fmt yuv420p -movflags +faststart ../public/mac-recording.mp4
echo "Wrote demo/public/mac-recording.mp4"
