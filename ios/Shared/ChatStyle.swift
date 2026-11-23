import Foundation

/// Chat spellings (ครับ as คับ) and stretched endings (krappp as ครับบบ), applied to the
/// engine's guesses after it has picked the standard words. The word list and the reasons for
/// each choice are in docs/chat-style.md; ChatTests checks every rule.
enum ChatStyle {
    /// The keyboard's own switch (kept in the keyboard's storage, so it needs no Full Access).
    static let key = "chat.style"
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    enum Place {
        case anywhere
        case atEnd       // the guess ends with the word
        case endOfLonger // the guess ends with the word and has something before it
    }

    struct Rule {
        let from: [Unicode.Scalar]
        let to: [Unicode.Scalar]
        let place: Place
        /// Words the rule must leave alone, each with where `from` sits inside it.
        let keep: [(word: [Unicode.Scalar], at: Int)]

        init(_ from: String, _ to: String, _ place: Place = .anywhere, keep: [String] = []) {
            let f = Array(from.unicodeScalars)
            self.from = f
            self.to = Array(to.unicodeScalars)
            self.place = place
            self.keep = keep.compactMap { w in
                let s = Array(w.unicodeScalars)
                guard s.count >= f.count, let at = (0...(s.count - f.count)).first(where: { Array(s[$0..<($0 + f.count)]) == f })
                else { return nil }
                return (s, at)
            }
        }
    }

    /// Longest first, so ถ้าอย่างนั้น is read before อย่างนั้น, and หรือเปล่า before หรือ.
    static let rules: [Rule] = [
        Rule("ครับ", "คับ"),
        Rule("ค่ะ", "ค่า"),
        Rule("จ้ะ", "จ้า"),
        Rule("สวัสดี", "หวัดดี"),
        Rule("ไหม", "มั้ย", keep: ["ผ้าไหม", "ไหมพรม", "เส้นไหม", "ใยไหม", "ตัวไหม", "หนอนไหม", "ร้อยไหม", "ไหมขัดฟัน", "ไหมไทย"]),
        Rule("หรือเปล่า", "รึป่าว"),
        Rule("เปล่า", "ป่าว", .atEnd, keep: ["น้ำเปล่า", "ข้าวเปล่า", "มือเปล่า", "ว่างเปล่า", "เท้าเปล่า", "ตาเปล่า", "ตัวเปล่า", "สูญเปล่า", "เสียเปล่า"]),
        Rule("หรือยัง", "รึยัง"),
        Rule("เหรอ", "หรอ"),
        Rule("หรือ", "หรอ", .endOfLonger),
        Rule("จริง", "จิง"),
        Rule("อะไร", "ไร", .endOfLonger),
        Rule("อย่างไร", "ยังไง"),
        Rule("อย่างนี้", "ยังงี้"),
        Rule("ถ้าอย่างนั้น", "ถ้างั้น"),
        Rule("อย่างนั้น", "ยังงั้น"),
        Rule("ก็", "ก้อ"),
        Rule("เดี๋ยว", "เด๋ว"),
        Rule("เขา", "เค้า", keep: ["ภูเขา", "เขาใหญ่", "เขาค้อ", "เขาหลัก", "เขาสัตว์", "เขาควาย", "เขากวาง", "เชิงเขา", "ยอดเขา",
                                    "ไหล่เขา", "หุบเขา", "เทือกเขา", "ตีนเขา", "บนเขา", "ขึ้นเขา", "ลงเขา"]),
        Rule("เธอ", "เทอ"),
        Rule("ฉัน", "ชั้น", keep: ["ฉันท", "ฉันใด"]),
        Rule("ขอโทษ", "ขอโทด"),
        Rule("โทษที", "โทดที"),
    ].sorted { $0.from.count > $1.from.count }

    /// Tone marks and the vowels written above or below a consonant: a word followed by one
    /// of these is a different word (ไหม้ is not ไหม).
    private static func joins(_ s: Unicode.Scalar) -> Bool {
        s.value == 0x0E31 || (0x0E34...0x0E3A).contains(s.value) || (0x0E47...0x0E4E).contains(s.value)
    }

    private static func matches(_ s: [Unicode.Scalar], _ word: [Unicode.Scalar], at i: Int) -> Bool {
        guard i >= 0, i + word.count <= s.count else { return false }
        for k in 0..<word.count where s[i + k] != word[k] { return false }
        return true
    }

    /// The text in chat spelling. Returns it unchanged when no rule applies.
    static func slang(_ text: String) -> String {
        let s = Array(text.unicodeScalars)
        var out = String.UnicodeScalarView()
        var i = 0
        scan: while i < s.count {
            for r in rules where matches(s, r.from, at: i) {
                let end = i + r.from.count
                if end < s.count && joins(s[end]) { continue }
                switch r.place {
                case .anywhere: break
                case .atEnd: if end != s.count { continue }
                case .endOfLonger: if end != s.count || i == 0 { continue }
                }
                if r.keep.contains(where: { matches(s, $0.word, at: i - $0.at) }) { continue }
                out.append(contentsOf: r.to)
                i = end
                continue scan
            }
            out.append(s[i])
            i += 1
        }
        return String(out)
    }

    /// How many letters to add for a stretched ending: three or more of the same letter at
    /// the end of what was typed ("krappp" adds 2, "deeee" adds 2). Two are left alone, as
    /// English spellings end that way (app, bill, boss). Nil when the ending isn't stretched.
    static func stretch(_ input: String) -> Int? {
        let a = Array(input.lowercased().unicodeScalars)
        guard let last = a.last, ("a"..."z").contains(Character(last)) else { return nil }
        var run = 0
        for c in a.reversed() { if c == last { run += 1 } else { break } }
        guard run >= 3, run < a.count else { return nil }
        // A long vowel is already written with two letters (dee, maa), a final consonant with one.
        let extra = "aeiou".unicodeScalars.contains(last) ? run - 2 : run - 1
        return min(extra, 8)
    }

    /// The text with its last letter repeated. Nil when the last letter can't be repeated
    /// (a tone mark, ์, ็, ำ, ๆ) or isn't Thai.
    static func stretched(_ text: String, by extra: Int) -> String? {
        guard extra > 0, let last = text.unicodeScalars.last, (0x0E01...0x0E44).contains(last.value),
              last.value != 0x0E33, last.value != 0x0E2F, last.value != 0x0E3A else { return nil }
        var out = text.unicodeScalars
        for _ in 0..<extra { out.append(last) }
        return String(out)
    }
}
