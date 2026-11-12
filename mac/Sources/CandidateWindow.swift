import Cocoa

/// Small floating bar under the cursor: romanized input on top, numbered Thai guesses below.
final class CandidateWindow: NSObject {
    static let shared = CandidateWindow()

    private let panel: NSPanel
    private let inputLabel = NSTextField(labelWithString: "")
    private let row = NSStackView()
    private let stack = NSStackView()
    private let pageLabel = NSTextField(labelWithString: "")
    private let header = NSStackView()
    /// Called with the index (on the current page) of a guess clicked with the mouse.
    var onPick: ((Int) -> Void)?
    private var flashTimer: Timer?

    private override init() {
        panel = NSPanel(contentRect: .zero,
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: true)
        super.init()
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.becomesKeyOnlyIfNeeded = true
        panel.isFloatingPanel = true

        let bg = NSVisualEffectView()
        bg.material = .popover
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 9
        bg.layer?.masksToBounds = true

        inputLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        inputLabel.textColor = .systemOrange

        row.orientation = .horizontal
        row.spacing = 4
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 3
        stack.edgeInsets = NSEdgeInsets(top: 6, left: 8, bottom: 7, right: 8)
        pageLabel.font = .systemFont(ofSize: 10)
        pageLabel.textColor = .tertiaryLabelColor
        header.orientation = .horizontal
        header.spacing = 8
        header.addArrangedSubview(inputLabel)
        header.addArrangedSubview(pageLabel)
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(row)

        bg.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            stack.topAnchor.constraint(equalTo: bg.topAnchor),
            stack.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
        ])
        panel.contentView = bg
    }

    func show(input: String, candidates: [Candidate], selected: Int, page: Int = 1, pages: Int = 1, caret: NSRect) {
        flashTimer?.invalidate()
        inputLabel.stringValue = input
        pageLabel.stringValue = pages > 1 ? "\(page)/\(pages)  − =" : ""
        pageLabel.isHidden = pages <= 1
        row.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if candidates.isEmpty {
            row.addArrangedSubview(cell("no match · Return keeps letters", index: nil, on: false, rest: nil))
        }
        for (i, c) in candidates.enumerated() {
            let rest = c.consume < input.count ? "+" + String(input.dropFirst(c.consume)) : nil
            let v = cell(c.text, index: i + 1, on: i == selected, rest: rest, fix: c.isCorrection) as! ClickCell
            v.onClick = { [weak self] in self?.onPick?(i) }
            row.addArrangedSubview(v)
        }
        place(caret: caret)
    }


    /// Briefly shows a mode label ("English" / "ไทย") near the caret.
    func flash(_ text: String, near caret: NSRect) {
        inputLabel.stringValue = ""
        pageLabel.isHidden = true
        row.arrangedSubviews.forEach { $0.removeFromSuperview() }
        row.addArrangedSubview(cell(text, index: nil, on: false, rest: nil))
        place(caret: caret)
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in self?.hide() }
    }

    private func place(caret: NSRect) {
        panel.contentView?.layoutSubtreeIfNeeded()
        let size = stack.fittingSize
        var origin = NSPoint(x: caret.minX, y: caret.minY - size.height - 4)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(caret.origin) }) ?? NSScreen.main {
            let vf = screen.visibleFrame
            origin.x = min(max(origin.x, vf.minX + 4), vf.maxX - size.width - 4)
            if origin.y < vf.minY { origin.y = caret.maxY + 4 } // no room below: flip above
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    /// Index (on the current page) of the guess under a screen point, if the bar is showing.
    func index(atScreenPoint p: NSPoint) -> Int? {
        guard panel.isVisible, panel.frame.contains(p) else { return nil }
        let local = panel.convertPoint(fromScreen: p)
        for (i, v) in row.arrangedSubviews.enumerated() where v is ClickCell {
            if v.convert(v.bounds, to: nil).contains(local) { return i }
        }
        return nil
    }

    func hide() {
        flashTimer?.invalidate()
        panel.orderOut(nil)
    }

    private func cell(_ text: String, index: Int?, on: Bool, rest: String?, fix: Bool = false) -> NSView {
        let s = NSMutableAttributedString()
        if let index {
            s.append(NSAttributedString(string: "\(index) ", attributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor,
            ]))
        }
        if fix { // a correction, not an exact match of what was typed
            s.append(NSAttributedString(string: "≈", attributes: [
                .font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.tertiaryLabelColor,
            ]))
        }
        s.append(NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: index == nil ? 12 : 18),
            .foregroundColor: index == nil ? NSColor.secondaryLabelColor : NSColor.labelColor,
        ]))
        if let rest {
            s.append(NSAttributedString(string: rest, attributes: [
                .font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.tertiaryLabelColor,
            ]))
        }
        let label = NSTextField(labelWithAttributedString: s)
        let box = ClickCell()
        box.wantsLayer = true
        box.layer?.cornerRadius = 5
        if on { box.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor }
        box.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 5),
            label.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -5),
            label.topAnchor.constraint(equalTo: box.topAnchor, constant: 1),
            label.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -1),
        ])
        return box
    }
}

/// A guess in the bar. Picks on mouse-down (not mouse-up) and accepts the very
/// first click, so the text field never loses focus before the pick lands.
final class ClickCell: NSView {
    var onClick: (() -> Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Labels inside shouldn't swallow the click.
        frame.contains(point) ? self : nil
    }
}
