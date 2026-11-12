import Foundation
import CoreGraphics
import AppKit
let codes: [Character: CGKeyCode] = ["a":0,"s":1,"d":2,"f":3,"h":4,"g":5,"z":6,"x":7,"c":8,"v":9,"b":11,"q":12,"w":13,"e":14,"r":15,"y":16,"t":17,"o":31,"u":32,"i":34,"p":35,"l":37,"j":38,"k":40,"n":45,"m":46," ":49,"R":36]
let src = CGEventSource(stateID: .hidSystemState)
func key(_ c: CGKeyCode) {
  CGEvent(keyboardEventSource: src, virtualKey: c, keyDown: true)?.post(tap: .cghidEventTap)
  usleep(25_000)
  CGEvent(keyboardEventSource: src, virtualKey: c, keyDown: false)?.post(tap: .cghidEventTap)
}
// script: letters typed at a steady pace; "|" = pause
let script = CommandLine.arguments[1]
for ch in script {
  if ch == "|" { usleep(700_000); continue }
  guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" else { print("TextEdit not in front; stopped"); exit(2) }
  guard let c = codes[ch] else { continue }
  key(c)
  usleep(ch == " " || ch == "R" ? 450_000 : 120_000)
}
