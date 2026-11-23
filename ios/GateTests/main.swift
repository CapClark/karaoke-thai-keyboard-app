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
check(!g.inTrial && g.remainingToday == Gate.dailyLimit, "after trial: \(Gate.dailyLimit) a day")
for _ in 0..<Gate.dailyLimit { g.didConvert() }
check(!g.mayConvert && g.remainingToday == 0, "all used: blocked")
t += 86_400
check(g.mayConvert && g.remainingToday == Gate.dailyLimit, "next day: all again")
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
check(g2.remainingToday == Gate.dailyLimit, "trial over")
for _ in 0..<Gate.dailyLimit { g2.didConvert() }
check(!g2.mayConvert, "all used")

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
check(g2.remainingToday == Gate.dailyLimit, "next real day: all again")

g2.didConvert(letters: 48)
check(g2.remainingToday == Gate.dailyLimit - 5, "48 letters in one go count as 5 words")
g2.didConvert(letters: 5)
check(g2.remainingToday == Gate.dailyLimit - 6, "a short word counts as 1")
for _ in 0..<Gate.dailyLimit { g2.didConvert(letters: 48) }
check(g2.remainingToday == 0 && !g2.mayConvert, "long conversions use the day up, never below 0")

let g3 = Gate(defaults: fresh("gatetest3"), now: { t2 }, active: true, shared: false, vault: nil)
check(g3.inTrial && g3.mayConvert, "no Keychain asked for: works from defaults alone")

struct LockedVault: GateVault { // Full Access off: the Keychain refuses
    func read() -> Data? { nil }
    func write(_ d: Data) {}
}
var d4 = fresh("gatetest4")
var g4 = Gate(defaults: d4, now: { t2 }, active: true, shared: false, vault: LockedVault())
check(!g4.inTrial && g4.remainingToday == Gate.dailyLimit, "Keychain unreachable: no trial, daily limit from the start")
for _ in 0..<Gate.dailyLimit { g4.didConvert() }
check(!g4.mayConvert, "Keychain unreachable: blocked after the limit")
let v4 = MemoryVault()
g4 = Gate(defaults: d4, now: { t2 }, active: true, shared: false, vault: v4)
check(g4.inTrial && g4.mayConvert, "Full Access turned on: the trial applies")
g4 = Gate(defaults: d4, now: { t2 }, active: true, shared: false, vault: LockedVault())
check(!g4.mayConvert, "Full Access off again: back to today's count, still used up")
// The keyboard's own purchase check: a refund locks again, "can't see it" does not.
let d5 = fresh("gatetest5")
let g5 = Gate(defaults: d5, now: { t2 }, active: true, shared: false, vault: nil)
g5.apply(owned: true, refunded: false)
check(g5.unlocked, "purchase seen: unlocked")
g5.apply(owned: false, refunded: false)
check(g5.unlocked, "purchase not visible (no StoreKit answer): stays unlocked")
g5.apply(owned: false, refunded: true)
check(!g5.unlocked, "refunded: locked again")
check(Gate.limitMessage.split(separator: "\n").allSatisfy { $0.count <= 52 }, "limit message: short lines")
// Rating request (Shared/SharedState.swift: Usage, RatingAsk).
let ud = fresh("usagetest")
var tu = Date(timeIntervalSince1970: 1_800_000_000)
for _ in 0..<20 { Usage.noteWord(now: tu, in: ud) }
check(Usage.words(in: ud) == 20 && Usage.days(in: ud) == 1, "usage: 20 words, 1 day")
tu += 86_400; Usage.noteWord(now: tu, in: ud)
tu -= 5 * 86_400; Usage.noteWord(now: tu, in: ud)
check(Usage.days(in: ud) == 2, "usage: clock set back adds no day")
let n = Date(timeIntervalSince1970: 1_900_000_000)
check(!RatingAsk.isDue(words: 29, keyboardDays: 5, appDays: 9, lastAsked: nil, limitHitAt: nil, now: n), "rating: too few words")
check(!RatingAsk.isDue(words: 300, keyboardDays: 2, appDays: 9, lastAsked: nil, limitHitAt: nil, now: n), "rating: too few days")
check(RatingAsk.isDue(words: 30, keyboardDays: 3, appDays: 1, lastAsked: nil, limitHitAt: nil, now: n), "rating: real use, asks")
check(!RatingAsk.isDue(words: 30, keyboardDays: 3, appDays: 1, lastAsked: n - 59 * 86_400, limitHitAt: nil, now: n), "rating: asked 59 days ago, waits")
check(RatingAsk.isDue(words: 30, keyboardDays: 3, appDays: 1, lastAsked: n - 61 * 86_400, limitHitAt: nil, now: n), "rating: asked 61 days ago, asks")
check(!RatingAsk.isDue(words: 30, keyboardDays: 3, appDays: 1, lastAsked: nil, limitHitAt: n - 3_600, now: n), "rating: limit hit an hour ago, waits")
check(!RatingAsk.isDue(words: 0, keyboardDays: 0, appDays: 3, lastAsked: nil, limitHitAt: nil, now: n), "rating: no Full Access, 3 app days, waits")
check(RatingAsk.isDue(words: 0, keyboardDays: 0, appDays: 4, lastAsked: nil, limitHitAt: nil, now: n), "rating: no Full Access, 4 app days, asks")
exit(failed ? 1 : 0)
