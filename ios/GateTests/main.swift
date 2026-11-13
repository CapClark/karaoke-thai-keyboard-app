// Free-plan limit logic (Keyboard/Gate.swift). Run:
//   swiftc Keyboard/Gate.swift GateTests/main.swift -o /tmp/gatetest && /tmp/gatetest
import Foundation
func check(_ c: Bool, _ m: String) { print(c ? "ok  " : "FAIL", m); if !c { failed = true } }
var failed = false
let d = UserDefaults(suiteName: "gatetest")!; d.removePersistentDomain(forName: "gatetest")
var t = Date(timeIntervalSince1970: 1_800_000_000)
let off = Gate(defaults: d, now: { t })
check(off.mayConvert && off.remainingToday == nil, "switched off: no limit")
let g = Gate(defaults: d, now: { t }, active: true)
check(g.inTrial && g.remainingToday == nil, "first day: trial, no limit")
t += 8 * 86_400
check(!g.inTrial && g.remainingToday == 50, "after trial: 50 a day")
for _ in 0..<50 { g.didConvert() }
check(!g.mayConvert && g.remainingToday == 0, "50 used: blocked")
t += 86_400
check(g.mayConvert && g.remainingToday == 50, "next day: 50 again")
g.unlocked = true
check(g.mayConvert && g.remainingToday == nil, "unlocked: no limit")
exit(failed ? 1 : 0)
