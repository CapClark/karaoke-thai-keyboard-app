import Foundation
import Security
#if canImport(StoreKit)
import StoreKit
#endif

/// Free plan limits for the keyboard: a free trial, then a number of Thai words a day,
/// unlimited once unlocked. With `enabled = false` nothing is limited.
///
/// How the keyboard knows about the unlock (any one is enough):
/// 1. its own StoreKit check (`refreshUnlocked`), remembered in the keyboard's defaults;
/// 2. the app's check, shared through the App Group (`SharedState`; iOS only lets the
///    keyboard read it while "Allow Full Access" is on).
/// Needs the in-app purchase `Gate.unlockProductID` (non-consumable) in App Store Connect.
///
/// The ways around a limit like this, and what stops each:
/// - deleting and reinstalling the app for a new trial: the record is also kept in the
///   Keychain (`GateVault`), which iOS keeps when an app is deleted. iOS only lets a keyboard
///   use the Keychain while "Allow Full Access" is on, so without it there is no free trial:
///   the daily allowance applies from the first day (a reinstall then gains nothing);
/// - setting the phone's clock back for a new trial or a new day: time never runs backwards
///   here (`lastSeen`), so an earlier date gets no new allowance;
/// - typing a whole message as one long "word": a long conversion counts as several words;
/// - turning Full Access off and on: the count lives in the keyboard's own storage either way.
struct Gate {
    static let enabled = true
    static let unlockProductID = "com.kenpeeranat.KaraokeThai.unlock"
    static let trialDays = 7
    static let dailyLimit = 50
    /// People who downloaded the app while it was paid keep everything: set this to the first
    /// build number (CFBundleVersion) released as free. On iOS, AppTransaction.originalAppVersion
    /// is the build number of the first download, not the marketing version.
    static let firstFreeBuild = "8"

    /// Letters of typed sound that count as one word (ceil(letters / this), at least 1).
    static let lettersPerWord = 7

    private let defaults: UserDefaults
    private let clock: () -> Date
    private let active: Bool
    private let shared: Bool
    private let vault: GateVault?

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init, active: Bool = Gate.enabled,
         shared: Bool = true, vault: GateVault? = KeychainVault()) {
        self.defaults = defaults
        self.clock = now
        self.active = active
        self.shared = shared
        self.vault = active ? vault : nil
    }

    // MARK: record (kept twice: the keyboard's defaults and the Keychain; the stricter one wins)

    private struct Record: Codable, Equatable {
        var firstUse: Date?
        var lastSeen: Date?
        var day: String?
        var count = 0
    }

    private func load() -> Record {
        var r = Record()
        r.firstUse = defaults.object(forKey: "gate.firstUse") as? Date
        r.lastSeen = defaults.object(forKey: "gate.lastSeen") as? Date
        r.day = defaults.string(forKey: "gate.day")
        r.count = defaults.integer(forKey: "gate.count")
        guard let data = vault?.read(), let v = try? JSONDecoder().decode(Record.self, from: data) else { return r }
        if let f = v.firstUse { r.firstUse = min(r.firstUse ?? f, f) }
        if let l = v.lastSeen { r.lastSeen = max(r.lastSeen ?? l, l) }
        if let d = v.day {
            if r.day == nil || d > r.day! { r.day = d; r.count = v.count }
            else if d == r.day { r.count = max(r.count, v.count) }
        }
        return r
    }

    private func save(_ r: Record) {
        defaults.set(r.firstUse, forKey: "gate.firstUse")
        defaults.set(r.lastSeen, forKey: "gate.lastSeen")
        defaults.set(r.day, forKey: "gate.day")
        defaults.set(r.count, forKey: "gate.count")
        if let data = try? JSONEncoder().encode(r) { vault?.write(data) }
    }

    /// The record brought up to now: the first use is set, time has not gone backwards, and
    /// the count belongs to today. Saved only when something changed.
    private func current() -> Record {
        let old = load()
        var r = old
        let t = max(clock(), r.lastSeen ?? .distantPast)
        if r.firstUse == nil { r.firstUse = t }
        // Saving the time on every call would write on every key; a step a minute is enough.
        if r.lastSeen == nil || t.timeIntervalSince(r.lastSeen!) >= 60 { r.lastSeen = t }
        let day = Self.dayKey(t)
        if r.day == nil || day > r.day! { r.day = day; r.count = 0 }
        if r != old { save(r) }
        return r
    }

    /// False when a Keychain was asked for but can't be used (Full Access is off): the record
    /// would not survive a reinstall, so the trial is not offered.
    private func trialAllowed(_ r: Record) -> Bool {
        guard let vault else { return true }
        if vault.read() != nil { return true }
        save(r) // nothing stored yet, or not reachable: try once and look again
        return vault.read() != nil
    }

    private func trial(_ r: Record) -> Bool {
        trialAllowed(r) && now(r).timeIntervalSince(r.firstUse ?? now(r)) < Double(Self.trialDays) * 86_400
    }

    /// The time the limits go by: the clock, but never earlier than a time already seen.
    private func now(_ r: Record) -> Date { max(clock(), r.lastSeen ?? .distantPast) }

    /// "2026-11-13": sorts in date order.
    private static func dayKey(_ t: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: t)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// The keyboard's own record (from `refreshUnlocked`), or the app's through the App Group.
    var unlocked: Bool {
        get { defaults.bool(forKey: "gate.unlocked") || (shared && SharedState.unlocked) }
        nonmutating set { defaults.set(newValue, forKey: "gate.unlocked") }
    }

    var inTrial: Bool {
        return trial(current())
    }

    var usedToday: Int { current().count }

    /// Words left today, or nil when there is no limit.
    var remainingToday: Int? {
        if !active || unlocked { return nil }
        let r = current()
        if trial(r) { return nil }
        return max(0, Self.dailyLimit - r.count)
    }

    /// May the keyboard type one more Thai word?
    var mayConvert: Bool { remainingToday.map { $0 > 0 } ?? true }

    /// Counts a conversion of `letters` typed letters (only while a limit applies): one word
    /// for every `lettersPerWord` letters, so a sentence typed in one go is not one word.
    func didConvert(letters: Int = 1) {
        guard remainingToday != nil else { return }
        var r = current()
        r.count += max(1, (letters + Self.lettersPerWord - 1) / Self.lettersPerWord)
        save(r)
    }

    static let limitMessage = "หมดโควตาวันนี้ · Free words used up today.\nUnlock in the Karaoke Thai app. Unlocked or in your free week? Turn on Full Access."

    #if canImport(StoreKit)
    /// Looks up the purchase (or an original paid download) and remembers the answer.
    func refreshUnlocked() async {
        guard Self.enabled else { return }
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.unlockProductID, t.revocationDate == nil { owned = true }
        }
        // Downloaded while the app was paid (App Store downloads only: in TestFlight and the
        // sandbox originalAppVersion is always "1.0", which would unlock every tester).
        if !owned, case .verified(let app)? = try? await AppTransaction.shared, app.environment == .production {
            owned = app.originalAppVersion.compare(Self.firstFreeBuild, options: .numeric) == .orderedAscending
        }
        // Only ever set here: if the keyboard can't see StoreKit, a "no" would hide the app's "yes".
        if owned { unlocked = true }
    }
    #endif
}

/// Where the limit's record is kept besides the keyboard's defaults.
protocol GateVault {
    func read() -> Data?
    func write(_ data: Data)
}

/// The Keychain: iOS keeps its items when the app is deleted, so a reinstall does not start a
/// new trial. If the Keychain can't be reached the defaults alone are used.
struct KeychainVault: GateVault {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "com.kenpeeranat.KaraokeThai.gate",
         kSecAttrAccount as String: "record"]
    }

    func read() -> Data? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    func write(_ data: Data) {
        let change: [String: Any] = [kSecValueData as String: data]
        if SecItemUpdate(query as CFDictionary, change as CFDictionary) == errSecItemNotFound {
            var q = query
            q[kSecValueData as String] = data
            q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            SecItemAdd(q as CFDictionary, nil)
        }
    }
}
