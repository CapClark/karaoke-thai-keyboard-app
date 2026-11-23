# Chat style (slang spellings) and stretched endings

Planned for 1.1.3, iPhone and iPad keyboard. The Mac input method and the web page don't have
it yet.

## What it does

1. **Chat style** (a switch on the keyboard, off by default). The first guess uses the spelling
   people type in chats: `krap` gives คับ, `sawatdeekrap` gives หวัดดีคับ, `jingmai` gives
   จิงมั้ย. The standard spelling is always the next guess, one tap away.
2. **Stretched endings** (always on). Three or more of the same letter at the end stretch the
   Thai: `krappp` gives ครับบบ, `makkk` gives มากกก, `deeee` gives ดีีี. Two letters are left
   alone, because English spellings end that way (app, bill, boss, chill).

## How it works

The engine is not changed. It still picks the standard word, so its sentence reading and its
word-pair context stay as accurate as before. A small layer (`ios/Shared/ChatStyle.swift`)
rewrites the guesses afterwards:

- Each guess keeps its standard text as `base`. The keyboard learns and passes `base` to the
  engine as the previous word, so slang never weakens later guesses.
- A rule never fires inside another word: not when the next letter is a tone mark or an upper
  or lower vowel (ไหม้ is not ไหม), and not inside a listed word (ผ้าไหม, ภูเขา, น้ำเปล่า).
- A stretched ending repeats the last Thai letter. Words that end in a tone mark, ์, ็, ำ or ๆ
  are not stretched.
- The app's practice box accepts either spelling, so practice works with the switch on.

The switch is on the keyboard itself (next to the colours button), not in the app: the app can
only pass settings to the keyboard when Full Access is on.

## Word list

One chat spelling per word: the one seen most in Thai chats, and still polite enough to send
to anyone. "Other spellings" are common too, but they are not typed by the switch (several are
already in the word list under their own sound: `kraab` gives คร้าบ, `pao` gives ป่าว).

| Standard | Chat style | Where | Other spellings (not used) |
|---|---|---|---|
| ครับ | คับ | anywhere | คร้าบ, ครัช, งับ, คัฟ, ฮับ |
| ค่ะ | ค่า | anywhere | คร่า, ค้า, ข่า |
| จ้ะ | จ้า | anywhere | จ้ะะ, จร้า |
| สวัสดี | หวัดดี | anywhere | ดีจ้า, ดีคับ |
| ไหม | มั้ย | anywhere, not ผ้าไหม, ไหมพรม, เส้นไหม, ใยไหม, ตัวไหม, หนอนไหม, ร้อยไหม, ไหมขัดฟัน, ไหมไทย | ป่ะ, ปะ, มะ, ม้าย |
| หรือเปล่า | รึป่าว | anywhere | รึเปล่า, ป่าว, ป่ะ |
| เปล่า | ป่าว | at the end, not น้ำเปล่า, ข้าวเปล่า, มือเปล่า, ว่างเปล่า, เท้าเปล่า, ตาเปล่า, ตัวเปล่า, สูญเปล่า, เสียเปล่า | ปล่าว, เป่า |
| หรือยัง | รึยัง | anywhere | ยัง, ยางง |
| เหรอ | หรอ | anywhere | เหรอออ, หรา, เร้อ |
| หรือ | หรอ | at the end of a longer guess | รึ |
| จริง | จิง | anywhere | จิงๆ, จริงดิ, จิงดิ |
| อะไร | ไร | at the end of a longer guess (ทำอะไร gives ทำไร) | อาราย, อารัย, ไรอะ |
| อย่างไร | ยังไง | anywhere | ไง, ยังงัย |
| อย่างนี้ | ยังงี้ | anywhere | งี้, แบบนี้ |
| อย่างนั้น | ยังงั้น | anywhere | งั้น, แบบนั้น |
| ถ้าอย่างนั้น | ถ้างั้น | anywhere | งั้น |
| ก็ | ก้อ | anywhere | ก่อ, กะ |
| เดี๋ยว | เด๋ว | anywhere | เดี๋ยวว, เดว, เด่ว |
| เขา | เค้า | anywhere, not ภูเขา, เขาใหญ่, เขาค้อ, เขาหลัก, เขาสัตว์, เขาควาย, เขากวาง, เชิงเขา, ยอดเขา, ไหล่เขา, หุบเขา, เทือกเขา, ตีนเขา, บนเขา, ขึ้นเขา, ลงเขา | เค้าา, เขาา |
| เธอ | เทอ | anywhere | เตง, แก |
| ฉัน | ชั้น | anywhere, not ฉันท์, ฉันทะ, ฉันใด | ช้าน, เค้า |
| ขอโทษ | ขอโทด | anywhere | โทดที, ขอโต้ด, sorry |
| โทษที | โทดที | anywhere | โทดน้า |

Left out on purpose:

- **Changes the tone of the message:** สิ to ดิ, แล้ว to ละ, กับ to กะ, ไม่ to มะ.
- **Dated or cutesy:** แร้ว, เรย, คุน, ชิมิ, ป๋ม, ม่าย, ช่าย, อาราย.
- **Lazy typing, not slang:** เปน, รุ้, อยุ่.
- **Couple talk:** ตะเอง, เตง, ที่ร้าก.
- **Rude words:** none.

To change the list, edit `ChatStyle.rules` and the table above together; `ios/ChatTests` checks
every row.

## Checks

- `ios/ChatTests/main.swift`: every rule, every protected word, stretched endings, and that the
  standard spelling is still offered.
- Engine parity (web against Swift) is untouched, since the engine is.
