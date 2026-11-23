// Chat spellings and stretched endings (Shared/ChatStyle.swift). Run:
//   swiftc Shared/ChatStyle.swift ChatTests/main.swift -o /tmp/chattest && /tmp/chattest
import Foundation
var failed = false
func check(_ got: String?, _ want: String?, _ what: String) {
    let ok = got == want
    print(ok ? "ok  " : "FAIL", what, ok ? "" : "got \(got ?? "nil"), want \(want ?? "nil")")
    if !ok { failed = true }
}

// Every row of the table in docs/chat-style.md.
for (std, chat) in [
    ("ครับ", "คับ"), ("ค่ะ", "ค่า"), ("จ้ะ", "จ้า"), ("สวัสดี", "หวัดดี"), ("ไหม", "มั้ย"), ("หรือเปล่า", "รึป่าว"),
    ("เปล่า", "ป่าว"), ("หรือยัง", "รึยัง"), ("เหรอ", "หรอ"), ("จริง", "จิง"), ("อย่างไร", "ยังไง"), ("อย่างนี้", "ยังงี้"),
    ("อย่างนั้น", "ยังงั้น"), ("ถ้าอย่างนั้น", "ถ้างั้น"), ("ก็", "ก้อ"), ("เดี๋ยว", "เด๋ว"), ("เขา", "เค้า"), ("เธอ", "เทอ"),
    ("ฉัน", "ชั้น"), ("ขอโทษ", "ขอโทด"), ("โทษที", "โทดที"),
] { check(ChatStyle.slang(std), chat, "\(std) -> \(chat)") }

// Inside sentences.
for (std, chat) in [
    ("สวัสดีครับ", "หวัดดีคับ"), ("ขอบคุณค่ะ", "ขอบคุณค่า"), ("ไปไหมครับ", "ไปมั้ยคับ"), ("จริงไหม", "จิงมั้ย"),
    ("กินข้าวหรือยัง", "กินข้าวรึยัง"), ("ไปหรือเปล่า", "ไปรึป่าว"), ("ไปเปล่า", "ไปป่าว"), ("ทำอะไร", "ทำไร"),
    ("จริงหรือ", "จิงหรอ"), ("เขาก็ไป", "เค้าก้อไป"), ("เดี๋ยวค่อยคุยกัน", "เด๋วค่อยคุยกัน"), ("ฉันรักเธอ", "ชั้นรักเทอ"),
    ("ทำอย่างไร", "ทำยังไง"), ("ขอโทษครับ", "ขอโทดคับ"), ("สบายดีไหมครับ", "สบายดีมั้ยคับ"), ("จริงๆ", "จิงๆ"),
] { check(ChatStyle.slang(std), chat, "\(std) -> \(chat)") }

// Left alone: other words that only look the same, and words with nothing to change.
for same in ["ผ้าไหม", "ไหมพรม", "ไหม้", "ภูเขา", "ไปเขาใหญ่", "น้ำเปล่า", "ข้าวเปล่า", "มือเปล่า", "ฉันท์", "อะไร", "อะไรนะ",
             "หรือ", "หรือว่า", "เปล่าเลย", "เข้า", "กินข้าว", "ผมรักคุณ", "อร่อยมาก", "โทษ", "ลงโทษ", "ใหม่", "ไม่"] {
    check(ChatStyle.slang(same), same, "\(same) stays")
}

// Stretched endings.
for (typed, extra) in [("krappp", 2), ("makkk", 2), ("makkkk", 3), ("deee", 1), ("deeee", 2), ("maaa", 1), ("loeiii", 1)] {
    check(ChatStyle.stretch(typed).map(String.init), String(extra), "\(typed) adds \(extra)")
}
for typed in ["krap", "krapp", "app", "bill", "boss", "dee", "maa", "kkk", "aaa", "", "sawatdee"] {
    check(ChatStyle.stretch(typed).map(String.init), nil, "\(typed.isEmpty ? "(empty)" : typed) is not stretched")
}
check(ChatStyle.stretch(String(repeating: "k", count: 30) + "a" + String(repeating: "k", count: 30)).map(String.init), "8", "at most 8 added")
check(ChatStyle.stretched("ครับ", by: 2), "ครับบบ", "ครับ + 2")
check(ChatStyle.stretched("มาก", by: 2), "มากกก", "มาก + 2")
check(ChatStyle.stretched("ดี", by: 2), "ดีีี", "ดี + 2")
check(ChatStyle.stretched("มา", by: 1), "มาา", "มา + 1")
check(ChatStyle.stretched("นะ", by: 2), "นะะะ", "นะ + 2")
check(ChatStyle.stretched("คับ", by: 2), "คับบบ", "คับ + 2")
for no in ["ไม่", "ได้", "น้ำ", "สัตว์", "ก็", "จริงๆ", "ok", ""] { check(ChatStyle.stretched(no, by: 2), nil, "\(no.isEmpty ? "(empty)" : no) can't be stretched") }
check(ChatStyle.stretched("ครับ", by: 0), nil, "nothing to add")
exit(failed ? 1 : 0)
