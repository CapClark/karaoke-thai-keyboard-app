# Karaoke Thai Keyboard

Source for the Karaoke Thai Keyboard: the paid [iPhone/iPad app](https://capclark.github.io/karaoke-thai-keyboard/), the free Mac input method and the web page. Data sources are listed in [CREDITS.md](CREDITS.md). The support page and privacy policy are published from the separate repository `CapClark/karaoke-thai-keyboard`, which also hosts the Mac download.

Type Thai by sound, like Chinese pinyin input: `sawatdeekrap` → สวัสดีครับ.

## Mac keyboard (works in every app)

```bash
./mac/build.sh
```

This installs `~/Library/Input Methods/ThaiPinyin.app`. Tap Shift alone or turn on Caps Lock to type English. `-`/`=` page through more guesses, and you can click a guess.

Then System Settings → Keyboard →
Text Input → Input Sources → Edit → `+` → Thai → **Karaoke Thai**. Switch to it from the menu bar
or with Ctrl+Space / Globe. If it doesn't appear, log out and back in.

Re-run `./mac/build.sh` after editing `web/extra.js` or `web/engine.js`.

## iPhone / iPad keyboard

```bash
./ios/build.sh
```

This checks the keyboard's engine against the web engine, then builds it. To put it on your phone or iPad:
1. Open `ios/ThaiPinyin.xcodeproj` in Xcode.
2. Pick your device and press Run (Xcode → Settings → Accounts needs your Apple ID).
3. On the device: Settings → General → Keyboard → Keyboards → Add New Keyboard → **Karaoke Thai**.
4. In any app, hold 🌐 and pick it.

"Allow Full Access" is optional: iOS requires it for the light tap on each key (haptics). The keyboard never connects to the internet either way; nothing leaves the device.

- **Keys:** Space or Return types the first guess, tap any guess, tap the typed letters to keep them as English. **EN** switches to plain English typing (**ไทย** switches back).
- **Physical keyboards:** it works with the on-screen keyboard only. iOS doesn't pass physical-keyboard typing to third-party keyboards.
- **Installing with a free Apple ID:** the app stops opening after 7 days; reinstall from Xcode. A paid developer account lasts a year.

How it differs from the Mac version:
- **Engine:** a Swift port, `ios/Keyboard/ThaiEngine.swift`, instead of running `web/engine.js`. iOS stops keyboards that use more than about 50–70 MB. JavaScriptCore needed about 100 MB for the word list, and runs slower inside a keyboard.
- **Matches the web engine:** `ios/build.sh` checks the Swift engine against the web engine on about 4,400 inputs (`tools/ios_parity.js`, `ios/ParityTests`). The build stops if any guess or its order differs.
- **Word list:** the 25,000 most used words with their word pairs (`tools/mobile_dict.js` → `web/dict.mobile.txt`). Your `web/extra.js` and `web/personal.js` are included.
- **Memory and speed:** about 26 MB in total, under 1 ms per keystroke.
- **Your picks** are remembered on the device, separately from the Mac.

## Web version

```bash
python3 -m http.server 8765 --directory web
```

Open http://localhost:8765.

## Keys

- Letters build the romanized word; the candidate bar shows Thai guesses.
- `Space` / `1` picks the top guess, `2`–`9` pick others, `←` `→` move the highlight.
- `Enter` takes the highlighted guess, `Shift+Enter` keeps the English letters, `Esc` cancels, `Ctrl+Space` toggles English mode.
- Words you pick rank higher next time (stored in the browser).

## How it works

1. **Sound map** (`web/phonemes.js`, explained in [MAPPING.md](MAPPING.md)): every spelling is turned into Thai sounds,
   so `kap` / `krap` / `khrap`, `sawasdee` / `sawatdi`, `khoon` / `khun` all match the same words.
2. **Word list** (`web/dict.js`): 67k Thai words with how often each is used (TNC corpus), each with one or two
   romanizations (PyThaiNLP's neural romanizer, plus a pronunciation model for the top 40k words),
   and 250k common word pairs.
3. **Ranking** (`web/engine.js`): exact sound match, then words you are still typing, letter typos
   (extra letter, swapped letters, neighbouring key), then near-sounding words. Word pairs pick the likely
   meaning (`kin` + `khao` = กินข้าว, not กินเขา) and split whole sentences without spaces.
   Your picks are remembered.
4. **Your fixes** (`web/extra.js`): add `["ไทย", "spelling"]` lines for anything it gets wrong.
5. **Your own words from Wispr Flow** (`web/personal.js`): `tools/.venv/bin/python tools/import_wispr.py` reads the Thai
   you've dictated in Wispr Flow (read-only, on this Mac only), and the words you use rank higher. Names and slang
   missing from the word list get added. Rerun it after more Thai dictation, then `./mac/build.sh`. Delete
   `web/personal.js` to undo.

## Proper nouns

`web/names.js` adds about 2,600 names: nicknames (`may` = เมย์, `golf` = กอล์ฟ), well-known first names, Bangkok areas and
tourist places, all 77 provinces, countries (`japan` = ญี่ปุ่น), and brands and apps (`facebook` = เฟซบุ๊ก).

- **Your own additions:** edit `tools/names_hand.txt` (one line per name: Thai, then the spellings), run
  `tools/.venv/bin/python tools/proper_nouns.py`, then rebuild.
- **Automatic part:** provinces, countries, and the first names and surnames from PyThaiNLP that actually appear in
  the word counts.
- **Ranking:** a name that is already an everyday word keeps its rank and only gains spellings. New names come in at
  a modest rank, so they don't push out common words.

## Word counts: formal and online Thai

Ranking uses how often each word is used, blended from two sources (`tools/build_dict.py`, `CASUAL_WEIGHT` = 0.4 online):

- **Formal written Thai:** the TNC corpus (via PyThaiNLP).
- **Casual online Thai:** counted by `tools/casual_counts.py` from two public datasets in `tools/data/`, both usable commercially:
  - Wisesight social-media posts (CC0), 75% share
  - Wongnai restaurant reviews (LGPL-3.0), 25% share (kept low because it skews toward food words)

  Only word counts are kept.

This fixes the chat words that formal text under-counts: `na` = นะ (not หน้า), `kha` = ค่ะ (not ค่า), `nam` = น้ำ, `ton` = ตอน.

There is no public data pairing casual romanized Thai with the Thai it stands for (checked: Hugging Face, Kaggle, GitHub, papers). Spellings that differ only by tone (`khao` = เขา / เข้า / ข้าว) are decided by the surrounding words and your own picks.

To redo the counts after adding data: `.venv/bin/python casual_counts.py && .venv/bin/python build_dict.py`, then `mac/build.sh`.

## Tests

```bash
node tests/mapping.test.js && node tests/edge.test.js && node tests/accuracy.test.js -v && node tests/roundtrip.test.js 3000
```

`tests/cases.js` has 231 typed spellings (textbook, chat style, typos, phrases). Right now: right word first 89.6%,
in the top 3 98.3%, in the list 99.1%, about 7 ms per keystroke. Most misses are words that differ only in tone
(ข้าว / เขา / เข้า), which Latin letters can't show; word pairs and your picks sort those out.
`tests/roundtrip.test.js` types the spelling of each of the 3,000 most common words (99.9% appear in the first 9 guesses)
and throws 3,000 random inputs at the engine (no errors, under 60 ms each). `mac/Tests/main.swift` presses simulated keys
against the real keyboard code with a fake text field: phrases, picking by number (also AZERTY), paging, Return, Esc,
Delete, Shift tap vs Shift held, Caps Lock, ⌘ shortcuts, Home/F-keys, focus loss, apps that drop or don't show the
underlined text, and the 48-letter limit. `mac/build.sh` runs all of these and won't install if any fail.

## Rebuilding the word list

```bash
cd tools
.venv/bin/python rom_cache.py 60000   # romanize vocabulary (cached)
.venv/bin/python g2p_cache.py 40000   # pronunciations for top words (cached)
.venv/bin/python build_dict.py        # writes web/dict.js
node make_mapping_doc.js              # regenerates MAPPING.md
```
