// Free-plan limit logic (Keyboard/Gate.swift). Run:
//   swiftc Keyboard/Gate.swift Shared/SharedState.swift GateTests/main.swift -o /tmp/gatetest && /tmp/gatetest
import Foundation
func check(_ c: Bool, _ m: String) { print(c ? "ok  " : "FAIL", m); if !c { failed = true } }
var failed = false
let d = UserDefaults(suiteName: "gatetest")!; d.removePersistentDomain(forName: "gatetest")
var t = Date(timeIntervalSince1970: 1_800_000_000)
let off = Gate(defaults: d, now: { t }, active: false, shared: false, vault: nil)
check(off.mayConvert && off.remainingToday == nil, "switched off: no limit")
let g = Gate(defaults: d, now: { t }, active: true, shared: false, vault: nil)
check(g.inTrial && g.remainingToday == nil, "first day: trial, no limit")
t += 8 * 86_400
check(!g.inTrial && g.remainingToday == 50, "after trial: 50 a day")
for _ in 0..<50 { g.didConvert() }
check(!g.mayConvert && g.remainingToday == 0, "50 used: blocked")
t += 86_400
check(g.mayConvert && g.remainingToday == 50, "next day: 50 again")
g.unlocked = true
check(g.mayConvert && g.remainingToday == nil, "unlocked: no limit")

// Ways around the limit.
final class MemoryVault: GateVault {
    var data: Data?
    func read() -> Data? { data }
    func write(_ d: Data) { data = d }
}
func fresh(_ name: String) -> UserDefaults { let u = UserDefaults(suiteName: name)!; u.removePersistentDomain(forName: name); return u }
let vault = MemoryVault()
var t2 = Date(timeIntervalSince1970: 1_800_000_000)
var d2 = fresh("gatetest2")
var g2 = Gate(defaults: d2, now: { t2 }, active: true, shared: false, vault: vault)
check(g2.inTrial, "new install: trial")
t2 += 8 * 86_400
check(g2.remainingToday == 50, "trial over")
for _ in 0..<50 { g2.didConvert() }
check(!g2.mayConvert, "50 used")

t2 -= 3 * 86_400
check(!g2.mayConvert && !g2.inTrial, "clock set back 3 days: still blocked, no trial")
t2 -= 30 * 86_400
check(!g2.mayConvert && !g2.inTrial, "clock set back before the install: still blocked, no trial")
t2 += 33 * 86_400

d2 = fresh("gatetest2") // app deleted and installed again: defaults gone, Keychain kept
g2 = Gate(defaults: d2, now: { t2 }, active: true, shared: false, vault: vault)
check(!g2.inTrial, "reinstall: no new trial")
check(!g2.mayConvert, "reinstall the same day: still blocked")
t2 += 86_400
check(g2.remainingToday == 50, "next real day: 50 again")

g2.didConvert(letters: 48)
check(g2.remainingToday == 43, "48 letters in one go count as 7 words")
g2.didConvert(letters: 5)
check(g2.remainingToday == 42, "a short word counts as 1")
for _ in 0..<6 { g2.didConvert(letters: 48) }
check(g2.remainingToday == 0 && !g2.mayConvert, "long conversions use the day up, never below 0")

let g3 = Gate(defaults: fresh("gatetest3"), now: { t2 }, active: true, shared: false, vault: nil)
check(g3.inTrial && g3.mayConvert, "no Keychain asked for: works from defaults alone")

struct LockedVault: GateVault { // Full Access off: the Keychain refuses
    func read() -> Data? { nil }
    func write(_ d: Data) {}
}
var d4 = fresh("gatetest4")
var g4 = Gate(defaults: d4, now: { t2 }, active: true, shared: false, vault: LockedVault())
check(!g4.inTrial && g4.remainingToday == 50, "Keychain unreachable: no trial, 50 a day from the start")
for _ in 0..<50 { g4.didConvert() }
check(!g4.mayConvert, "Keychain unreachable: blocked after 50")
let v4 = MemoryVault()
g4 = Gate(defaults: d4, now: { t2 }, active: true, shared: false, vault: v4)
check(g4.inTrial && g4.mayConvert, "Full Access turned on: the trial applies")
g4 = Gate(defaults: d4, now: { t2 }, active: true, shared: false, vault: LockedVault())
check(!g4.mayConvert, "Full Access off again: back to today's count, still used up")
exit(failed ? 1 : 0)
