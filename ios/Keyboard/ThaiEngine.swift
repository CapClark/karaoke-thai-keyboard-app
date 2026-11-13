import Foundation

/// Native port of the matching engine (web/phonemes.js + web/engine.js) for the iPhone/iPad
/// keyboard. iOS caps keyboard memory far below what JavaScriptCore needs for the word
/// list, and runs it without its JIT, so the keyboard uses this instead. The rules,
/// costs and ordering are the same line for line; tools/ios_parity.js + ios/ParityTests
/// check that both engines return the same guesses for thousands of inputs.
/// Not thread-safe: use from one queue.
final class ThaiEngine {
    struct Tok { let key: String; let full: String }
    struct Result { let text: String; let consume: Int; let kind: String; let tier: Int; let cost: Double }

    // MARK: - Sound map (phonemes.js)

    private static func b(_ s: String) -> [UInt8] { Array(s.utf8) }
    private static let vowelLetters: Set<UInt8> = Set("aeiou".utf8)
    private static let vowelTokens: Set<UInt8> = Set("aiuvexoq".utf8)

    // [spelling, tokens, close]: longest first; `close` = only when no vowel letter follows.
    private static let VOWELS: [([UInt8], [UInt8], Bool)] = ([
        ("uea", "va", false), ("eua", "va", false), ("uear", "va", true), ("uer", "va", true),
        ("oei", "qy", false), ("oey", "qy", true), ("euy", "qy", true), ("oeuy", "qy", true), ("eoi", "qy", false),
        ("aew", "xw", true), ("aeo", "xw", false), ("eaw", "xw", true), ("aeu", "xw", false),
        ("iew", "iaw", true), ("iao", "iaw", false), ("eao", "iaw", false), ("eiw", "iaw", true), ("eow", "iaw", true),
        ("uay", "uay", true), ("uai", "uay", false), ("oay", "uay", true),
        ("ooi", "uy", false), ("ooy", "uy", true), ("uei", "vay", false),
        ("ae", "x", false), ("air", "x", true), ("ea", "ia", false),
        ("ee", "i", false), ("ii", "i", false), ("ie", "ia", false), ("ia", "ia", false), ("ear", "ia", true),
        ("oo", "u", false), ("ou", "u", false), ("uu", "u", false),
        ("ue", "v", false), ("eu", "v", false), ("ui", "uy", false),
        ("oe", "q", false), ("er", "q", true), ("ur", "q", true), ("eur", "q", true),
        ("or", "o", true), ("oh", "o", true), ("aw", "aw", true), ("ow", "aw", true),
        ("ao", "aw", false), ("au", "aw", false), ("ai", "ay", false),
        ("aa", "a", false), ("ah", "a", true), ("ar", "a", true), ("eh", "e", true),
        ("a", "a", false), ("e", "e", false), ("i", "i", false), ("o", "o", false), ("u", "u", false),
    ] as [(String, String, Bool)]).map { (b($0.0), b($0.1), $0.2) }

    // [spelling, initial tokens, final token, only at word start / after a consonant]
    private static let CONSONANTS: [([UInt8], [UInt8], [UInt8], Bool)] = ([
        ("ngh", "G", "g", false), ("ng", "G", "g", false),
        ("mh", "M", "m", true), ("nh", "N", "n", true), ("lh", "R", "n", true), ("rh", "R", "n", true),
        ("wh", "W", "w", true), ("yh", "Y", "y", true),
        ("kh", "K", "k", false), ("gh", "K", "k", false), ("ck", "K", "k", false), ("gk", "K", "k", false), ("qu", "KW", "k", false),
        ("ph", "P", "p", false), ("bh", "P", "p", false), ("bp", "P", "p", false),
        ("th", "T", "t", false), ("dh", "T", "t", false), ("dt", "T", "t", false),
        ("ch", "J", "t", false), ("sh", "J", "t", false), ("tch", "J", "t", false), ("ts", "J", "t", false),
        ("k", "K", "k", false), ("g", "K", "k", false), ("q", "K", "k", false), ("x", "S", "k", false),
        ("j", "J", "t", false), ("z", "S", "t", false), ("s", "S", "t", false),
        ("d", "D", "t", false), ("t", "T", "t", false),
        ("b", "B", "p", false), ("p", "P", "p", false), ("f", "F", "p", false), ("v", "W", "p", false),
        ("n", "N", "n", false), ("m", "M", "m", false), ("l", "R", "n", false), ("r", "R", "n", false),
        ("y", "Y", "y", false), ("w", "W", "w", false), ("h", "H", "", false),
        ("c", "K", "k", false),
    ] as [(String, String, String, Bool)]).map { (b($0.0), b($0.1), b($0.2), $0.3) }

    private static let doubledFinal: Set<UInt8> = Set("bcdfghjklmnpqrstvwxz".utf8)
    private static let vowelOrY: Set<UInt8> = Set("aeiouy".utf8)
    private static let clusterHeads: Set<UInt8> = Set("KPTBFD".utf8)
    private static let mergePairs: Set<[UInt8]> = Set(["kK", "tT", "pP", "nN", "mM", "gG", "tD", "pB"].map { Array($0.utf8) })

    /// Lowercase a-z only (what every entry point does first).
    static func letters(_ input: String) -> [UInt8] {
        var s: [UInt8] = []
        s.reserveCapacity(input.utf8.count)
        for var c in input.utf8 {
            if c >= 65 && c <= 90 { c += 32 }
            if c >= 97 && c <= 122 { s.append(c) }
        }
        return s
    }

    /// Runs of 3+ of the same letter -> `keep` copies (2 in tokenize, 1 for "unstretched").
    private static func collapseRuns(_ s: [UInt8], keep: Int) -> [UInt8] {
        var t: [UInt8] = []
        t.reserveCapacity(s.count)
        var i = 0
        while i < s.count {
            var j = i
            while j < s.count && s[j] == s[i] { j += 1 }
            let run = j - i
            if run >= 3 { for _ in 0..<keep { t.append(s[i]) } } else { for _ in 0..<run { t.append(s[i]) } }
            i = j
        }
        return t
    }

    static func tokenize(_ input: String) -> Tok { tokenize(bytes: letters(input)) }

    static func tokenize(bytes raw: [UInt8]) -> Tok {
        let t = collapseRuns(raw, keep: 2)
        // A doubled final letter ("bill", "kiss") is one letter.
        var s: [UInt8] = []
        s.reserveCapacity(t.count)
        var i = 0
        while i < t.count {
            if i + 1 < t.count, t[i] == t[i + 1], doubledFinal.contains(t[i]), !(i + 2 < t.count && vowelOrY.contains(t[i + 2])) {
                s.append(t[i]); i += 2
            } else {
                s.append(t[i]); i += 1
            }
        }
        let n = s.count
        func isV(_ k: Int) -> Bool { k >= 0 && k < n && vowelLetters.contains(s[k]) }
        func starts(_ sp: [UInt8], _ at: Int) -> Bool {
            if at + sp.count > n { return false }
            for q in 0..<sp.count where s[at + q] != sp[q] { return false }
            return true
        }
        var out: [UInt8] = []
        out.reserveCapacity(n + 4)
        i = 0
        while i < n {
            if isV(i) {
                var len = 1
                var tok: [UInt8] = [s[i]]
                for (sp, tk, close) in VOWELS {
                    if !starts(sp, i) { continue }
                    if close && isV(i + sp.count) { continue }
                    len = sp.count; tok = tk
                    break
                }
                i += len
                // A trailing glide (ai, ao, oi, iu, eo...) when nothing vowel-like follows.
                if let last = tok.last, vowelTokens.contains(last), !isV(i + 1) {
                    if i < n && s[i] == UInt8(ascii: "i") && tok != [UInt8(ascii: "i")] { tok.append(UInt8(ascii: "y")); i += 1 }
                    else if i < n && (s[i] == UInt8(ascii: "o") || s[i] == UInt8(ascii: "u"))
                                && tok != [UInt8(ascii: "u")] && tok != [UInt8(ascii: "o")] { tok.append(UInt8(ascii: "w")); i += 1 }
                }
                out += tok
                continue
            }
            var sp: [UInt8] = [s[i]], ini: [UInt8] = [], fin: [UInt8] = []
            for (cs, it, ft, start) in CONSONANTS {
                if start && i > 0 && isV(i - 1) { continue }
                if starts(cs, i) { sp = cs; ini = it; fin = ft; break }
            }
            if sp == [UInt8(ascii: "c")], i + 1 < n, "eiy".utf8.contains(s[i + 1]) { ini = [UInt8(ascii: "S")] }
            let nextIdx = i + sp.count
            let next: UInt8? = nextIdx < n ? s[nextIdx] : nil
            let lastIsVowel = out.last.map { vowelTokens.contains($0) } ?? false
            let isFinal = lastIsVowel && !(next.map { vowelLetters.contains($0) } ?? false)
            if isFinal {
                // "rn"/"rl"/"r" at the end ("karn" การ) just lengthen the vowel.
                if sp == [UInt8(ascii: "r")] && (next == UInt8(ascii: "n") || next == UInt8(ascii: "l") || next == nil) { fin = [] }
                if let f = fin.first, out.last != f { out.append(f) }
            } else {
                out += ini
            }
            i += sp.count
        }
        let full = String(decoding: out, as: UTF8.self)
        // Drop R after a cluster head (krap -> kap).
        var k1: [UInt8] = []
        k1.reserveCapacity(out.count)
        i = 0
        while i < out.count {
            if i + 2 < out.count, clusterHeads.contains(out[i]), out[i + 1] == UInt8(ascii: "R"), vowelTokens.contains(out[i + 2]) {
                k1.append(out[i]); i += 2
            } else { k1.append(out[i]); i += 1 }
        }
        // A final followed by the same sound starting the next syllable is heard once.
        var k2: [UInt8] = []
        k2.reserveCapacity(k1.count)
        i = 0
        while i < k1.count {
            if i + 1 < k1.count, mergePairs.contains([k1[i], k1[i + 1]]) { k2.append(k1[i + 1]); i += 2 }
            else { k2.append(k1[i]); i += 1 }
        }
        return Tok(key: String(decoding: k2, as: UTF8.self), full: full)
    }

    /// While typing, the last consonant might start the next syllable ("kin" -> "kina").
    static func openKeys(_ raw: [UInt8]) -> (String, String?) {
        let a = tokenize(bytes: raw).key
        var b = tokenize(bytes: raw + [UInt8(ascii: "a")]).key
        if b.hasSuffix("a") { b.removeLast() }
        return a == b ? (a, nil) : (a, b)
    }

    private static let SUB: [UInt16: Double] = {
        let near: [(String, Double)] = [
            ("ex", 0.35), ("ia", 0.9), ("vu", 0.45), ("oq", 0.55), ("eq", 0.55), ("vq", 0.55),
            ("au", 0.6), ("ao", 0.7), ("ie", 0.6), ("iv", 0.6), ("ou", 0.6),
            ("DT", 0.5), ("BP", 0.5), ("FP", 0.6), ("SJ", 0.6), ("JY", 0.7), ("KG", 0.7),
            ("NR", 0.8), ("MN", 0.8),
            ("kt", 0.55), ("tp", 0.55), ("kp", 0.6), ("ng", 0.45), ("nm", 0.6), ("gm", 0.7), ("wy", 0.8),
        ]
        var m: [UInt16: Double] = [:]
        for (p, c) in near {
            let u = Array(p.utf8)
            m[UInt16(u[0]) << 8 | UInt16(u[1])] = c
            m[UInt16(u[1]) << 8 | UInt16(u[0])] = c
        }
        return m
    }()
    @inline(__always) static func subCost(_ a: UInt8, _ b: UInt8) -> Double {
        a == b ? 0 : (SUB[UInt16(a) << 8 | UInt16(b)] ?? 1)
    }
    @inline(__always) static func indelCost(_ t: UInt8) -> Double {
        switch t {
        case UInt8(ascii: "H"): return 0.4
        case UInt8(ascii: "R"), UInt8(ascii: "W"): return 0.5
        case UInt8(ascii: "k"), UInt8(ascii: "t"), UInt8(ascii: "p"), UInt8(ascii: "n"),
             UInt8(ascii: "m"), UInt8(ascii: "g"), UInt8(ascii: "w"), UInt8(ascii: "y"): return 0.6
        default: return 1
        }
    }

    // MARK: - Data

    private var words: [String] = []
    private var freq: [Double] = []
    private var spell: [String] = [] // all spellings of a word, joined with "|"
    private var byKey: [String: [Int32]] = [:] // sound key -> word ids, most likely first
    private var wordId: [Exact: Int32] = [:] // exact text: Swift would treat differently-ordered tone marks as equal
    private var phraseIds = Set<Int32>() // multi-word phrases
    private var phraseLast: [Int32: Int32] = [:] // phrase -> its last word
    private var personal: [Exact: Double] = [:] // your own words (Wispr import)
    private var total: Double = 1
    private var biKeys: [UInt64] = [], biCounts: [UInt32] = []
    private var triKeys: [UInt64] = [], triCounts: [UInt32] = []
    private var sortedKeys: [String] = []
    // Near-sound index: every key with one sound removed -> the keys (sorted, by index).
    private var delKeys: [String] = [], delVals: [Int32] = []
    private var buckets: [UInt8: [[Int32]]] = [:] // first sound -> length -> keys
    private var notId = -2, inId = -2
    // Polite endings: ใน ("in") is never right before one (yuunaika = อยู่ไหนคะ, not อยู่ในคะ).
    private static let POLITE = ["ครับ", "ค่ะ", "คะ", "นะ", "จ้ะ", "จ้า", "นะคะ", "นะครับ"]
    private var politeIds = Set<Int>()
    private var enderIds = Set<Int>()
    private static let B: UInt64 = 131072
    private static let REPEAT = -1 // stands for ๆ
    private static let ENDERS = ["ครับ", "ค่ะ", "คะ", "นะ", "ไหม", "มั้ย", "เหรอ", "หรอ", "จ้า", "จ้ะ", "นะคะ", "นะครับ",
        "เลย", "ด้วย", "กัน", "แล้ว", "หรือเปล่า", "รึเปล่า", "เปล่า", "ป่ะ", "สิ", "ล่ะ", "แหละ", "เนอะ", "อะ", "อ่ะ", "ยัง", "บ้าง"]

    // Words you picked: same format as the web page and the Mac keyboard.
    private var learnedU: [String: Double] = [:]
    private var learnedB: [String: Double] = [:]
    private static let maxLearned = 4000

    private let rowBuf = UnsafeMutablePointer<Float>.allocate(capacity: 3 * 96)
    deinit { rowBuf.deallocate() }

    var size: Int { words.count }

    // MARK: load

    /// Reads web/dict.mobile.txt (tools/mobile_dict.js): one entry per line, tab-separated.
    ///   W word spellings count keys   P phrase spelling count lastword key
    ///   B a b count   T a b c count   E word spelling (web/extra.js)
    ///   N name spellings rank (web/names.js)   M word count spelling (web/personal.js)
    func load(contentsOf url: URL, learned: Data? = nil) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        if let learned, let obj = (try? JSONSerialization.jsonObject(with: learned)) as? [String: Any] {
            learnedU = (obj["u"] as? [String: Double]) ?? [:]
            learnedB = (obj["b"] as? [String: Double]) ?? [:]
        }
        var extra: [(String, String)] = []
        var mine: [(String, Double, String)] = []
        var named: [(String, String, Double)] = []
        var bi: [(UInt64, UInt32)] = [], tri: [(UInt64, UInt32)] = []
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            let p = raw.bindMemory(to: UInt8.self)
            var start = 0
            while start < p.count {
                var end = start
                while end < p.count && p[end] != 10 { end += 1 }
                defer { start = end + 1 }
                if end - start < 2 { continue }
                let tag = p[start]
                if tag == UInt8(ascii: "B") || tag == UInt8(ascii: "T") {
                    // Numbers only: parse without making strings.
                    var nums: [UInt64] = []
                    var v: UInt64 = 0, inNum = false
                    for q in (start + 2)..<end {
                        let c = p[q]
                        if c >= 48 && c <= 57 { v = v * 10 + UInt64(c - 48); inNum = true }
                        else if inNum { nums.append(v); v = 0; inNum = false }
                    }
                    if inNum { nums.append(v) }
                    if tag == UInt8(ascii: "B"), nums.count == 3 { bi.append((nums[0] * Self.B + nums[1], UInt32(nums[2]))) }
                    if tag == UInt8(ascii: "T"), nums.count == 4 { tri.append(((nums[0] * Self.B + nums[1]) * Self.B + nums[2], UInt32(nums[3]))) }
                    continue
                }
                let line = String(decoding: UnsafeBufferPointer(rebasing: p[(start + 2)..<end]), as: UTF8.self)
                let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
                func at(_ i: Int) -> String { i < f.count ? f[i] : "" }
                switch tag {
                case UInt8(ascii: "W"):
                    addWord(at(0), at(1).split(separator: "|", omittingEmptySubsequences: false).map(String.init), Double(at(2)) ?? 0,
                            at(3).split(separator: "|", omittingEmptySubsequences: false).map(String.init))
                case UInt8(ascii: "P"):
                    let t = at(0)
                    if wordId[Exact(t)] != nil { continue }
                    addWord(t, [at(1)], Double(at(2)) ?? 0, [at(4)])
                    if let id = wordId[Exact(t)] {
                        phraseIds.insert(id)
                        if let lid = wordId[Exact(at(3))] { phraseLast[id] = lid }
                    }
                case UInt8(ascii: "E"): extra.append((at(0), at(1)))
                case UInt8(ascii: "N"): named.append((at(0), at(1), Double(at(2)) ?? 100))
                case UInt8(ascii: "M"): mine.append((at(0), Double(at(1)) ?? 0, at(2)))
                default: break
                }
            }
        }
        for (w, c, _) in mine { personal[Exact(w), default: 0] += c }
        bi.sort { $0.0 < $1.0 }
        tri.sort { $0.0 < $1.0 }
        biKeys = bi.map(\.0); biCounts = bi.map(\.1)
        triKeys = tri.map(\.0); triCounts = tri.map(\.1)
        for (w, r) in extra {
            let id = wordId[Exact(w)]
            addWord(w, [r], id == nil ? 2000 : max(freq[Int(id!)], 2000), nil)
        }
        // Proper nouns: an existing word keeps its rank and gains the spellings.
        for (w, rs, f) in named {
            let id = wordId[Exact(w)]
            addWord(w, rs.split(separator: "|", omittingEmptySubsequences: false).map(String.init), id == nil ? f : freq[Int(id!)], nil)
        }
        // Your own words (names, slang) that the word list lacks.
        for (w, _, r) in mine where !r.isEmpty && wordId[Exact(w)] == nil { addWord(w, [r], 500, nil) }
        notId = wordId[Exact("ไม่")].map(Int.init) ?? -2
        inId = wordId[Exact("ใน")].map(Int.init) ?? -2
        politeIds = Set(Self.POLITE.compactMap { wordId[Exact($0)].map(Int.init) })
        enderIds = Set(Self.ENDERS.compactMap { wordId[Exact($0)].map(Int.init) })
        total = freq.reduce(0, +) + Double(words.count)
        let u = (0..<words.count).map(uni)
        for (k, list) in byKey where list.count > 1 {
            byKey[k] = list.stableSorted { u[Int($0)] > u[Int($1)] }
        }
        sortedKeys = byKey.keys.sorted()
        buildIndex()
    }

    private func addWord(_ w: String, _ roms: [String], _ f: Double, _ keys: [String]?) {
        let id: Int
        if let e = wordId[Exact(w)] {
            id = Int(e)
            if f > freq[id] { freq[id] = f }
        } else {
            id = words.count
            words.append(w); freq.append(f); spell.append("")
            wordId[Exact(w)] = Int32(id)
        }
        for (q, r) in roms.enumerated() {
            let key = keys.map { q < $0.count ? $0[q] : "" } ?? tok(r).key
            if key.isEmpty { continue }
            if !("|" + spell[id] + "|").contains("|" + r + "|") { spell[id] = spell[id].isEmpty ? r : spell[id] + "|" + r }
            if byKey[key]?.contains(Int32(id)) != true { byKey[key, default: []].append(Int32(id)) }
        }
    }

    private func buildIndex() {
        var pairs: [(String, Int32)] = []
        var bk: [UInt8: [[Int32]]] = [:]
        for (ki, k) in sortedKeys.enumerated() {
            if idsOf(k).allSatisfy({ phraseIds.contains($0) }) { continue }
            let kb = Array(k.utf8)
            // Keys of 3+ sounds only: shorter ones never need the index.
            if kb.count >= 3 && kb.count <= 16 {
                for i in 0..<kb.count {
                    var d = kb
                    d.remove(at: i)
                    pairs.append((String(decoding: d, as: UTF8.self), Int32(ki)))
                }
            }
            var byLen = bk[kb[0]] ?? []
            while byLen.count <= kb.count { byLen.append([]) }
            byLen[kb.count].append(Int32(ki))
            bk[kb[0]] = byLen
        }
        pairs.sort { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
        delKeys.removeAll(); delVals.removeAll()
        delKeys.reserveCapacity(pairs.count); delVals.reserveCapacity(pairs.count)
        for (d, v) in pairs where !(delKeys.last == d && delVals.last == v) { delKeys.append(d); delVals.append(v) }
        buckets = bk
    }

    // MARK: - Scoring

    private func boost(_ id: Int) -> Double {
        let w = words[id]
        return min(learnedU[w] ?? 0, 10) * 0.8 + log1p(personal[Exact(w)] ?? 0) * 0.6
    }
    private func uni(_ id: Int) -> Double { log(freq[id] + 1) + boost(id) * 3 }

    private static func lookup(_ keys: [UInt64], _ counts: [UInt32], _ k: UInt64) -> UInt32 {
        var lo = 0, hi = keys.count - 1
        while lo <= hi {
            let m = (lo + hi) >> 1
            let v = keys[m]
            if v == k { return counts[m] }
            if v < k { lo = m + 1 } else { hi = m - 1 }
        }
        return 0
    }
    private func bigramCount(_ a: Int, _ b: Int) -> Double {
        guard a >= 0, b >= 0, UInt64(a) < Self.B, UInt64(b) < Self.B else { return 0 }
        return Double(Self.lookup(biKeys, biCounts, UInt64(a) * Self.B + UInt64(b)))
    }
    private func trigramCount(_ a: Int, _ b: Int, _ c: Int) -> Double {
        guard a >= 0, b >= 0, c >= 0, UInt64(a) < Self.B, UInt64(b) < Self.B, UInt64(c) < Self.B else { return 0 }
        return Double(Self.lookup(triKeys, triCounts, (UInt64(a) * Self.B + UInt64(b)) * Self.B + UInt64(c)))
    }

    /// -log P(word | previous words), +1 per word so fewer, longer words win.
    private func wcost(_ prev0: Int?, _ id: Int, _ prev20: Int?) -> Double {
        var prev = prev0, prev2 = prev20
        if let p = prev, phraseIds.contains(Int32(p)) { prev = phraseLast[Int32(p)].map(Int.init); prev2 = nil }
        let pu = ((freq[id] + 1) / total) * exp(boost(id))
        var p = pu
        if let pv = prev {
            let c = bigramCount(pv, id)
            let l = learnedB[words[pv] + "\t" + words[id]] ?? 0
            p = 0.35 * pu + 0.65 * (c / (freq[pv] + 1)) + (l != 0 ? 0.05 * l : 0)
            if let p2 = prev2 {
                let c3 = trigramCount(p2, pv, id)
                let c2 = bigramCount(p2, pv)
                if c3 != 0 && c2 != 0 { p = 0.6 * p + 0.4 * min(1, c3 / c2) }
            }
        }
        return -log(min(p, 1)) + 1
    }

    // MARK: - Lookups

    private var tokCache: [String: Tok] = [:]
    private func tok(_ s: String) -> Tok {
        if let t = tokCache[s] { return t }
        let t = Self.tokenize(s)
        if tokCache.count > 8000 { tokCache.removeAll() }
        tokCache[s] = t
        return t
    }

    private func idsOf(_ k: String) -> [Int32] { byKey[k] ?? [] }

    private func hasFull(_ id: Int, _ full: String) -> Bool {
        for r in spell[id].split(separator: "|", omittingEmptySubsequences: false) where tok(String(r)).full == full { return true }
        return false
    }

    private func keysWithPrefix(_ p: String, _ max: Int = 300) -> [String] {
        var lo = 0, hi = sortedKeys.count
        while lo < hi {
            let m = (lo + hi) >> 1
            if sortedKeys[m] < p { lo = m + 1 } else { hi = m }
        }
        var out: [String] = []
        var i = lo
        while i < sortedKeys.count && out.count < max {
            if !sortedKeys[i].hasPrefix(p) { break }
            out.append(sortedKeys[i]); i += 1
        }
        return out
    }

    /// Weighted edit distance between sound keys (with swaps). Rows are 32-bit floats, as in
    /// the web engine, so both round the same way. prefix: best match against any start of b.
    private func dist(_ a: [UInt8], _ b: [UInt8], _ budget: Double, _ prefix: Bool) -> Double {
        let n = a.count, m = b.count
        if m + 1 > 96 { return .infinity }
        var p2 = rowBuf, pv = rowBuf + 96, cu = rowBuf + 192
        pv[0] = 0
        if m >= 1 { for j in 1...m { pv[j] = Float(Double(pv[j - 1]) + Self.indelCost(b[j - 1])) } }
        if n >= 1 {
            for i in 1...n {
                cu[0] = Float(Double(pv[0]) + Self.indelCost(a[i - 1]))
                var rowMin = Double(cu[0])
                if m >= 1 {
                    for j in 1...m {
                        var v = min(Double(pv[j]) + Self.indelCost(a[i - 1]),
                                    Double(cu[j - 1]) + Self.indelCost(b[j - 1]),
                                    Double(pv[j - 1]) + Self.subCost(a[i - 1], b[j - 1]))
                        if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1] { v = min(v, Double(p2[j - 2]) + 0.7) }
                        cu[j] = Float(v)
                        if v < rowMin { rowMin = v }
                    }
                }
                if rowMin > budget { return .infinity }
                let spare = p2; p2 = pv; pv = cu; cu = spare
            }
        }
        if !prefix { return Double(pv[m]) }
        var best = Double.infinity
        var j = max(0, n - 1)
        while j <= m { best = min(best, Double(pv[j])); j += 1 }
        return best
    }

    /// Keys within `budget` of `key`: one-sound edits via the index, plus a small scan.
    private func fuzzy(_ key: String, _ budget: Double, _ prefix: Bool, _ max: Int = 40) -> [(String, Double)] {
        let kb = Array(key.utf8), n = kb.count
        var found: [String: Double] = [:]
        var order: [String] = []
        func tryKey(_ k: String) {
            if k == key || found[k] != nil || byKey[k] == nil { return }
            let d = dist(kb, Array(k.utf8), budget, prefix)
            if d <= budget { found[k] = d; order.append(k) }
        }
        func probe(_ d: String) {
            var lo = 0, hi = delKeys.count
            while lo < hi {
                let m = (lo + hi) >> 1
                if delKeys[m] < d { lo = m + 1 } else { hi = m }
            }
            while lo < delKeys.count && delKeys[lo] == d { tryKey(sortedKeys[Int(delVals[lo])]); lo += 1 }
        }
        tryKey(key)
        probe(key)
        for i in 0..<n {
            var d = kb
            d.remove(at: i)
            let ds = String(decoding: d, as: UTF8.self)
            tryKey(ds)
            probe(ds)
        }
        if n > 0, let byLen = buckets[kb[0]] {
            if prefix {
                let head = String(decoding: kb.prefix(2), as: UTF8.self)
                var len = n + 1
                while len <= n + 6 && len < byLen.count {
                    for ki in byLen[len] where sortedKeys[Int(ki)].hasPrefix(head) { tryKey(sortedKeys[Int(ki)]) }
                    len += 1
                }
            } else if n >= 6 && budget >= 1 {
                var len = n - 1
                while len <= n + 1 && len < byLen.count {
                    for ki in byLen[len] { tryKey(sortedKeys[Int(ki)]) }
                    len += 1
                }
            }
        }
        return Array(order.map { ($0, found[$0]!) }.stableSorted { $0.1 < $1.1 }.prefix(max))
    }

    // MARK: - Phrase splitting

    private static let BEAM = 8
    private static let FLUENT = 2.5

    private static func startsWithHo(_ w: String) -> Bool {
        let s = Array(w.unicodeScalars)
        var i = 0
        if let f = s.first, "เแโใไ".unicodeScalars.contains(f) { i = 1 }
        return i < s.count && s[i] == "ห"
    }
    // "ahn" / "aan" written out: the short sound of ัน (gahn = กัน), ahead of the long า words.
    private static let SHORT_A_BONUS = 2.5
    private static func shortA(_ s: [UInt8]) -> Bool {
        if s.count < 3 { return false }
        for i in 0..<(s.count - 2) where s[i] == 97 && (s[i + 1] == 97 || s[i + 1] == 104) && s[i + 2] == 110 { return true }
        return false
    }
    private static func shortAWord(_ w: String) -> Bool {
        var after = false
        for u in w.unicodeScalars {
            if after && "นณญลฬร".unicodeScalars.contains(u) { return true }
            after = u == "\u{0E31}"
        }
        return false
    }
    private static func hMarked(_ s: [UInt8]) -> Bool {
        for p in ["mh", "nh", "lh", "rh", "wh", "yh", "ngh"] where s.starts(with: p.utf8) { return true }
        return false
    }

    /// English-style "u" for the short a sound (krung = ครั้ง): every combination, at most 3 u's.
    private static func uAsA(_ c: [UInt8]) -> [[UInt8]] {
        let vowels: Set<UInt8> = Set("aeiou".utf8), vowelsY: Set<UInt8> = Set("aeiouy".utf8)
        var spots: [Int] = []
        var i = 0
        while i + 2 < c.count && spots.count < 3 {
            if !vowels.contains(c[i]) && c[i + 1] == UInt8(ascii: "u") && !vowelsY.contains(c[i + 2]) { spots.append(i + 1); i += 2 }
            else { i += 1 }
        }
        var out: [[UInt8]] = []
        if spots.isEmpty { return out }
        for mask in 1..<(1 << spots.count) {
            var s = c
            for (b, p) in spots.enumerated() where mask & (1 << b) != 0 { s[p] = UInt8(ascii: "a") }
            out.append(s)
        }
        return out
    }

    /// Vowel spellings that say a different Thai vowel than the letters suggest: a or e for แ
    /// (gang = แกง), eo/eaw for เอียว (teo = เที่ยว), ey for เอย (ley = เลย), u for อึ อื (ru = หรือ).
    /// Returns (sound key, cost) for each single change.
    private static func habitVariants(_ key: String) -> [(String, Double)] {
        let k = Array(key.utf8)
        var out: [(String, Double)] = []
        if k.count > 16 { return out }
        func add(_ i: Int, _ n: Int, _ to: String, _ c: Double) {
            out.append((String(decoding: Array(k[0..<i]) + Array(to.utf8) + Array(k[(i + n)...]), as: UTF8.self), c))
        }
        let A = UInt8(ascii: "a"), E = UInt8(ascii: "e"), X = UInt8(ascii: "x"), U = UInt8(ascii: "u")
        let W = UInt8(ascii: "w"), Y = UInt8(ascii: "y"), I = UInt8(ascii: "i"), V = UInt8(ascii: "v"), Q = UInt8(ascii: "q")
        for i in 0..<k.count {
            let ch = k[i]
            let before: UInt8 = i > 0 ? k[i - 1] : 0, next: UInt8 = i + 1 < k.count ? k[i + 1] : 0
            let inPair = before == I || before == U || before == V // ia, ua, uea
            if ch == A && !inPair && next != Y { add(i, 1, "x", k.count <= 2 ? 0.3 : 1) } // short words: ka = แค่, ma = แม่
            if ch == E && next != Y { add(i, 1, "x", 1.3) }
            if (ch == E || ch == X) && next == W { add(i, 2, "iaw", 1.5) }
            if ch == E && next == Y { add(i, 2, "qy", 1) }
            if ch == E && next == W && !inPair { add(i, 1, "i", 1.3) } // hew = หิว
            if ch == X && k.count > 2 { add(i, 1, "e", 1.5) } // prathaet = ประเทศ
            if ch == Q && next != Y { add(i, 1, "v", 1.3) } // ur for อือ: kurn = ขึ้น, chur = ชื่อ
            if ch == E && next != Y && next != W { add(i, 1, "q", 1.5) } // e for เออ: den = เดิน, che = เจอ
            if ch == U && next != A && next != Y { add(i, 1, "v", 1.3) }
        }
        return out
    }

    private struct Other { let id: Int; let pen: Double }
    private struct Lex { let k: String; let full: String; let cluster: Bool; let ids: [Int]; let others: [Other]; let short: Double; let hMarked: Bool; let shortA: Bool }
    private var lexCache: [String: Lex] = [:]
    private func lex(_ chunk: [UInt8]) -> Lex {
        let cs = String(decoding: chunk, as: UTF8.self)
        if let L = lexCache[cs] { return L }
        let t = tok(cs)
        let ids = idsOf(t.key).prefix(6).map(Int.init)
        var uaIds: [Int] = []
        for ua in Self.uAsA(chunk) {
            for id in idsOf(tok(String(decoding: ua, as: UTF8.self)).key).prefix(3).map(Int.init)
            where !ids.contains(id) && !uaIds.contains(id) && !phraseIds.contains(Int32(id)) { uaIds.append(id) }
        }
        // Other readings, each with its extra cost: "u" for a, then vowel habits (which need
        // more support from the words around them when the letters already spell a word).
        var others = uaIds.map { Other(id: $0, pen: ids.isEmpty ? 1.2 : 5) }
        if t.key.utf8.count <= 10 {
            for (v, c) in Self.habitVariants(t.key) {
                for id in idsOf(v).prefix(2).map(Int.init)
                where !ids.contains(id) && !others.contains(where: { $0.id == id }) && !phraseIds.contains(Int32(id)) {
                    others.append(Other(id: id, pen: c + (ids.isEmpty ? 1 : 2)))
                }
            }
        }
        let L = Lex(k: t.key, full: t.full, cluster: t.full != t.key, ids: ids, others: others,
                    short: t.key.utf8.count < 2 ? 5 : 0, hMarked: Self.hMarked(chunk), shortA: Self.shortA(chunk))
        if lexCache.count > 8000 { lexCache.removeAll() }
        lexCache[cs] = L
        return L
    }

    // A slip of the finger inside a sentence: when a stretch of letters spells no word, the
    // words it would spell with one letter put right (swapped back, a neighbouring key, an
    // extra letter taken out) or with one missing sound put in. Each with its extra cost.
    // Costs, set with tests/typos.test.js: BASE is added to every put-right letter, MISSING is
    // a missing sound, MIN the shortest stretch looked at, GATE the cost per letter above
    // which the input counts as not reading well, WIN how much cheaper a put-right reading
    // must be to go first, LAST the extra for a slip in the last word (it may just be unfinished).
    private static let SLIP_BASE = 3.0, SLIP_MISSING = 5.0, SLIP_MAX = 4, SLIP_GATE = 1.6, SLIP_MIN = 3, SLIP_WIN = 2.0, SLIP_LAST = 2.0
    private var fixCache: [String: [Other]] = [:]
    private func slipFixes(_ chunk: [UInt8], _ L: Lex) -> [Other] {
        if !L.ids.isEmpty || chunk.count < Self.SLIP_MIN || chunk.count > 14 { return [] }
        let cs = String(decoding: chunk, as: UTF8.self)
        if let f = fixCache[cs] { return f }
        var best: [Int: Double] = [:] // id -> extra cost
        func add(_ id: Int, _ pen: Double) {
            if phraseIds.contains(Int32(id)) { return }
            if let o = best[id], o <= pen { return }
            best[id] = pen
        }
        // The same variants as typoVariants (swap 3.2, neighbour key 3.6, drop 4), tried one by
        // one: `add` keeps the cheapest, so no list of them is needed.
        func tryVariant(_ v: [UInt8], _ vc: Double) {
            guard let list = byKey[Self.tokenize(bytes: v).key] else { return }
            for id in list.prefix(2) { add(Int(id), Self.SLIP_BASE + vc) }
        }
        var v = chunk
        for i in 0..<chunk.count {
            if i < chunk.count - 1 && chunk[i] != chunk[i + 1] {
                v.swapAt(i, i + 1); tryVariant(v, 3.2); v.swapAt(i, i + 1)
            }
            for c in Self.NEIGHBOURS[chunk[i]] ?? [] { v[i] = c; tryVariant(v, 3.6) }
            v[i] = chunk[i]
            var d = chunk
            d.remove(at: i)
            tryVariant(d, 4)
        }
        if L.k.utf8.count >= 3 {
            var lo = 0, hi = delKeys.count
            while lo < hi {
                let m = (lo + hi) >> 1
                if delKeys[m] < L.k { lo = m + 1 } else { hi = m }
            }
            while lo < delKeys.count && delKeys[lo] == L.k {
                if let id = idsOf(sortedKeys[Int(delVals[lo])]).first { add(Int(id), Self.SLIP_MISSING) }
                lo += 1
            }
        }
        // Keep the few most likely: how common the word is counts as much as the kind of slip.
        let ranked = best.map { (id: $0.key, pen: $0.value, rank: $0.value - uni($0.key)) }
            .sorted { $0.rank != $1.rank ? $0.rank < $1.rank : $0.id < $1.id }
        let out = ranked.prefix(Self.SLIP_MAX).map { Other(id: $0.id, pen: $0.pen) }
        if fixCache.count > 8000 { fixCache.removeAll() }
        fixCache[cs] = out
        return out
    }

    private struct State { var cost: Double; var ids: [Int]; var last: Int?; var last2: Int?; var lastKey: String?; var lens: [Int]; var fix = false; var open = false }
    private struct Alt { let text: String; let cost: Double; let n: Int; let fix: Bool }
    private struct Seg { let cost: Double; let ids: [Int]; let lens: [Int]; let end: Int; let alts: [Alt]; let split: State?; let fix: Bool; let open: Bool }

    private func textOf(_ ids: [Int]) -> String { ids.map { $0 == Self.REPEAT ? "ๆ" : words[$0] }.joined() }

    // Reused across keystrokes: positions before the part that changed stay valid.
    private var memoRaw: [UInt8] = [], memoPrev: Int? = nil, memoStates: [[State]]? = nil
    private var slipRaw: [UInt8] = [], slipPrev: Int? = nil, slipStates: [[State]]? = nil

    /// slips: also puts one slip of the finger right (slower: only asked for when the input
    /// doesn't read well as typed). Each kind of search keeps its own work.
    private func segment(_ raw: [UInt8], _ prev: Int?, slips: Bool = false) -> Seg? {
        let n = raw.count
        var states: [[State]] = []
        var from = 0
        var reused = false
        let memoRaw = slips ? slipRaw : self.memoRaw
        if let old = slips ? slipStates : memoStates, (slips ? slipPrev : memoPrev) == prev {
            var L = 0
            while L < n && L < memoRaw.count && raw[L] == memoRaw[L] { L += 1 }
            if L > 0 {
                states = Array(old.prefix(L))
                while states.count <= n { states.append([]) }
                from = L
                reused = true
            }
        }
        if !reused {
            states = Array(repeating: [], count: n + 1)
            states[0] = [State(cost: 0, ids: [], last: prev, last2: nil, lastKey: nil, lens: [])]
            from = 1
        }
        var i = max(0, from - 30)
        while i < n {
            if !states[i].isEmpty {
                let canFix = slips && states[i].contains { !$0.fix } // one slip per reading: no use looking after one
                var j = max(i + 1, from)
                while j <= min(n, i + 30) {
                    defer { j += 1 }
                    let chunk = Array(raw[i..<j])
                    let L = lex(chunk)
                    let fixes = canFix ? slipFixes(chunk, L) : []
                    var ids = L.ids
                    let others = L.others
                    var pen = 0.0
                    if ids.isEmpty && others.isEmpty && j == n && L.k.utf8.count >= 2 {
                        // Unfinished last word: best completions.
                        ids = Array(keysWithPrefix(L.k, 60).flatMap { idsOf($0).prefix(2).map(Int.init) }
                            .filter { !phraseIds.contains(Int32($0)) }
                            .stableSorted { uni($0) > uni($1) }.prefix(3))
                        pen = 3
                    }
                    if ids.isEmpty && others.isEmpty && fixes.isEmpty && !(states[i].first?.lastKey == L.k) { continue }
                    for s in states[i] {
                        // Same sounds as the word before: Thai writes the repeat as ๆ (makmak -> มากๆ).
                        if let lk = s.lastKey, !lk.isEmpty, L.k == lk {
                            states[j].append(State(cost: s.cost + 1.5, ids: s.ids + [Self.REPEAT], last: s.last, last2: s.last2,
                                                   lastKey: nil, lens: s.lens + [j - i], fix: s.fix))
                        }
                        for q in 0..<(ids.count + others.count) {
                            let other: Other? = q >= ids.count ? others[q - ids.count] : nil
                            let id = other?.id ?? ids[q]
                            var cost = s.cost + wcost(s.last, id, s.last2) + pen + L.short + (other?.pen ?? 0)
                            if L.cluster && hasFull(id, L.full) { cost -= 2.5 }
                            if L.hMarked && Self.startsWithHo(words[id]) { cost -= i == 0 ? 8 : 4 } // mid-sentence the h may start the next word
                            if L.shortA && Self.shortAWord(words[id]) { cost -= Self.SHORT_A_BONUS }
                            if j == n && pen == 0 && enderIds.contains(id) { cost -= 3 }
                            if j == n && id == notId { cost += 3 }
                            if politeIds.contains(id), let last = s.last, last == inId || phraseLast[Int32(last)].map(Int.init) == inId { cost += 3 }
                            states[j].append(State(cost: cost, ids: s.ids + [id], last: id, last2: s.last,
                                                   lastKey: pen != 0 ? nil : L.k, lens: s.lens + [j - i], fix: s.fix, open: pen > 0))
                        }
                        // One slip of the finger per reading.
                        if !s.fix {
                            for f in fixes {
                                // The last word may just not be finished yet: a slip there has to earn more.
                                var cost = s.cost + wcost(s.last, f.id, s.last2) + f.pen + (j == n ? Self.SLIP_LAST : 0)
                                if j == n && enderIds.contains(f.id) { cost -= 3 }
                                states[j].append(State(cost: cost, ids: s.ids + [f.id], last: f.id, last2: s.last,
                                                       lastKey: nil, lens: s.lens + [j - i], fix: true))
                            }
                        }
                    }
                    if states[j].count > Self.BEAM * 4 {
                        states[j] = Array(states[j].stableSorted { $0.cost < $1.cost }.prefix(Self.BEAM))
                    }
                }
            }
            if i + 1 >= from && i + 1 <= n {
                states[i + 1] = Array(states[i + 1].stableSorted { $0.cost < $1.cost }.prefix(Self.BEAM))
            }
            i += 1
        }
        if slips { slipRaw = raw; slipPrev = prev; slipStates = states } else { self.memoRaw = raw; memoPrev = prev; memoStates = states }
        // Whole input if possible, else the longest start that reads.
        var j = n
        while j > 0 {
            defer { j -= 1 }
            // A slip is only put right when the whole input then reads: the start of an input
            // that doesn't read to the end is taken as typed.
            let sorted = (j == n ? states[j] : states[j].filter { !$0.fix }).stableSorted { $0.cost < $1.cost }
            if sorted.isEmpty { continue }
            var alts: [Alt] = []
            var seen = Set<Exact>()
            for st in sorted {
                let tx = textOf(st.ids)
                if !seen.insert(Exact(tx)).inserted { continue }
                alts.append(Alt(text: tx, cost: st.cost, n: st.ids.count, fix: st.fix))
                if alts.count >= 3 { break }
            }
            let best = alts[0].text
            let split = sorted.first { $0.ids.count > 1 && textOf($0.ids) == best } ?? sorted.first { $0.ids.count > 1 }
            return Seg(cost: sorted[0].cost, ids: sorted[0].ids, lens: sorted[0].lens, end: j, alts: alts, split: split, fix: sorted[0].fix, open: sorted[0].open)
        }
        return nil
    }

    // MARK: - Candidates

    private static let NEIGHBOURS: [UInt8: [UInt8]] = {
        let m: [Character: String] = [
            "q": "wa", "w": "qeas", "e": "wrds", "r": "etdf", "t": "ryfg", "y": "tugh", "u": "yihj", "i": "uojk", "o": "ipkl", "p": "ol",
            "a": "qwsz", "s": "awedxz", "d": "serfcx", "f": "drtgvc", "g": "ftyhbv", "h": "gyujnb", "j": "huikmn", "k": "jiolm", "l": "kop",
            "z": "asx", "x": "zsdc", "c": "xdfv", "v": "cfgb", "b": "vghn", "n": "bhjm", "m": "njk",
        ]
        var out: [UInt8: [UInt8]] = [:]
        for (k, v) in m { out[k.asciiValue!] = Array(v.utf8) }
        return out
    }()

    /// Letter-level typo fixes, in the web engine's order: swap two (3.2), neighbour key (3.6), drop one (4).
    private static func typoVariants(_ raw: [UInt8]) -> [([UInt8], Double)] {
        var order: [[UInt8]] = []
        var cost: [[UInt8]: Double] = [:]
        if raw.count < 3 || raw.count > 14 { return [] }
        func add(_ v: [UInt8], _ c: Double) {
            if v == raw { return }
            if let o = cost[v] { if o <= c { return } } else { order.append(v) }
            cost[v] = c
        }
        for i in 0..<raw.count {
            if i < raw.count - 1 {
                var s = raw
                s.swapAt(i, i + 1)
                add(s, 3.2)
            }
            for c in NEIGHBOURS[raw[i]] ?? [] {
                var s = raw
                s[i] = c
                add(s, 3.6)
            }
            var s = raw
            s.remove(at: i)
            add(s, 4)
        }
        return order.map { ($0, cost[$0]!) }
    }

    private static func diphthongVariants(_ key: String) -> [String] {
        let k = Array(key.utf8)
        var out: [String] = []
        for i in 0..<k.count {
            let ch = k[i]
            guard ch == UInt8(ascii: "v") || ch == UInt8(ascii: "i") || ch == UInt8(ascii: "u") else { continue }
            let nextIsA = i + 1 < k.count && k[i + 1] == UInt8(ascii: "a")
            if !nextIsA { out.append(String(decoding: k[0...i] + [UInt8(ascii: "a")] + k[(i + 1)...], as: UTF8.self)) }
            if nextIsA { out.append(String(decoding: Array(k[0...i]) + Array(k[(i + 2)...]), as: UTF8.self)) }
        }
        return out
    }

    private struct Item { let text: String; let c: Double; let tier: Int; let kind: String; let consume: Int }

    /// Ranked Thai guesses for romanized `input`. `consume` = how many letters each one uses up.
    func candidates(_ input: String, limit: Int = 9, previous prevText: String? = nil, fast: Bool = false) -> [Result] {
        var raw = Self.letters(input)
        if raw.isEmpty { return [] }
        if raw.count > 60 { raw = Array(raw.prefix(60)) }
        let n = raw.count
        let rawS = String(decoding: raw, as: UTF8.self)
        let prev: Int? = prevText.flatMap { wordId[Exact($0)] }.map(Int.init)
        let t = tok(rawS)
        let (closedKey, openKey) = Self.openKeys(raw)
        var costOrder: [Int] = []
        var cost: [Int: Double] = [:]
        var tierOf: [Int: Int] = [:]
        // Tiers, best first: 0 = every typed sound (plus habits, completions, fluent sentences);
        // 1 = corrections keeping your consonants; 2 = corrections changing a consonant.
        func consonants(_ k: String) -> String { String(k.unicodeScalars.filter { $0.value >= 65 && $0.value <= 90 }.map(Character.init)) }
        let typedC = consonants(closedKey)
        func tierFor(_ k: String, _ prefix: Bool = false) -> Int {
            (prefix ? consonants(k).hasPrefix(typedC) : consonants(k) == typedC) ? 1 : 2
        }
        let hMarked = Self.hMarked(raw), shortA = Self.shortA(raw)
        let rawSpelled = "|" + rawS + "|"
        func put(_ id: Int, _ extra: Double, _ tier: Int = 0) {
            var c = wcost(prev, id, nil) + extra
            if hasFull(id, t.full) { c -= t.full != t.key ? 2.5 : 0.8 } // typed the cluster: krap -> ครับ
            if ("|" + spell[id] + "|").contains(rawSpelled) { c -= 2 } // one of its known spellings, letter for letter
            let w = words[id]
            if hMarked && Self.startsWithHo(w) { c -= 8 }
            if shortA && Self.shortAWord(w) { c -= Self.SHORT_A_BONUS }
            if w.utf16.count > 3 && w.unicodeScalars.reversed().starts(with: "ไม่".unicodeScalars.reversed()) { c += 2 }
            let ot = tierOf[id]
            if ot == nil || tier < ot! || (tier == ot! && c < cost[id]!) {
                if cost[id] == nil { costOrder.append(id) }
                cost[id] = c
                tierOf[id] = tier
            }
        }

        // 1. Exact sound match.
        let exactIds = idsOf(closedKey).map(Int.init)
        for id in exactIds { put(id, 0) }
        // 2. Still typing: completions that keep every typed sound.
        let useOpen = (openKey.map { !$0.isEmpty } ?? false) && openKey!.utf8.count >= closedKey.utf8.count
        var prefKeys: [String] = []
        var prefSeen = Set<String>()
        for k in keysWithPrefix(closedKey) + (useOpen ? keysWithPrefix(openKey!) : []) where prefSeen.insert(k).inserted { prefKeys.append(k) }
        for k in prefKeys where k != closedKey {
            let more = k.utf8.count - closedKey.utf8.count
            if more <= 0 { continue }
            for id in idsOf(k).prefix(4).map(Int.init) { put(id, 2 + 0.3 * Double(more) + (phraseIds.contains(Int32(id)) ? 3 : 0), 0) }
        }
        // Stretched letters for emphasis: also read each run as one letter.
        let unstretched = Self.collapseRuns(raw, keep: 1)
        if unstretched != raw {
            for id in idsOf(tok(String(decoding: unstretched, as: UTF8.self)).key).prefix(4).map(Int.init) { put(id, 0.3) }
        }
        // 3. Letter typos.
        for (v, vc) in Self.typoVariants(raw) {
            let vk = tok(String(decoding: v, as: UTF8.self)).key
            for id in idsOf(vk).prefix(3).map(Int.init) { put(id, vc, tierFor(vk)) }
        }
        // "u" for the short a sound.
        for ua in Self.uAsA(raw) {
            for id in idsOf(tok(String(decoding: ua, as: UTF8.self)).key).prefix(4).map(Int.init) {
                put(id, exactIds.isEmpty ? 1.2 : 2.5, exactIds.isEmpty ? 0 : 1)
            }
        }
        // Vowel habits (a for แ, eo for เอียว, ...): count as typed sounds, a little behind exact.
        for (v, c) in Self.habitVariants(closedKey) {
            for id in idsOf(v).prefix(3).map(Int.init) { put(id, c, 0) }
        }
        // 4. Near sounds, unless the input already reads well.
        var seg = n >= 4 ? segment(raw, prev) : nil
        // Doesn't read well as typed: look again, allowing for one slip of the finger.
        var slipWins = false
        if n >= 4 && !(seg.map { $0.end == n && $0.cost / Double(n) <= Self.SLIP_GATE } ?? false) {
            let fixed = segment(raw, prev, slips: true)
            // With no word spelt exactly, a put-right reading that still costs clearly less than
            // the reading as typed is the likelier one.
            if let fixed, fixed.fix, exactIds.isEmpty {
                slipWins = seg.map { $0.end < n || (!$0.open && fixed.cost + Self.SLIP_WIN < $0.cost) } ?? true
            }
            seg = fixed ?? seg
        }
        let readsWell = exactIds.count >= 4 || (seg.map { !$0.fix && $0.end == n && $0.ids.count > 1 && $0.cost / Double(n) <= Self.FLUENT } ?? false)
        if closedKey.utf8.count >= 3 && !fast && !readsWell {
            let kl = closedKey.utf8.count
            let budget = kl <= 4 ? 0.7 : kl <= 7 ? 1.1 : 1.6
            for (k, d) in fuzzy(closedKey, budget, false) {
                for id in idsOf(k).prefix(4).map(Int.init) { put(id, 1.5 + 5 * d, tierFor(k)) }
            }
            if cost.count < limit {
                for (k, d) in fuzzy(closedKey, budget * 0.8, true) {
                    for id in idsOf(k).prefix(2).map(Int.init) { put(id, 3 + 5 * d, tierFor(k, true)) }
                }
            }
        }
        // 5. Long/short vowel pairs (ue/uea is a habit; i/ia and u/ua are corrections).
        let plain = closedKey.replacingOccurrences(of: "va", with: "v")
        for v in Self.diphthongVariants(closedKey) {
            let habit = v.replacingOccurrences(of: "va", with: "v") == plain
            for id in idsOf(v).prefix(3).map(Int.init) { put(id, 1.5, habit ? 0 : 1) }
        }

        // ...and the input isn't the start of a longer word, and no near-sounding word is a cheaper guess.
        if slipWins, let seg, cost.contains(where: { tierOf[$0.key] == 0 || (tierOf[$0.key] == 1 && $0.value < seg.cost) }) { slipWins = false }
        var items = costOrder.map { Item(text: words[$0], c: cost[$0]!, tier: tierOf[$0]!, kind: "word", consume: n) }
        if let seg, seg.ids.count > 1 || seg.end < n || seg.fix || seg.alts.contains(where: { $0.n > 1 || $0.fix }) {
            let partial = seg.end < n
            // A reading that puts a slip right is a correction, however well it reads.
            let fluent = !partial && !seg.fix && seg.ids.count > 1 && seg.cost / Double(n) <= Self.FLUENT
            let phraseTier = slipWins || (!seg.fix && (fluent || (seg.ids.count == 1 && !partial))) ? 0 : 1
            var c = seg.cost + (partial ? 3 : 0)
            let minCost = cost.values.map { $0 - 0.01 }.min()
            if fluent && exactIds.isEmpty, let m = minCost { c = min(c, m) }
            if partial && Double(seg.end) >= Double(n) * 0.6, let m = minCost { c = min(c, m) }
            items.append(Item(text: textOf(seg.ids), c: c, tier: phraseTier, kind: "phrase", consume: seg.end))
            for a in seg.alts.dropFirst() {
                // Backup readings never jump above a word that matches the whole input exactly.
                let floor = exactIds.isEmpty ? -Double.infinity : (exactIds.map { cost[$0] ?? .infinity }.min()! + 0.01)
                let altTier = !partial && !a.fix && a.cost / Double(n) <= Self.FLUENT ? 0 : 1
                if a.n > 1 || a.fix { items.append(Item(text: a.text, c: max(floor, c + 0.05 + (a.cost - seg.cost)), tier: altTier, kind: "phrase", consume: seg.end)) }
            }
            // Pick just the first word and keep typing the rest (like pinyin).
            let multi: (ids: [Int], lens: [Int])? = seg.ids.count > 1 ? (seg.ids, seg.lens) : seg.split.map { ($0.ids, $0.lens) }
            let first = multi?.lens[0] ?? n
            let firstIds = idsOf(tok(String(decoding: raw.prefix(first), as: UTF8.self)).key).prefix(4).map(Int.init)
            let own = multi?.ids[0]
            if let multi {
                for id in [own] + firstIds.filter({ $0 != own }).map(Optional.some) {
                    guard let id, id != Self.REPEAT else { continue }
                    let cc = id == own ? c + 0.02 : max(c, wcost(prev, id, nil)) + 3
                    items.append(Item(text: words[id], c: cc, tier: phraseTier, kind: "first", consume: first))
                }
            }
        }
        items = items.stableSorted { $0.tier != $1.tier ? $0.tier < $1.tier : $0.c < $1.c }

        // First page: exact matches first, but up to 3 slots go to corrections more likely
        // than the exact matches they displace.
        var uniq: [Item] = []
        var seen = Set<Exact>()
        for it in items where seen.insert(Exact(it.text)).inserted { uniq.append(it) }
        let PAGE = 9, RESERVE = 3
        let exact = uniq.filter { $0.tier == 0 }, fixes = uniq.filter { $0.tier != 0 }
        var r = 0
        while r < RESERVE && r < fixes.count && (exact.count < PAGE - r || fixes[r].c < exact[PAGE - 1 - r].c) { r += 1 }
        let firstExact = Array(exact.prefix(PAGE - r))
        let take = PAGE - firstExact.count
        let ordered = firstExact + fixes.prefix(take) + exact.dropFirst(firstExact.count) + fixes.dropFirst(min(take, fixes.count))
        return ordered.prefix(limit).map { Result(text: $0.text, consume: $0.consume, kind: $0.kind, tier: $0.tier, cost: ($0.c * 10).rounded() / 10) }
    }

    // MARK: - Learning

    /// Remember a pick (whole phrases aren't stored; their words are found by the pairs).
    func learn(_ text: String, previous prevText: String?, kind: String) {
        if text.isEmpty || kind == "phrase" { return }
        learnedU[text] = min(10, (learnedU[text] ?? 0) + 1)
        if let p = prevText, !p.isEmpty {
            let k = p + "\t" + text
            learnedB[k] = min(10, (learnedB[k] ?? 0) + 1)
        }
        Self.prune(&learnedU)
        Self.prune(&learnedB)
    }

    private static func prune(_ d: inout [String: Double]) {
        if d.count <= maxLearned { return }
        let drop = d.count - Int(Double(maxLearned) * 0.8)
        for (k, _) in d.sorted(by: { $0.value != $1.value ? $0.value < $1.value : $0.key < $1.key }).prefix(drop) { d[k] = nil }
    }

    /// Learned picks as JSON, for saving.
    func learnedData() -> Data? { try? JSONSerialization.data(withJSONObject: ["u": learnedU, "b": learnedB]) }

    func forget() { learnedU = [:]; learnedB = [:] }

    /// Drop caches that rebuild themselves (low memory).
    func trimCaches() {
        tokCache.removeAll()
        lexCache.removeAll()
        fixCache.removeAll()
        memoStates = nil
        slipStates = nil
    }
}

/// A string compared letter for letter (like JavaScript), not by Unicode equivalence.
struct Exact: Hashable {
    let s: String
    init(_ s: String) { self.s = s }
    static func == (a: Exact, b: Exact) -> Bool { a.s.utf8.elementsEqual(b.s.utf8) }
    func hash(into h: inout Hasher) {
        var s = s
        s.withUTF8 { h.combine(bytes: UnsafeRawBufferPointer($0)) }
    }
}

extension Array {
    /// Sort that keeps equal elements in their original order (like JavaScript's sort).
    func stableSorted(by less: (Element, Element) -> Bool) -> [Element] {
        enumerated().sorted { less($0.element, $1.element) || (!less($1.element, $0.element) && $0.offset < $1.offset) }.map(\.element)
    }
}
