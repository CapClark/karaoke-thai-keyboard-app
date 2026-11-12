import Cocoa
import InputMethodKit

/// One instance per text field / app. Holds the romanized letters being typed
/// (shown underlined in the app) and turns them into Thai on Space or 1–9.
///
/// Keys while typing:
///   letters        add to the input          Space / 1    take the highlighted / first guess
///   2–9            take that guess           ← → ↑ ↓ Tab  move the highlight
///   - =  , .  PgUp PgDn   previous / next page of guesses
///   Return         take the highlighted guess           Shift+Return  type the letters as English
///   Esc            throw the letters away
///   Delete         remove the last letter    punctuation  take the highlighted guess, then type it
/// Tap Shift alone, or turn on Caps Lock, to type English.
@objc(ThaiPinyinInputController)
final class ThaiPinyinInputController: IMKInputController {
    private static let pageSize = 9
    private static let maxBuffer = 48

    private var buffer = ""
    private var candidates: [Candidate] = []
    private var selected = 0 // index into `candidates`
    // macOS makes one controller per text field, so the mode is shared.
    private static var englishMode = false
    private var shiftDownAt: TimeInterval?
    private var lastWasRepeat = false
    private var clientShowsMarkedText = false // some apps never report underlined text
    private var previousWord: String? // last Thai word we typed, for word-pair ranking

    private let noRange = NSRange(location: NSNotFound, length: 0)

    override func recognizedEvents(_ sender: Any!) -> Int {
        Int(NSEvent.EventTypeMask([.keyDown, .flagsChanged]).rawValue)
    }

    override func activateServer(_ sender: Any!) {
        super.activateServer(sender)
        previousWord = nil
    }

    override func deactivateServer(_ sender: Any!) {
        commitComposition(sender)
        CandidateWindow.shared.hide()
        super.deactivateServer(sender)
    }

    // The app threw our underlined text away (clicked elsewhere, cleared the box).
    override func cancelComposition() {
        buffer = ""
        candidates = []
        CandidateWindow.shared.hide()
        super.cancelComposition()
    }

    // App switched focus or asked us to finish: keep what was typed as English.
    // If that happens because a guess in the bar was clicked, use the clicked guess.
    override func commitComposition(_ sender: Any!) {
        guard let client = sender as? IMKTextInput, !buffer.isEmpty else { return }
        if NSEvent.pressedMouseButtons != 0,
           let i = CandidateWindow.shared.index(atScreenPoint: NSEvent.mouseLocation) {
            pick(pageStart + i, client: client)
            if !buffer.isEmpty { commit(buffer, client: client) }
            return
        }
        commit(buffer, client: client)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let client = sender as? IMKTextInput else { return false }

        if event.type == .flagsChanged {
            handleShiftTap(event, client: client)
            return false
        }
        shiftDownAt = nil
        guard event.type == .keyDown else { return false }

        // The app dropped our underlined letters without telling us: start fresh.
        if !buffer.isEmpty, clientShowsMarkedText, client.markedRange().location == NSNotFound {
            buffer = ""
            candidates = []
            CandidateWindow.shared.hide()
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        // Shortcuts (⌘C, ⌃A…) belong to the app; keep the letters as typed.
        if !flags.intersection([.command, .control, .option]).isEmpty {
            if !buffer.isEmpty { commit(buffer, client: client) }
            previousWord = nil
            return false
        }
        if Self.englishMode || flags.contains(.capsLock) {
            if !buffer.isEmpty { commit(buffer, client: client) }
            return false
        }

        var chars = event.characters ?? ""
        let keyCode = event.keyCode
        lastWasRepeat = event.isARepeat
        // Number row by physical key, so AZERTY (& é " ' …) can still pick guesses.
        if !buffer.isEmpty, !flags.contains(.shift), let d = Self.numberRow[keyCode] { chars = String(d) }

        // Letters always go into the input.
        if chars.count == 1, let ch = chars.first, ch.isASCII, ch.isLetter {
            if buffer.count >= Self.maxBuffer {
                NSSound.beep() // too long to convert sensibly; ignore extra letters
                return true
            }
            buffer.append(Character(ch.lowercased()))
            selected = 0
            update(client)
            return true
        }

        guard !buffer.isEmpty else {
            // Not composing. Anything that moves the caret or ends a line breaks the word pair.
            if [36, 76, 48, 123, 124, 125, 126, 115, 119, 116, 121].contains(keyCode) || !(chars.first?.isLetter ?? false) {
                previousWord = nil
            }
            return false
        }

        switch keyCode {
        case 51: // delete
            buffer.removeLast()
            selected = 0
            update(client)
            return true
        case 117: // forward delete: nothing to delete after the caret inside the input
            return true
        case 49: // space
            if candidates.isEmpty {
                commit(buffer, client: client)
                return false // no guess: keep letters and still type the space
            }
            pick(selected, client: client)
            return true
        case 36, 76: // return / enter: take the highlighted guess; Shift+Return keeps the English letters
            if flags.contains(.shift) || candidates.isEmpty {
                commit(buffer, client: client)
            } else {
                pick(selected, client: client)
            }
            return true
        case 53: // escape
            buffer = ""
            update(client)
            return true
        case 124, 125, 48: // right, down, tab
            move(1, client: client)
            return true
        case 123, 126: // left, up
            move(-1, client: client)
            return true
        case 121: // page down
            page(1, client: client)
            return true
        case 116: // page up
            page(-1, client: client)
            return true
        default:
            break
        }

        switch chars {
        case "=", ".": if candidates.count > Self.pageSize { page(1, client: client); return true }
        case "-", ",": if candidates.count > Self.pageSize { page(-1, client: client); return true }
        default: break
        }

        if let d = Int(chars), (1...9).contains(d) {
            let index = pageStart + d - 1
            if index < candidates.count {
                pick(index, client: client)
                return true
            }
            commit(buffer, client: client) // no such guess: keep letters, type the digit
            return false
        }

        // Home, End, F-keys and other function keys: keep the letters as typed.
        if let u = chars.unicodeScalars.first?.value, (0xF700...0xF8FF).contains(u) || chars.isEmpty {
            commit(buffer, client: client)
            return false
        }

        // Punctuation etc.: take the highlighted guess, then let the key type itself.
        if !candidates.isEmpty { pick(selected, client: client) }
        if !buffer.isEmpty { commit(buffer, client: client) }
        previousWord = nil
        return false
    }

    // MARK: - Shift tap toggles English

    // A real tap: Shift pressed and released within 0.4 s, nothing else pressed,
    // no mouse button held (Shift-click to select text must not switch modes).
    private func handleShiftTap(_ event: NSEvent, client: IMKTextInput) {
        let flags = event.modifierFlags.intersection([.shift, .command, .control, .option])
        if flags == .shift {
            shiftDownAt = NSEvent.pressedMouseButtons == 0 ? event.timestamp : nil
        } else if flags.isEmpty, let down = shiftDownAt {
            shiftDownAt = nil
            guard event.timestamp - down < 0.4, NSEvent.pressedMouseButtons == 0 else { return }
            if !buffer.isEmpty { commit(buffer, client: client) }
            Self.englishMode.toggle()
            CandidateWindow.shared.flash(Self.englishMode ? "English" : "ไทย", near: caretRect(client))
        } else {
            shiftDownAt = nil
        }
    }

    private static let numberRow: [UInt16: Character] = [
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
    ]

    // MARK: - Candidates

    private var pageStart: Int { (selected / Self.pageSize) * Self.pageSize }

    private func move(_ step: Int, client: IMKTextInput) {
        guard !candidates.isEmpty else { return }
        selected = (selected + step + candidates.count) % candidates.count
        show(client)
    }

    private func page(_ step: Int, client: IMKTextInput) {
        guard !candidates.isEmpty else { return }
        let pages = (candidates.count + Self.pageSize - 1) / Self.pageSize
        let p = (selected / Self.pageSize + step + pages) % pages
        selected = p * Self.pageSize
        show(client)
    }

    private func update(_ client: IMKTextInput) {
        if buffer.isEmpty {
            candidates = []
            client.setMarkedText("", selectionRange: NSRange(location: 0, length: 0), replacementRange: noRange)
            CandidateWindow.shared.hide()
            return
        }
        candidates = Engine.shared.candidates(for: buffer, previous: previousWord, fast: lastWasRepeat)
        selected = min(selected, max(0, candidates.count - 1))

        let marked = NSAttributedString(string: buffer, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ])
        client.setMarkedText(marked, selectionRange: NSRange(location: buffer.utf16.count, length: 0),
                             replacementRange: noRange)
        clientShowsMarkedText = client.markedRange().location != NSNotFound
        show(client)
    }

    private func show(_ client: IMKTextInput) {
        let start = pageStart
        let pageItems = Array(candidates.dropFirst(start).prefix(Self.pageSize))
        let pages = max(1, (candidates.count + Self.pageSize - 1) / Self.pageSize)
        CandidateWindow.shared.onPick = { [weak self] i in
            self?.pick(start + i, client: client)
        }
        CandidateWindow.shared.show(input: buffer, candidates: pageItems, selected: selected - start,
                                    page: start / Self.pageSize + 1, pages: pages, caret: caretRect(client))
    }

    private func caretRect(_ client: IMKTextInput) -> NSRect {
        var rect = NSRect.zero
        client.attributes(forCharacterIndex: 0, lineHeightRectangle: &rect)
        // Some apps don't report a caret position; fall back to the mouse.
        if rect.origin == .zero || !rect.origin.x.isFinite || !rect.origin.y.isFinite {
            rect = NSRect(origin: NSEvent.mouseLocation, size: NSSize(width: 0, height: 18))
        }
        return rect
    }

    private func pick(_ i: Int, client: IMKTextInput) {
        guard candidates.indices.contains(i) else {
            NSLog("ThaiPinyin: pick \(i) out of range (\(candidates.count) guesses)")
            return
        }
        let c = candidates[i]
        Engine.shared.learn(c.text, previous: previousWord, kind: c.kind)
        client.insertText(c.text, replacementRange: noRange)
        previousWord = c.text
        buffer = String(buffer.dropFirst(max(1, min(c.consume, buffer.count))))
        selected = 0
        update(client)
    }

    private func commit(_ text: String, client: IMKTextInput) {
        client.insertText(text, replacementRange: noRange)
        buffer = ""
        previousWord = nil
        update(client)
    }
}
