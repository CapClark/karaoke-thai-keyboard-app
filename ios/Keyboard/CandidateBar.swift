import UIKit

/// The strip above the keys: the letters typed so far (tap to keep them as English),
/// then the Thai guesses, best first (tap to pick). Scrolls sideways for more.
final class CandidateBar: UIView {
    var onPick: ((Int) -> Void)?
    var onKeepLetters: (() -> Void)?
    var onTouch: (() -> Void)?
    var onPalette: (() -> Void)?
    var theme = Theme(dark: false) { didSet { if theme.dark != oldValue.dark || theme.palette != oldValue.palette { rebuildItems() }; render() } }
    private let paletteButton = UIButton(type: .system)

    private let typed = UIButton(type: .custom)
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let hint = UILabel()
    private let divider = UIView()
    private var input = ""
    private var items: [Candidate] = []
    private var loading = false
    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        typed.titleLabel?.font = .systemFont(ofSize: 16)
        typed.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 8)
        typed.addTarget(self, action: #selector(keep), for: .touchUpInside)
        typed.accessibilityHint = "Types these English letters"
        addSubview(typed)
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        scroll.delaysContentTouches = false
        if #available(iOS 26.0, *) {
            // The new edge blur covers the whole strip when it's this short.
            scroll.topEdgeEffect.isHidden = true
            scroll.bottomEdgeEffect.isHidden = true
            scroll.leftEdgeEffect.isHidden = true
            scroll.rightEdgeEffect.isHidden = true
        }
        addSubview(scroll)
        stack.axis = .horizontal
        stack.spacing = 0
        stack.alignment = .fill
        scroll.addSubview(stack)
        hint.font = .systemFont(ofSize: 14)
        hint.text = "พิมพ์ตามเสียง · type Thai by sound"
        addSubview(hint)
        paletteButton.setImage(UIImage(systemName: "paintpalette"), for: .normal)
        paletteButton.accessibilityLabel = "Keyboard colours"
        paletteButton.addTarget(self, action: #selector(palette), for: .touchUpInside)
        addSubview(paletteButton)
        addSubview(divider)
        render()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// A one-off message in place of the hint (e.g. the free plan's daily limit), until the next letter.
    func showNotice(_ text: String) {
        hint.text = text
        hint.numberOfLines = 2
        hint.font = .systemFont(ofSize: 12)
        hint.adjustsFontSizeToFitWidth = true
        hint.minimumScaleFactor = 0.7
        hint.isHidden = false
        noticeShown = true
    }
    private var noticeShown = false

    /// `loading`: the guesses shown are for fewer letters; keep them until the new ones arrive.
    func show(input: String, candidates: [Candidate], loading: Bool) {
        if noticeShown && !input.isEmpty {
            noticeShown = false
            hint.text = "พิมพ์ตามเสียง · type Thai by sound"
            hint.numberOfLines = 1
            hint.font = .systemFont(ofSize: 14)
        }
        // The left-over letters shown after a guess depend on the input too.
        let changed = input != self.input || candidates.count != items.count
            || !zip(candidates, items).allSatisfy { $0.text == $1.text && $0.consume == $1.consume }
        self.input = input
        self.loading = loading
        if changed { items = candidates; rebuildItems(); scroll.contentOffset = .zero }
        render()
    }

    private func rebuildItems() {
        // Buttons are kept and relabelled: making 36 new ones on every letter held the keys up.
        while buttons.count < items.count {
            let b = UIButton(type: .custom)
            b.tag = buttons.count
            b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
            b.layer.cornerRadius = 6
            b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            buttons.append(b)
            stack.addArrangedSubview(b)
        }
        for (i, b) in buttons.enumerated() where b.isHidden != (i >= items.count) { b.isHidden = i >= items.count }
        for (i, c) in items.enumerated() {
            let b = buttons[i]
            let title = NSMutableAttributedString(string: c.text, attributes: [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: theme.text,
            ])
            if c.consume < input.count {
                // A phrase or word that covers only the first letters: show what's left over.
                let rest = String(input.dropFirst(c.consume))
                title.append(NSAttributedString(string: " +" + rest, attributes: [
                    .font: UIFont.systemFont(ofSize: 12), .foregroundColor: theme.muted]))
            }
            if b.attributedTitle(for: .normal) != title { b.setAttributedTitle(title, for: .normal) }
            b.accessibilityLabel = c.text
        }
        setNeedsLayout()
    }

    private func render() {
        backgroundColor = .clear
        divider.backgroundColor = .clear
        typed.setTitle(input, for: .normal)
        typed.setTitleColor(theme.muted, for: .normal)
        typed.isHidden = input.isEmpty
        scroll.isHidden = input.isEmpty
        hint.isHidden = !input.isEmpty
        hint.textColor = theme.muted
        paletteButton.isHidden = !input.isEmpty
        paletteButton.tintColor = theme.muted
        stack.alpha = loading ? 0.5 : 1
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let h = bounds.height
        let tw = min(typed.intrinsicContentSize.width, bounds.width * 0.4)
        typed.frame = CGRect(x: 0, y: 0, width: input.isEmpty ? 0 : tw, height: h)
        scroll.frame = CGRect(x: typed.frame.maxX, y: 0, width: bounds.width - typed.frame.maxX, height: h)
        let size = stack.systemLayoutSizeFitting(CGSize(width: UIView.layoutFittingCompressedSize.width, height: h - 8))
        stack.frame = CGRect(x: 0, y: 4, width: size.width, height: h - 8)
        scroll.contentSize = CGSize(width: size.width + 8, height: h)
        paletteButton.frame = CGRect(x: bounds.width - 44, y: 0, width: 44, height: h)
        hint.frame = CGRect(x: 12, y: 0, width: bounds.width - 12 - 44, height: h)
        divider.frame = CGRect(x: 0, y: h - 0.5, width: bounds.width, height: 0.5)
    }

    @objc private func tapped(_ b: UIButton) {
        onTouch?()
        UIDevice.current.playInputClick()
        onPick?(b.tag)
    }

    @objc private func palette() {
        onTouch?()
        UIDevice.current.playInputClick()
        onPalette?()
    }

    @objc private func keep() {
        onTouch?()
        UIDevice.current.playInputClick()
        onKeepLetters?()
    }
}
