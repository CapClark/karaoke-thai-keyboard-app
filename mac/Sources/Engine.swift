import Foundation
import JavaScriptCore

struct Candidate {
    let text: String
    let consume: Int
    var kind: String = "word"
    var isCorrection = false // doesn't match every typed sound exactly
}

/// Runs the same matching engine as the web page (engine.js) inside JavaScriptCore.
final class Engine {
    static let shared = Engine()

    private let ctx = JSContext()!
    private var saveTimer: Timer?
    private var warmTimer: Timer?

    private init() {
        ctx.exceptionHandler = { _, exc in
            NSLog("ThaiPinyin JS error: \(exc?.toString() ?? "?")")
        }
        ctx.evaluateScript("var window = this;")

        // localStorage shim backed by UserDefaults, so picked words keep ranking higher.
        let getItem: @convention(block) (String) -> Any = { key in
            UserDefaults.standard.string(forKey: key) ?? NSNull()
        }
        let setItem: @convention(block) (String, String) -> Void = { key, value in
            UserDefaults.standard.set(value, forKey: key)
        }
        let storage = JSValue(newObjectIn: ctx)!
        storage.setObject(getItem, forKeyedSubscript: "getItem" as NSString)
        storage.setObject(setItem, forKeyedSubscript: "setItem" as NSString)
        ctx.setObject(storage, forKeyedSubscript: "localStorage" as NSString)

        for name in ["phonemes", "dict", "extra", "personal", "names", "engine"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "js"),
                  let src = try? String(contentsOf: url, encoding: .utf8) else {
                if name != "personal" && name != "names" { NSLog("ThaiPinyin: missing \(name).js") }
                continue
            }
            ctx.evaluateScript(src, withSourceURL: url)
        }
        ctx.evaluateScript("""
            ThaiIME.autosave = false;
            ThaiIME.load(window.THAI_DICT, window.THAI_EXTRA || [], window.THAI_PERSONAL || [], window.THAI_NAMES || []);
            delete window.THAI_DICT; delete window.THAI_EXTRA; delete window.THAI_PERSONAL; delete window.THAI_NAMES;
            """)
        // Free the parsed word-list text now rather than whenever the collector gets to it.
        JSGarbageCollect(ctx.jsGlobalContextRef)
        NSLog("ThaiPinyin load: %@", ctx.evaluateScript("ThaiIME.loadTimes()")?.toString() ?? "?")
        // Finish the near-sound index in small slices while idle; typing works meanwhile.
        warmTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            if self.ctx.evaluateScript("ThaiIME.warmup(10)")?.toBool() ?? true { t.invalidate(); self.warmTimer = nil }
        }
    }

    /// `previous` = the Thai word just typed, so word pairs can rank guesses (กิน + khao = ข้าว).
    func candidates(for input: String, limit: Int = 36, previous: String? = nil, fast: Bool = false) -> [Candidate] {
        guard !input.isEmpty,
              let fn = ctx.objectForKeyedSubscript("ThaiIME")?.objectForKeyedSubscript("candidates"),
              let arr = fn.call(withArguments: [input, limit, previous ?? NSNull(), fast])?.toArray() as? [[String: Any]]
        else { return [] }
        return arr.compactMap { d in
            guard let t = d["text"] as? String else { return nil }
            let c = (d["consume"] as? NSNumber)?.intValue ?? input.count
            guard c >= 1, c <= input.count, !t.isEmpty else { return nil }
            return Candidate(text: t, consume: c, kind: d["kind"] as? String ?? "word",
                             isCorrection: ((d["tier"] as? NSNumber)?.intValue ?? 0) > 0)
        }
    }

    func learn(_ text: String, previous: String? = nil, kind: String = "word") {
        ctx.objectForKeyedSubscript("ThaiIME")?.objectForKeyedSubscript("learn")?
            .call(withArguments: [text, previous ?? NSNull(), kind])
        // Save a moment later, not on every pick.
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            self?.ctx.objectForKeyedSubscript("ThaiIME")?.objectForKeyedSubscript("save")?.call(withArguments: [])
        }
    }
}
