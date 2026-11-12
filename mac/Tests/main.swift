// Keyboard tests: drives the real input controller with simulated key presses
// against a fake text field. Run by build.sh before installing.

import Cocoa
import InputMethodKit

// Fake text field that records what the input method does to it.
final class FakeClient: NSObject, IMKTextInput {
    var text = ""
    var marked = ""
    var reportsMarked = true
    func insertText(_ string: Any!, replacementRange: NSRange) { text += (string as? String) ?? (string as? NSAttributedString)?.string ?? ""; marked = "" }
    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) { marked = (string as? String) ?? (string as? NSAttributedString)?.string ?? "" }
    func selectedRange() -> NSRange { NSRange(location: text.utf16.count, length: 0) }
    func markedRange() -> NSRange { reportsMarked && !marked.isEmpty ? NSRange(location: text.utf16.count, length: marked.utf16.count) : NSRange(location: NSNotFound, length: 0) }
    func attributedSubstring(from range: NSRange) -> NSAttributedString! { NSAttributedString(string: "") }
    func length() -> Int { text.utf16.count }
    func characterIndex(for point: NSPoint, tracking mappingMode: IMKLocationToOffsetMappingMode, inMarkedRange: UnsafeMutablePointer<ObjCBool>!) -> Int { 0 }
    func attributes(forCharacterIndex index: Int, lineHeightRectangle: UnsafeMutablePointer<NSRect>!) -> [AnyHashable: Any]! { lineHeightRectangle.pointee = NSRect(x: 200, y: 400, width: 1, height: 18); return [:] }
    func validAttributesForMarkedText() -> [Any]! { [] }
    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {}
    func selectMode(_ modeIdentifier: String!) {}
    func supportsUnicode() -> Bool { true }
    func bundleIdentifier() -> String! { "test" }
    func windowLevel() -> CGWindowLevel { 0 }
    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { false }
    func uniqueClientIdentifierString() -> String! { "test" }
    func string(from range: NSRange, actualRange: NSRangePointer!) -> String! { "" }
    func firstRect(forCharacterRange aRange: NSRange, actualRange: NSRangePointer!) -> NSRect { .zero }
}

_ = NSApplication.shared
let server = IMKServer(name: "ThaiPinyinTest_Connection", bundleIdentifier: Bundle.main.bundleIdentifier)
_ = Engine.shared.candidates(for: "a")
var fails = 0
func check(_ name: String, _ ok: Bool, _ info: String = "") { if !ok { fails += 1; print("FAIL", name, info) } else { print("ok  ", name) } }

// keyCodes for US layout letters
let kc: [Character: UInt16] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"o":31,"u":32,"i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46]
func key(_ chars: String, code: UInt16, flags: NSEvent.ModifierFlags = [], t: TimeInterval = 0) -> NSEvent {
    NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: t, windowNumber: 0, context: nil,
                     characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)!
}
func flagsEv(_ flags: NSEvent.ModifierFlags, t: TimeInterval) -> NSEvent {
    NSEvent.keyEvent(with: .flagsChanged, location: .zero, modifierFlags: flags, timestamp: t, windowNumber: 0, context: nil,
                     characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: 56)!
}
func fresh() -> (ThaiPinyinInputController, FakeClient) {
    let c = FakeClient()
    let ctl = ThaiPinyinInputController(server: server, delegate: nil, client: nil)!
    return (ctl, c)
}
@discardableResult func type(_ ctl: ThaiPinyinInputController, _ c: FakeClient, _ s: String) -> [Bool] {
    s.map { ch in ctl.handle(key(String(ch), code: kc[ch] ?? 0), client: c) }
}
let space = { key(" ", code: 49) }

do { let (ctl, c) = fresh(); type(ctl, c, "sawatdeekrap"); check("marked text shows letters", c.marked == "sawatdeekrap", c.marked)
     _ = ctl.handle(space(), client: c); check("space commits phrase", c.text == "สวัสดีครับ" && c.marked == "", c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "kin"); _ = ctl.handle(space(), client: c); type(ctl, c, "khao"); _ = ctl.handle(space(), client: c)
     check("context: kin khao -> กินข้าว", c.text == "กินข้าว", c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "pomrakkun"); _ = ctl.handle(key("2", code: 19), client: c)
     check("digit 2 picks first word only, rest stays", c.text == "ผม" && c.marked == "rakkun", c.text + " / " + c.marked) }
do { let (ctl, c) = fresh(); type(ctl, c, "sawatdi"); _ = ctl.handle(key("\r", code: 36), client: c); check("return picks highlighted", c.text == "สวัสดี", c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "mai"); _ = ctl.handle(key("\t", code: 48), client: c); _ = ctl.handle(key("\r", code: 36), client: c)
     check("return picks the moved highlight", !c.text.isEmpty && c.text != "ไม่" && c.marked == "", c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "hello"); _ = ctl.handle(key("\r", code: 36, flags: .shift), client: c); check("shift-return keeps English", c.text == "hello", c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "zzqx"); _ = ctl.handle(key("\r", code: 36), client: c); check("return with no guess keeps letters", c.text == "zzqx", c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "abc"); _ = ctl.handle(key("\u{1b}", code: 53), client: c); check("esc clears", c.text == "" && c.marked == "") }
do { let (ctl, c) = fresh(); type(ctl, c, "kinx"); _ = ctl.handle(key("\u{7f}", code: 51), client: c); check("delete removes letter", c.marked == "kin", c.marked) }
do { let (ctl, c) = fresh(); type(ctl, c, "zzqx"); let r = ctl.handle(space(), client: c); check("space with no guess types letters + space", c.text == "zzqx" && r == false, "\(c.text) \(r)") }
do { let (ctl, c) = fresh(); type(ctl, c, "mai"); let r = ctl.handle(key("&", code: 18), client: c); check("AZERTY 1-key picks", c.text == "ไม่" && r == true, c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "mai"); let r = ctl.handle(key(String(UnicodeScalar(0xF729)!), code: 115), client: c); check("Home key keeps letters", c.text == "mai" && r == false, c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "mai"); let r = ctl.handle(key("c", code: 8, flags: .command), client: c); check("cmd shortcut keeps letters, passes key", c.text == "mai" && r == false) }
do { let (ctl, c) = fresh(); type(ctl, c, "mai"); let r = ctl.handle(key("!", code: 18, flags: .shift), client: c); check("punctuation commits guess then types", c.text == "ไม่" && r == false, c.text) }
do { let (ctl, c) = fresh(); type(ctl, c, "abc"); c.marked = ""; type(ctl, c, "d"); check("app dropped marked text: no ghost letters", c.marked == "d", c.marked) }
do { let (ctl, c) = fresh(); c.reportsMarked = false; type(ctl, c, "sawatdi"); check("app without marked-text support still composes", c.marked == "sawatdi", c.marked) }
do { let (ctl, c) = fresh(); type(ctl, c, String(repeating: "a", count: 60)); check("long input capped at 48", c.marked.count == 48 && c.text.isEmpty, "\(c.marked.count)") }
do { let (ctl, c) = fresh(); type(ctl, c, "khao"); for _ in 0..<12 { _ = ctl.handle(key("=", code: 24), client: c) }
     _ = ctl.handle(space(), client: c); check("paging then space commits something Thai", !c.text.isEmpty && c.text.unicodeScalars.allSatisfy { $0.value >= 0x0E00 && $0.value <= 0x0E7F }, c.text) }
do { let (ctl, c) = fresh()
     _ = ctl.handle(flagsEv(.shift, t: 1.0), client: c); _ = ctl.handle(flagsEv([], t: 1.1), client: c)
     let r = type(ctl, c, "hi"); check("shift tap -> English passes letters", r.allSatisfy { !$0 } && c.marked == "")
     _ = ctl.handle(flagsEv(.shift, t: 2.0), client: c); _ = ctl.handle(flagsEv([], t: 2.1), client: c)
     _ = ctl.handle(flagsEv(.shift, t: 3.0), client: c); _ = ctl.handle(flagsEv([], t: 3.9), client: c)
     type(ctl, c, "di"); check("tap back to Thai; long shift hold ignored", c.marked == "di", c.marked) }
do { let (ctl, c) = fresh(); type(ctl, c, "mai"); ctl.cancelComposition(); type(ctl, c, "pai"); check("cancelComposition resets", c.marked == "pai", c.marked) }
do { let (ctl, c) = fresh(); type(ctl, c, "sawat"); ctl.commitComposition(c); check("focus loss keeps letters", c.text == "sawat" && c.marked == "", c.text) }
do { let (ctl, c) = fresh(); let r = ctl.handle(key("1", code: 18), client: c); check("digits pass through when not typing", r == false && c.text == "") }
print(fails == 0 ? "controller: all pass" : "controller: \(fails) failed")
exit(fails == 0 ? 0 : 1)
