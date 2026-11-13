# Drafts for 1.0.1 and later (not submitted)

Drafts only. Nothing here has been entered in App Store Connect. The current
listing is in listing.md.

## What's New, 1.0.1 (English, 4000 max)

Better at the way people really spell:
• "ahn" and "aan" for the short ัน sound: gahn = กัน, wahn = วัน
• Short words: ka = แค่, ma = แม่
• "ur" for อือ (kurn = ขึ้น), "e" for เออ (den = เดิน), "ew" for อิว (hew = หิว)
• Food orders come out whole: kaopadkai = ข้าวผัดไก่, kapraomoo = กะเพราหมู
• Questions read right: yuunaika = อยู่ไหนคะ
• Keyboard colours: tap the palette at the right of the bar (Mango, Matcha, Ocean, Lychee)
• New practice screen in the app

## What's New, 1.0.1 (Thai)

พิมพ์ได้ตรงกับที่คนสะกดจริงมากขึ้น:
• "ahn" และ "aan" สำหรับเสียง ัน: gahn = กัน, wahn = วัน
• คำสั้น: ka = แค่, ma = แม่
• "ur" แทน อือ (kurn = ขึ้น), "e" แทน เออ (den = เดิน), "ew" แทน อิว (hew = หิว)
• สั่งอาหารได้ทั้งชื่อ: kaopadkai = ข้าวผัดไก่, kapraomoo = กะเพราหมู
• ประโยคคำถามถูกขึ้น: yuunaika = อยู่ไหนคะ
• เลือกสีแป้นพิมพ์ได้: แตะรูปจานสีด้านขวาของแถบคำ
• หน้าฝึกพิมพ์ใหม่ในแอป

## Promotional text (170 max), English

No rules to learn: spell Thai the way you'd text it. sawatdeekrap → สวัสดีครับ, kaopadkai → ข้าวผัดไก่. Every app, fully offline.

(150 characters)

## Promotional text (Thai)

พิมพ์ไทยด้วยตัวอักษรอังกฤษ สะกดแบบที่คุณแชทได้เลย ไม่ต้องจำกฎ sawatdeekrap → สวัสดีครับ ใช้ได้ทุกแอป ไม่ต้องต่อเน็ต

## Description: new opening paragraph (English)

Most romanized Thai keyboards make you learn their spelling system first: aspirated
consonants this way, vowels that way. Karaoke Thai doesn't. Spell a word the way you
would in a chat (kin or gin, khao or kao or kow, laew or leow or lew) and it finds the
Thai. Type a whole sentence without spaces and it splits it into words for you.

## Thai localization (add Thai as a second language in App Store Connect)

**Name (30 max):** แป้นพิมพ์ไทยคาราโอเกะ
**Subtitle (30 max):** พิมพ์ไทยตามเสียง
**Keywords (100 max):** พิมพ์ไทย,คาราโอเกะ,แป้นพิมพ์,คีย์บอร์ดไทย,ภาษาไทย,ทับศัพท์,พินอิน,thai keyboard,karaoke
**Description:**
พิมพ์ภาษาไทยด้วยตัวอักษรภาษาอังกฤษ แบบคาราโอเกะ พิมพ์ "sawatdeekrap" แล้วเลือก สวัสดีครับ พิมพ์ทั้งประโยคไม่ต้องเว้นวรรค แป้นพิมพ์จะแบ่งคำให้เอง

• สะกดแบบไหนก็ได้: kap, krap, khrap, krub ได้ ครับ ทั้งหมด
• เข้าใจทั้งประโยค: ดูคำรอบข้างเพื่อเลือกคำที่ถูก (kinkhao → กินข้าว ไม่ใช่ กินเขา)
• แก้คำพิมพ์ผิด: สลับตัวอักษร กดพลาด หรือสะกดใกล้เคียงก็ยังเจอคำ
• ชื่อและสถานที่: ชื่อเล่น จังหวัด ประเทศ และแบรนด์
• จำคำที่คุณเลือก: คำที่ใช้บ่อยขึ้นมาก่อน
• เป็นส่วนตัว: ทำงานบนเครื่องทั้งหมด ไม่เชื่อมต่ออินเทอร์เน็ต
• โหมดสว่างและมืด, iPhone และ iPad

เหมาะกับคนไทยในต่างประเทศ คนที่ใช้แป้นอังกฤษคล่องกว่า และคนที่เรียนภาษาไทยที่รู้ว่าคำออกเสียงอย่างไรแต่ยังสะกดไม่ได้

วิธีเปิดใช้: การตั้งค่า → ทั่วไป → แป้นพิมพ์ → แป้นพิมพ์ → เพิ่มแป้นพิมพ์ใหม่ → Karaoke Thai

The Thai text above was written by Claude; have a native speaker read it before use.

## If the free plan is switched on later (Gate.enabled / Store.enabled)

- In-app purchase: non-consumable, ID `com.kenpeeranat.KaraokeThai.unlock`,
  reference name "Unlimited", suggested price ฿149 (tier near $3.99-4.99).
- Description line to add: "Free to try: 7 days unlimited, then 50 Thai words a day.
  Unlock once for no limit. Bought the app before it was free? It's already unlocked."
- App Review note to add: "The unlock is a non-consumable in-app purchase. Restore
  Purchases is on the main screen. Earlier paid downloads are recognised with
  AppTransaction.originalAppVersion."
- Set `firstFreeBuild` in Keyboard/Gate.swift and App/Store.swift to the first free
  build number before that build is uploaded.
