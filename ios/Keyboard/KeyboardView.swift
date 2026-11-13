import UIKit
import os

enum Page { case letters, numbers, symbols }

enum KeyKind: Equatable {
    case char(String)
    case shift, delete, space, ret, toggleMode, globe
    case page(Page)
}

struct Key {
    let kind: KeyKind
    var label: String
    var symbol: String? = nil // SF Symbol name instead of text
    var function = false // grey key
}

/// Keyboard colours. `system` looks like Apple's keyboard; the others tint the keys (the
/// system backdrop always shows through: iOS draws its own rounded keyboard shell around
/// ours, so a coloured backdrop would leave grey bands). Picked with the palette button.
enum Palette: String, CaseIterable {
    case system, mango, matcha, ocean, lychee

    var next: Palette {
        let all = Palette.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }

    /// (key, function key) for light and dark.
    func colors(dark: Bool) -> (UIColor, UIColor)? {
        let c = Self.rgb
        switch (self, dark) {
        case (.system, _): return nil
        case (.mango, false): return (c(1.00, 0.96, 0.87), c(0.97, 0.76, 0.42))
        case (.mango, true): return (c(0.45, 0.33, 0.15), c(0.32, 0.23, 0.10))
        case (.matcha, false): return (c(0.95, 0.99, 0.93), c(0.62, 0.78, 0.57))
        case (.matcha, true): return (c(0.24, 0.36, 0.24), c(0.16, 0.26, 0.16))
        case (.ocean, false): return (c(0.93, 0.96, 1.00), c(0.56, 0.71, 0.89))
        case (.ocean, true): return (c(0.20, 0.32, 0.48), c(0.12, 0.21, 0.33))
        case (.lychee, false): return (c(1.00, 0.94, 0.95), c(0.93, 0.67, 0.74))
        case (.lychee, true): return (c(0.44, 0.22, 0.27), c(0.31, 0.14, 0.18))
        }
    }

    static var saved: Palette {
        get { Palette(rawValue: UserDefaults.standard.string(forKey: "theme.palette") ?? "") ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "theme.palette") }
    }
}

struct Theme {
    let dark: Bool
    var palette: Palette = .system
    private var tint: (UIColor, UIColor)? { palette.colors(dark: dark) }
    var background: UIColor { dark ? UIColor(white: 0.13, alpha: 1) : UIColor(red: 0.82, green: 0.83, blue: 0.86, alpha: 1) }
    // Close to Apple's own keyboard colours.
    var key: UIColor { tint?.0 ?? (dark ? UIColor(white: 0.34, alpha: 1) : .white) }
    var functionKey: UIColor { tint?.1 ?? (dark ? UIColor(white: 0.21, alpha: 1) : UIColor(red: 0.67, green: 0.69, blue: 0.73, alpha: 1)) }
    var pressed: UIColor { functionKey }
    var pressedFunction: UIColor { key }
    var text: UIColor { dark ? .white : .black }
    var shadow: UIColor { dark ? UIColor(white: 0, alpha: 0.6) : UIColor(white: 0, alpha: 0.35) }
    var muted: UIColor { dark ? UIColor(white: 0.62, alpha: 1) : UIColor(white: 0.45, alpha: 1) }
}

final class KeyCap: UIView {
    let key: Key
    private let label = UILabel()
    private let image = UIImageView()
    var theme: Theme { didSet { restyle() } }
    var pressed = false { didSet { restyle() } }
    var lit = false { didSet { restyle() } } // shift on, etc.
    var fill: UIColor? { didSet { restyle() } } // e.g. blue for "send" / "search"
    var hitFrame: CGRect = .zero

    init(key: Key, theme: Theme) {
        self.key = key
        self.theme = theme
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.cornerRadius = 8.5
        layer.cornerCurve = .continuous
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        addSubview(label)
        image.contentMode = .center
        addSubview(image)
        setLabel(key.label, symbol: key.symbol)
        restyle()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setLabel(_ text: String, symbol: String?) {
        label.text = symbol == nil ? text : nil
        let isChar: Bool = { if case .char = key.kind { return true }; return false }()
        label.font = isChar && text.count == 1 ? .systemFont(ofSize: 25) : .systemFont(ofSize: 16)
        if let symbol {
            image.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .regular))
        } else {
            image.image = nil
        }
    }

    private func restyle() {
        let fn = key.function
        backgroundColor = pressed ? (fn ? theme.pressedFunction : theme.pressed)
            : (fill ?? (lit ? theme.key : (fn ? theme.functionKey : theme.key)))
        label.textColor = fill == nil ? theme.text : .white
        image.tintColor = fill == nil ? theme.text : .white
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        image.frame = bounds
    }
}

/// The keys. Draws its own key caps and handles touches itself, so the gaps between
/// keys still count (a touch goes to the nearest key) and fast typing with two thumbs
/// doesn't drop letters.
extension UIColor {
    /// Looks clear, but isn't: in a keyboard extension the system drops touches on fully
    /// transparent pixels, so a tap in the gap between two keys would vanish.
    static let touchable = UIColor(white: 0.5, alpha: 0.012)
}

final class KeyboardView: UIView {
    var onKey: ((KeyKind) -> Void)?
    var onDeleteRepeat: (() -> Void)?
    /// Globe key: the touch and event go to the system's keyboard switcher.
    var onGlobe: ((UIView, UIEvent?) -> Void)?
    /// Every key press (for haptics).
    var onTouch: (() -> Void)?
    /// How far above its top edge the keys still take touches (into the guess bar). Fast taps
    /// on the top row often land a little high, and the bar would swallow them.
    var reachUp: CGFloat = 0

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.inset(by: UIEdgeInsets(top: -reachUp, left: 0, bottom: 0, right: 0)).contains(point)
    }

    var theme = Theme(dark: false) { didSet { caps.forEach { $0.theme = theme }; popup.backgroundColor = theme.key; popupLabel.textColor = theme.text } }
    var showsGlobe = true { didSet { if oldValue != showsGlobe { rebuild() } } }
    var page: Page = .letters { didSet { if oldValue != page { rebuild() } } }
    var thai = true { didSet { if oldValue != thai { rebuild() } } }
    var shiftOn = false { didSet { refreshLetters() } }
    var capsLock = false { didSet { refreshLetters() } }
    var returnLabel = "return" { didSet { styleReturn() } }
    var compact = true // iPhone: show the letter popup

    private var caps: [KeyCap] = []
    private var rows: [[Key]] = []
    private var active: [UITouch: KeyCap] = [:]
    private var began: [UITouch: (at: CGPoint, time: TimeInterval)] = [:]
    private let log = Logger(subsystem: "com.kenpeeranat.ThaiPinyin", category: "keys")
    private var repeatTimer: Timer?
    private let popup = UIView()
    private let popupLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .touchable
        popup.isHidden = true
        popup.isUserInteractionEnabled = false
        popup.layer.cornerRadius = 8
        popup.layer.shadowColor = UIColor.black.cgColor
        popup.layer.shadowOpacity = 0.3
        popup.layer.shadowRadius = 2
        popup.layer.shadowOffset = CGSize(width: 0, height: 1)
        popupLabel.font = .systemFont(ofSize: 34)
        popupLabel.textAlignment = .center
        popup.addSubview(popupLabel)
        rebuild()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func letterRows() -> [[Key]] {
        let r1 = "qwertyuiop", r2 = "asdfghjkl", r3 = "zxcvbnm"
        func chars(_ s: String) -> [Key] { s.map { Key(kind: .char(String($0)), label: String($0)) } }
        let shift = Key(kind: .shift, label: "", symbol: "shift", function: true)
        return [chars(r1), chars(r2),
                [shift] + chars(r3) + [Key(kind: .delete, label: "", symbol: "delete.left", function: true)]]
    }

    private func numberRows() -> [[Key]] {
        func chars(_ s: [String]) -> [Key] { s.map { Key(kind: .char($0), label: $0) } }
        let punct = chars([".", ",", "?", "!", "'"])
        let del = Key(kind: .delete, label: "", symbol: "delete.left", function: true)
        if page == .numbers {
            return [chars(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
                    chars(["-", "/", ":", ";", "(", ")", "฿", "&", "@", "\""]),
                    [Key(kind: .page(.symbols), label: "#+=", function: true)] + punct + [del]]
        }
        return [chars(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]),
                chars(["_", "\\", "|", "~", "<", ">", "$", "€", "£", "•"]),
                [Key(kind: .page(.numbers), label: "123", function: true)] + punct + [del]]
    }

    private func bottomRow() -> [Key] {
        var row: [Key] = [page == .letters ? Key(kind: .page(.numbers), label: "123", function: true)
                                           : Key(kind: .page(.letters), label: "abc", function: true)]
        if showsGlobe { row.append(Key(kind: .globe, label: "", symbol: "globe", function: true)) }
        row.append(Key(kind: .toggleMode, label: thai ? "EN" : "ไทย", function: true))
        row.append(Key(kind: .space, label: ""))
        row.append(Key(kind: .ret, label: returnLabel, function: true))
        return row
    }

    func rebuild() {
        caps.forEach { $0.removeFromSuperview() }
        active.removeAll()
        rows = (page == .letters ? letterRows() : numberRows()) + [bottomRow()]
        caps = rows.flatMap { $0 }.map { KeyCap(key: $0, theme: theme) }
        caps.forEach { insertSubview($0, belowSubview: popup) }
        if popup.superview == nil { addSubview(popup) }
        refreshLetters()
        styleReturn()
        setNeedsLayout()
    }

    /// Like Apple's: a ↩ key normally, a blue labelled key for "send", "search", "go"...
    private func styleReturn() {
        guard let cap = caps.first(where: { $0.key.kind == .ret }) else { return }
        let plain = returnLabel == "return"
        cap.setLabel(plain ? "" : returnLabel, symbol: plain ? "return" : nil)
        cap.fill = plain ? nil : .systemBlue
    }

    private func refreshLetters() {
        let upper = !thai && (shiftOn || capsLock)
        for cap in caps {
            if case .char(let c) = cap.key.kind, page == .letters { cap.setLabel(upper ? c.uppercased() : c, symbol: nil) }
            if cap.key.kind == .shift {
                cap.setLabel("", symbol: capsLock ? "capslock.fill" : (shiftOn ? "shift.fill" : "shift"))
                cap.lit = !thai && (shiftOn || capsLock)
                cap.alpha = thai ? 0.35 : 1 // letters are always lowercase sounds in Thai mode
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let W = bounds.width, H = bounds.height
        guard W > 0, H > 0, !rows.isEmpty else { return }
        let side: CGFloat = W > 500 ? 8 : 5
        let gap: CGFloat = W > 500 ? 10 : 6
        // The rows sit where Apple's keyboard has them on screen. People switch between the two
        // keyboards and their thumbs aim by habit; with our rows up to 12 pt higher, taps landed
        // low: on the row below, or under the space bar in the system's globe and mic strip,
        // which keeps them. Measured on iOS 26 against the bottom edge of this view (iPhone 17
        // Pro, iPad Air 11-inch): distance from the top to the first row, key height, gap between
        // rows, room under the last row. The last row takes whatever height is left (on a phone
        // in portrait Apple's space bar runs 4 pt past this view, so ours is that much shorter).
        let pad = traitCollection.userInterfaceIdiom == .pad
        let apple: (top: CGFloat, key: CGFloat, gap: CGFloat, bottom: CGFloat) =
            pad ? (W > 900 ? (4.5, 72, 12.3, 11) : (16.5, 54.5, 9.25, 8))
                : (W > 500 ? (8.3, 32, 8, 1.7) : (15.3, 42, 12, 0.5))
        // Only when this view has the height those numbers were measured for (not a floating
        // or split iPad keyboard, not a page with another number of rows).
        let fits = rows.count == 4 && abs(apple.top + 4 * apple.key + 3 * apple.gap + apple.bottom - H) <= 6
        let top: CGFloat = fits ? apple.top : 6, bottom: CGFloat = fits ? apple.bottom : 6
        let rowGap: CGFloat = fits ? apple.gap : (H > 260 ? 12 : (H > 180 ? 11 : 6))
        let keyH = fits ? apple.key : (H - top - bottom - rowGap * CGFloat(rows.count - 1)) / CGFloat(rows.count)
        let keyW = (W - 2 * side - 9 * gap) / 10
        var i = 0
        for (r, row) in rows.enumerated() {
            let y = top + CGFloat(r) * (keyH + rowGap)
            let keyH = r == rows.count - 1 ? H - bottom - y : keyH // the last row takes what is left
            var frames: [CGRect] = []
            if r == rows.count - 1 {
                // Bottom row: fixed-width keys, space takes what's left.
                let fixed: [CGFloat] = row.map {
                    switch $0.kind {
                    case .space: return 0
                    case .ret: return keyW * 2.3 + gap
                    default: return keyW * 1.2
                    }
                }
                let spaceW = W - 2 * side - fixed.reduce(0, +) - gap * CGFloat(row.count - 1)
                var x = side
                for (k, key) in row.enumerated() {
                    let w = key.kind == .space ? spaceW : fixed[k]
                    frames.append(CGRect(x: x, y: y, width: w, height: keyH)); x += w + gap
                }
            } else if row.first?.function == true {
                // Shift / page key, centred characters, delete.
                let n = CGFloat(row.count - 2)
                let charW = page == .letters ? keyW : (W - 2 * side - 4 * gap - 2 * keyW * 1.4) / n - gap
                let mid = n * charW + (n - 1) * gap
                let start = (W - mid) / 2
                let sideW = max(keyW, start - side - gap * 1.5)
                frames.append(CGRect(x: side, y: y, width: sideW, height: keyH))
                for k in 0..<Int(n) { frames.append(CGRect(x: start + CGFloat(k) * (charW + gap), y: y, width: charW, height: keyH)) }
                frames.append(CGRect(x: W - side - sideW, y: y, width: sideW, height: keyH))
            } else {
                let n = CGFloat(row.count)
                let start = (W - (n * keyW + (n - 1) * gap)) / 2
                for k in 0..<row.count { frames.append(CGRect(x: start + CGFloat(k) * (keyW + gap), y: y, width: keyW, height: keyH)) }
            }
            for (k, f) in frames.enumerated() {
                let cap = caps[i]
                cap.frame = f.integral
                // Touch area: half the gap around each key; the outer keys reach the edges.
                var hit = f.insetBy(dx: -gap / 2, dy: -rowGap / 2)
                if k == 0 { hit.origin.x = 0; hit.size.width = f.maxX + gap / 2 }
                if k == frames.count - 1 { hit.size.width = W - hit.minX }
                if r == 0 { hit.size.height += hit.minY; hit.origin.y = 0 }
                if r == rows.count - 1 { hit.size.height = H - hit.minY }
                cap.hitFrame = hit
                i += 1
            }
        }
    }

    private func cap(at p: CGPoint) -> KeyCap? {
        if let c = caps.first(where: { $0.hitFrame.contains(p) }) { return c }
        // Nearest key otherwise.
        return caps.min { dist($0.frame, p) < dist($1.frame, p) }
    }

    private func dist(_ r: CGRect, _ p: CGPoint) -> CGFloat {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX), dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return dx * dx + dy * dy
    }

    // MARK: touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let c = cap(at: t.location(in: self)) else { KeyLog.note("down nokey"); continue }
            KeyLog.note("down \(c.key.label) y=\(Int(t.location(in: self).y)) active=\(active.count) inSet=\(touches.count) late=\(Int((ProcessInfo.processInfo.systemUptime - t.timestamp) * 1000))ms")
            // A second finger lands before the first lifts: type the first key now.
            for (other, oc) in active where oc.key.kind != .delete && oc.key.kind != .globe {
                KeyLog.note("rollover fires \(oc.key.label)")
                finish(other, oc, fire: true)
            }
            active[t] = c
            began[t] = (t.location(in: self), t.timestamp)
            c.pressed = true
            onTouch?()
            UIDevice.current.playInputClick()
            switch c.key.kind {
            case .delete:
                onKey?(.delete)
                repeatTimer?.invalidate()
                repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                    self?.repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { _ in self?.onDeleteRepeat?() }
                }
            case .globe:
                onGlobe?(self, event)
            case .char:
                showPopup(c)
            default: break
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let c = active[t] else { continue }
            if c.key.kind == .globe { onGlobe?(self, event); continue }
            if c.key.kind == .delete { continue }
            // Slide to another key before lifting: that key counts. Only for a deliberate press:
            // in fast typing the finger often drifts onto a neighbour as it lifts (i -> j).
            guard let b = began[t], t.timestamp - b.time >= 0.15 else { continue }
            if let n = cap(at: t.location(in: self)), n !== c, n.key.kind != .delete, n.key.kind != .globe {
                KeyLog.note("slide \(c.key.label) -> \(n.key.label)")
                c.pressed = false
                n.pressed = true
                active[t] = n
                if case .char = n.key.kind { showPopup(n) } else { popup.isHidden = true }
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let c = active[t] else { KeyLog.note("up (already typed)"); continue }
            KeyLog.note("up \(c.key.label) held=\(Int((t.timestamp - (began[t]?.time ?? t.timestamp)) * 1000))ms")
            if c.key.kind == .globe { onGlobe?(self, event) }
            finish(t, c, fire: true)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let c = active[t] else { continue }
            // iOS sometimes takes a touch away mid-tap when typing fast (it is checking for a
            // system swipe). A short touch that hasn't moved was a tap: it still types.
            var tapped = false
            if let b = began[t], c.key.kind != .globe {
                let p = t.location(in: self)
                tapped = t.timestamp - b.time < 0.4 && abs(p.x - b.at.x) < 14 && abs(p.y - b.at.y) < 14
            }
            log.notice("touch cancelled, typed anyway: \(tapped)")
            KeyLog.note("CANCELLED \(c.key.label) typed=\(tapped)")
            finish(t, c, fire: tapped)
        }
    }

    private func finish(_ t: UITouch, _ c: KeyCap, fire: Bool) {
        active[t] = nil
        began[t] = nil
        c.pressed = false
        if c.key.kind == .delete { repeatTimer?.invalidate(); repeatTimer = nil }
        if active.values.allSatisfy({ if case .char = $0.key.kind { return false }; return true }) { popup.isHidden = true }
        guard fire else { return }
        switch c.key.kind {
        case .delete, .globe: break // handled on touch down
        default: onKey?(c.key.kind)
        }
    }

    private func showPopup(_ c: KeyCap) {
        guard compact, case .char(let ch) = c.key.kind else { return }
        let upper = !thai && (shiftOn || capsLock) && page == .letters
        popupLabel.text = upper ? ch.uppercased() : ch
        let f = c.frame
        let w = f.width + 20, h = f.height + 14
        var x = f.midX - w / 2
        x = min(max(x, 2), bounds.width - w - 2)
        popup.frame = CGRect(x: x, y: f.minY - h + 4, width: w, height: h)
        popupLabel.frame = popup.bounds
        popup.isHidden = false
        bringSubviewToFront(popup)
    }
}
