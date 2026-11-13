import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Type Thai by sound. Letters collect in the bar above the keys; Space (or Return)
/// types the first Thai guess, a tap types any guess, a tap on the letters types them as
/// English. The EN key switches to plain English typing (ไทย switches back).
final class KeyboardViewController: UIInputViewController {
    private let bar = CandidateBar()
    private let keys = KeyboardView()
    private var heightConstraint: NSLayoutConstraint?

    // Typing state (same rules as the Mac keyboard).
    private(set) var buffer = ""
    private var cands: [Candidate] = []
    private var candsFor: String? // the letters `cands` were looked up for
    private var request = 0
    private var prevWord: String? // the Thai just typed: word pairs pick the likely meaning
    private var thai = true
    private var shiftOn = false, capsLock = false
    private var lastShiftTap = Date.distantPast
    private static let maxLetters = 48
    // English spelling guesses (the system's spell checker), looked up off the main thread.
    private let speller = UITextChecker()
    private let spellQueue = DispatchQueue(label: "ThaiPinyin.spell", qos: .userInitiated)

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyLog.note("LIFE viewDidLoad pid=\(ProcessInfo.processInfo.processIdentifier)"); KeyLog.flush()
        _ = Engine.shared // start loading the word list now
        view.addSubview(bar)
        view.addSubview(keys) // after the bar so top-row letter popups draw over it
        keys.clipsToBounds = false
        bar.onPick = { [weak self] i in self?.pick(i) }
        bar.onKeepLetters = { [weak self] in self?.commitRaw() }
        bar.onPalette = { [weak self] in
            Palette.saved = Palette.saved.next
            self?.applyTheme()
        }
        keys.onKey = { [weak self] k in self?.press(k) }
        keys.onDeleteRepeat = { [weak self] in self?.deleteBackward() }
        keys.onGlobe = { [weak self] v, e in self?.handleInputModeList(from: v, with: e ?? UIEvent()) }
        keys.onTouch = { [weak self] in self?.tap() }
        bar.onTouch = { [weak self] in self?.tap() }
        // Auto Layout all the way down. iOS 26 sizes the keyboard from what its contents
        // need; frame-positioned subviews made that "whatever height it has now", so the
        // keyboard could only grow. These constraints say exactly bar + keys.
        bar.translatesAutoresizingMaskIntoConstraints = false
        keys.translatesAutoresizingMaskIntoConstraints = false
        let barH = bar.heightAnchor.constraint(equalToConstant: 44)
        let keysH = keys.heightAnchor.constraint(equalToConstant: 216)
        let top = bar.topAnchor.constraint(equalTo: view.topAnchor)
        top.priority = UILayoutPriority(999) // if iOS insists on more room, it goes above the bar
        NSLayoutConstraint.activate([
            keys.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keys.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keys.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            keysH,
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: keys.topAnchor),
            barH, top,
        ])
        barHeight = barH; keysHeight = keysH
    }
    private var barHeight: NSLayoutConstraint?, keysHeight: NSLayoutConstraint?

    /// The keyboard's height. iOS drops constraints on this view when it sets the keyboard up,
    /// so this is (re)applied every time the keyboard appears, with self-sizing on so iOS
    /// takes its height from the constraint instead of its own default (444 pt on iOS 26).
    private func applyHeight(_ height: CGFloat) {
        (view as? UIInputView)?.allowsSelfSizing = true
        if let h = heightConstraint, h.isActive, view.constraints.contains(h) {
            if h.constant != height { h.constant = height }
            return
        }
        let h = view.heightAnchor.constraint(equalToConstant: height)
        h.priority = UILayoutPriority(999)
        h.identifier = "ThaiPinyin-height"
        h.isActive = true
        heightConstraint = h
    }

    private func wantedHeight() -> CGFloat {
        let w = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let landscape = w > UIScreen.main.bounds.height && traitCollection.userInterfaceIdiom == .phone
        let pad = traitCollection.userInterfaceIdiom == .pad
        let barH: CGFloat = pad ? 50 : (landscape ? 36 : 44)
        let keysH: CGFloat = pad ? (w > 900 ? 340 : 270) : (landscape ? 162 : 216)
        return barH + keysH
    }

    // A light tap on every key press. iOS only allows it with "Allow Full Access" on;
    // without it the call does nothing.
    // A short, crisp tick like Apple's keyboard: a "rigid" tap at reduced strength (a full
    // "light" tap is heavier and duller than the system's).
    private var haptic: UIImpactFeedbackGenerator?
    private var hapticsAllowed = false
    private static let hapticStrength: CGFloat = 0.65
    private func tap() {
        guard hapticsAllowed, let haptic else { return }
        let t0 = Date()
        if #available(iOS 17.5, *) { haptic.impactOccurred(intensity: Self.hapticStrength, at: .zero) }
        else { haptic.impactOccurred(intensity: Self.hapticStrength) }
        haptic.prepare() // keeps the Taptic Engine awake for the next key
        let ms = Date().timeIntervalSince(t0) * 1000
        if ms > 3 { KeyLog.note("haptic took \(Int(ms))ms") }
    }

    /// Made and woken up before the first key, so the first tap isn't late.
    private func readyHaptic() {
        hapticsAllowed = hasFullAccess // asked once per appearance, not on every key
        guard hapticsAllowed else { return }
        if haptic == nil {
            // Tied to the keyboard's view: newer iOS plays feedback only for a view on screen.
            if #available(iOS 17.5, *) { haptic = UIImpactFeedbackGenerator(style: .rigid, view: keys) }
            else { haptic = UIImpactFeedbackGenerator(style: .rigid) }
        }
        haptic?.prepare()
    }

    private let gate = Gate()

    override func viewWillAppear(_ animated: Bool) {
        KeyLog.note("LIFE viewWillAppear bounds=\(view.bounds.size)"); KeyLog.flush()
        if Gate.enabled { Task { await gate.refreshUnlocked() } }
        super.viewWillAppear(animated)
        applyHeight(wantedHeight())
        startFresh()
        readyHaptic()
    }

    #if DEBUG
    /// Debug: notes every moment the keyboard's main thread misses frames for over 50 ms.
    private var stallLink: CADisplayLink?
    private var lastFrame: CFTimeInterval = 0
    @objc private func frameTick(_ link: CADisplayLink) {
        if lastFrame > 0, link.timestamp - lastFrame > 0.05 { KeyLog.note("STALL \(Int((link.timestamp - lastFrame) * 1000))ms") }
        lastFrame = link.timestamp
    }
    #endif

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        KeyLog.note("LIFE viewDidAppear bounds=\(view.bounds.size)")
        #if DEBUG
        if stallLink == nil {
            stallLink = CADisplayLink(target: self, selector: #selector(frameTick(_:)))
            stallLink?.add(to: .main, forMode: .common)
        }
        lastFrame = 0
        KeyLog.note("haptics \(hapticsAllowed ? "on" : "off")")
        #endif
        // iOS holds touches near the screen edges back for a moment to check for system
        // swipes, which makes the keys feel late. The keys handle touches themselves.
        setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
        releaseSystemGestures()
        // iOS may add its recognizers a moment later.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.releaseSystemGestures() }
        readyHaptic()
    }

    #if DEBUG
/// Debug: notes every touch the keyboard's window receives, to tell a touch iOS never
/// delivered from one lost on the way to the keys. Never recognizes, never cancels.
final class TouchWatcher: UIGestureRecognizer {
    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        for t in touches { KeyLog.note("WINDOW down at \(Int(t.location(in: view).x)),\(Int(t.location(in: view).y)) view=\(t.view.map { String(describing: type(of: $0)) } ?? "nil")") }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) { state = .failed }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        for _ in touches { KeyLog.note("WINDOW cancelled") }
        state = .failed
    }
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool { false }
}
#endif

/// System gesture recognizers on the keyboard's window and the views around ours must not
    /// hold touches back or take them away: a second finger landing before the first lifts
    /// (fast typing) would otherwise never reach the keys.
    private func releaseSystemGestures() {
        var v: UIView? = view
        while let cur = v {
            for g in cur.gestureRecognizers ?? [] {
                KeyLog.note("gesture \(type(of: g)) on \(type(of: cur)) cancels=\(g.cancelsTouchesInView) delays=\(g.delaysTouchesBegan) enabled=\(g.isEnabled)")
                g.delaysTouchesBegan = false
                g.delaysTouchesEnded = false
                g.cancelsTouchesInView = false
                // The window's gates for system gestures (home swipe, edges) can still hold a
                // touch while they decide; the real system gestures are handled outside the keyboard.
                if String(describing: type(of: g)).contains("GateGestureRecognizer") { g.isEnabled = false }
            }
            cur.isMultipleTouchEnabled = true
            cur.isExclusiveTouch = false
            v = cur.superview
        }
        #if DEBUG
        if let w = view.window, !(w.gestureRecognizers ?? []).contains(where: { $0 is TouchWatcher }) {
            w.addGestureRecognizer(TouchWatcher())
        }
        #endif
        KeyLog.flush()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        KeyLog.note("LIFE viewDidDisappear"); KeyLog.flush()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        KeyLog.note("viewWillDisappear (buffer was \(buffer))")
        #if DEBUG
        stallLink?.invalidate(); stallLink = nil
        #endif
        KeyLog.flush()
        buffer = ""; cands = []; candsFor = nil
        Engine.shared.saveSoon()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        Engine.shared.trim()
    }

    #if DEBUG
    private var lastLoggedSize = CGSize.zero
    #endif
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        #if DEBUG
        if view.bounds.size != lastLoggedSize {
            lastLoggedSize = view.bounds.size
            KeyLog.note("LIFE layout bounds=\(view.bounds.size) window=\(String(describing: view.window?.bounds.size))"); KeyLog.flush()
        }
        #endif
        let w = view.bounds.width
        let landscape = w > UIScreen.main.bounds.height && traitCollection.userInterfaceIdiom == .phone
        let pad = traitCollection.userInterfaceIdiom == .pad
        let barH: CGFloat = pad ? 50 : (landscape ? 36 : 44)
        let keysH: CGFloat = pad ? (w > 900 ? 340 : 270) : (landscape ? 162 : 216)
        applyHeight(barH + keysH)
        if barHeight?.constant != barH { barHeight?.constant = barH }
        if keysHeight?.constant != keysH { keysHeight?.constant = keysH }
        keys.compact = !pad
        keys.showsGlobe = needsInputModeSwitchKey
    }

    override func textWillChange(_ textInput: UITextInput?) {}

    override func textDidChange(_ textInput: UITextInput?) {
        KeyLog.note("textDidChange type=\(String(describing: textDocumentProxy.keyboardType?.rawValue)) field=\(String(describing: fieldType?.rawValue)) buffer=\(buffer)")
        applyTheme()
        // Moved to another kind of field while the keyboard stayed up (address bar to a web page).
        if textDocumentProxy.keyboardType != fieldType { startFresh(); return }
        // The app changed the text (sent a message, moved the cursor…): what came before is gone.
        if let p = prevWord, !(textDocumentProxy.documentContextBeforeInput ?? "").hasSuffix(p) { prevWord = nil }
        autoShift()
    }

    /// The kind of text field the keyboard last set its language for.
    private var fieldType: UIKeyboardType?

    /// Email and web addresses start in English. Search boxes (Chrome's and Safari's
    /// address bar included) start in Thai: people search in Thai.
    private static func startsInThai(_ type: UIKeyboardType?) -> Bool {
        switch type {
        case .emailAddress, .URL, .asciiCapable, .numbersAndPunctuation: return false
        default: return true
        }
    }

    private func startFresh() {
        KeyLog.note("startFresh (buffer was \(buffer))")
        buffer = ""; cands = []; candsFor = nil; prevWord = nil
        fieldType = textDocumentProxy.keyboardType
        thai = Self.startsInThai(fieldType)
        keys.thai = thai
        keys.page = textDocumentProxy.keyboardType == .numbersAndPunctuation ? .numbers : .letters
        shiftOn = false; capsLock = false
        applyTheme()
        autoShift()
        refresh()
    }

    private func applyTheme() {
        let dark = textDocumentProxy.keyboardAppearance == .dark || traitCollection.userInterfaceStyle == .dark
        let t = Theme(dark: dark, palette: Palette.saved)
        if keys.theme.dark != dark || keys.theme.palette != t.palette || bar.theme.dark != dark || view.backgroundColor == nil {
            keys.theme = t
            bar.theme = t
            view.backgroundColor = .touchable // the system keyboard backdrop shows through, gaps still take taps
        }
        let rt = textDocumentProxy.returnKeyType ?? .default
        let labels: [UIReturnKeyType: String] = [.go: "go", .search: "search", .send: "send", .done: "done",
                                                 .next: "next", .join: "join", .route: "route", .continue: "continue"]
        keys.returnLabel = labels[rt] ?? "return"
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        applyTheme()
    }

    // MARK: keys

    private func press(_ k: KeyKind) {
        KeyLog.note("press \(k) buffer=\(buffer)")
        switch k {
        case .char(let c):
            if keys.page == .letters, c.count == 1, let ch = c.first, ch.isASCII, ch.isLetter {
                typeLetter(c)
            } else {
                typeSymbol(c)
            }
        case .delete: deleteBackward()
        case .space: space()
        case .ret: returnKey()
        case .shift: tapShift()
        case .toggleMode:
            if !buffer.isEmpty { commitRaw() }
            thai.toggle()
            keys.thai = thai
            keys.page = .letters
            shiftOn = false; capsLock = false
            autoShift()
        case .page(let p): keys.page = p
        case .globe: break
        }
    }

    private func typeLetter(_ c: String) {
        if !thai {
            textDocumentProxy.insertText(shiftOn || capsLock ? c.uppercased() : c)
            if shiftOn && !capsLock { shiftOn = false; keys.shiftOn = false }
            return
        }
        guard buffer.count < Self.maxLetters else { return } // the bar can't sensibly hold more
        buffer += c.lowercased()
        refresh()
    }

    /// Digits and punctuation: type the Thai first (all of it), then the symbol.
    private func typeSymbol(_ c: String) {
        if thai && !buffer.isEmpty { commitAll() }
        textDocumentProxy.insertText(c)
        prevWord = nil
        // After a symbol, go back to letters for ' and space-like keys, as iOS does.
        if c == "'" && keys.page != .letters { keys.page = .letters }
    }

    private func space() {
        if !buffer.isEmpty {
            let list = currentCandidates()
            if list.isEmpty { commitRaw(); textDocumentProxy.insertText(" ") } else { pick(0, from: list) }
            return
        }
        textDocumentProxy.insertText(" ")
        prevWord = nil // a space ends the sentence in Thai: no word-pair context across it
        if keys.page != .letters { keys.page = .letters }
        autoShift()
    }

    private func returnKey() {
        if !buffer.isEmpty {
            let list = currentCandidates()
            if list.isEmpty { commitRaw() } else { pick(0, from: list) }
            return
        }
        textDocumentProxy.insertText("\n")
        prevWord = nil
        autoShift()
    }

    private func deleteBackward() {
        if !buffer.isEmpty {
            buffer.removeLast()
            refresh()
            return
        }
        textDocumentProxy.deleteBackward()
        prevWord = nil
        autoShift()
    }

    private func tapShift() {
        guard !thai else { return }
        let now = Date()
        if now.timeIntervalSince(lastShiftTap) < 0.35 { capsLock = true; shiftOn = true } // double tap: caps lock
        else if capsLock { capsLock = false; shiftOn = false }
        else { shiftOn.toggle() }
        lastShiftTap = now
        keys.shiftOn = shiftOn
        keys.capsLock = capsLock
    }

    /// English mode: capital letter at the start of a sentence, where the app wants that.
    private func autoShift() {
        guard !thai, !capsLock else { return }
        let want: Bool = {
            guard textDocumentProxy.autocapitalizationType == .sentences || textDocumentProxy.autocapitalizationType == nil else { return false }
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let t = before.trimmingCharacters(in: .whitespaces)
            return t.isEmpty || t.hasSuffix(".") || t.hasSuffix("!") || t.hasSuffix("?") || before.hasSuffix("\n")
        }()
        shiftOn = want
        keys.shiftOn = want
    }

    // MARK: guesses

    // Touches at the bottom screen edge go to the keys first, not to the home swipe.
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    private func refresh() {
        // A tap a little above the top row is a key: up to 14 points into an empty bar, 10 while
        // it shows guesses (they're tapped near their middle).
        keys.reachUp = buffer.isEmpty ? 14 : 10
        request += 1
        let id = request
        if buffer.isEmpty {
            cands = []; candsFor = nil
            bar.show(input: "", candidates: [], loading: false)
            return
        }
        let input = buffer
        if Engine.shared.isReady {
            // A lookup takes a millisecond or two: letters and guesses change in the same frame.
            let t0 = Date()
            let list = Engine.shared.candidatesNow(for: input, previous: context())
            KeyLog.note("lookup \(input) \(Int(Date().timeIntervalSince(t0) * 1000))ms -> \(list.first?.text ?? "-")")
            cands = list; candsFor = input
            bar.show(input: input, candidates: list, loading: false)
            suggestEnglish(for: input, id: id)
            return
        }
        // Still loading the word list: keep the previous guesses (dimmed) until the new ones arrive.
        bar.show(input: buffer, candidates: cands, loading: true)
        Engine.shared.candidates(for: input, previous: context()) { [weak self] list in
            guard let self, id == self.request else { return }
            self.cands = list
            self.candsFor = input
            self.bar.show(input: input, candidates: list, loading: false)
        }
    }

    /// When the letters don't read well as Thai and aren't an English word either, the English
    /// word they most likely misspell is offered as the second guess ("tommorow": tomorrow).
    /// Never first, so Space keeps typing Thai.
    private func suggestEnglish(for input: String, id: Int) {
        // Reads badly as Thai: a correction, or over 2.5 a letter (good readings stay under 2.2).
        guard thai, input.count >= 4, let first = cands.first,
              first.isCorrection || first.cost / Double(input.count) > 2.5,
              input.allSatisfy({ $0.isASCII && $0.isLetter }) else { return }
        spellQueue.async { [weak self] in
            guard let self else { return }
            let range = NSRange(location: 0, length: input.utf16.count)
            guard self.speller.rangeOfMisspelledWord(in: input, range: range, startingAt: 0, wrap: false, language: "en_US").location != NSNotFound,
                  let guess = self.speller.guesses(forWordRange: range, in: input, language: "en_US")?.first,
                  guess.lowercased() != input.lowercased(), !guess.contains(" "), abs(guess.count - input.count) <= 2 else { return }
            DispatchQueue.main.async {
                guard id == self.request, self.candsFor == input, !self.cands.isEmpty,
                      !self.cands.contains(where: { $0.kind == "english" }) else { return }
                KeyLog.note("english \(input) -> \(guess)")
                self.cands.insert(Candidate(text: guess, consume: input.count, kind: "english"), at: 1)
                self.bar.show(input: input, candidates: self.cands, loading: false)
            }
        }
    }

    /// The guesses for exactly what's typed, looked up now if the last lookup is behind.
    private func currentCandidates() -> [Candidate] {
        if candsFor == buffer { return cands }
        let list = Engine.shared.candidatesNow(for: buffer, previous: context())
        cands = list; candsFor = buffer
        return list
    }

    private func context() -> String? {
        guard let p = prevWord, (textDocumentProxy.documentContextBeforeInput ?? "").hasSuffix(p) else { return nil }
        return p
    }

    private func pick(_ i: Int) {
        guard candsFor == buffer else { // tapped while newer letters were still being looked up
            let list = currentCandidates()
            if i < list.count { pick(i, from: list) }
            return
        }
        guard i < cands.count else { return }
        pick(i, from: cands)
    }

    private func pick(_ i: Int, from list: [Candidate]) {
        let c = list[i]
        KeyLog.note("pick \(i) \(c.text) consume=\(c.consume) buffer=\(buffer)")
        if c.kind == "english" { // an English spelling guess: typed as it is, nothing to learn or count
            textDocumentProxy.insertText(c.text)
            buffer = ""
            prevWord = nil
            cands = []; candsFor = nil
            refresh()
            return
        }
        if !gate.mayConvert { // free plan: daily words used up (only when Gate.enabled)
            commitRaw()
            bar.showNotice(Gate.limitMessage)
            return
        }
        gate.didConvert()
        let prev = context()
        textDocumentProxy.insertText(c.text)
        Engine.shared.learn(c.text, previous: prev, kind: c.kind)
        prevWord = c.text
        // A phrase can cover only the first letters: the rest stays to be typed.
        buffer = c.consume >= buffer.count ? "" : String(buffer.dropFirst(c.consume))
        cands = []; candsFor = nil
        refresh()
    }

    /// Converts everything typed (first guesses), e.g. before punctuation.
    private func commitAll() {
        var rounds = 0
        while !buffer.isEmpty && rounds < 12 {
            let list = currentCandidates()
            if list.isEmpty { break }
            pick(0, from: list)
            rounds += 1
        }
        if !buffer.isEmpty { commitRaw() }
    }

    /// Types the letters as they are (tap on them in the bar).
    private func commitRaw() {
        guard !buffer.isEmpty else { return }
        KeyLog.note("commitRaw \(buffer)")
        textDocumentProxy.insertText(buffer)
        buffer = ""
        prevWord = nil
        refresh()
    }
}
