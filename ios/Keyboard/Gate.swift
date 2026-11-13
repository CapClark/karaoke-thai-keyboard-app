import Foundation
#if canImport(StoreKit)
import StoreKit
#endif

/// Free plan limits for the keyboard: a free trial, then a number of Thai words a day,
/// unlimited once unlocked. Switched off (`enabled = false`): nothing is limited.
///
/// Before switching it on:
/// - Create the in-app purchase `Gate.unlockProductID` in App Store Connect (non-consumable).
/// - Check on a device that the keyboard sees the purchase (StoreKit 2 entitlements are read
///   here too); if not, share the unlocked state from the app through an App Group.
struct Gate {
    static let enabled = false
    static let unlockProductID = "com.kenpeeranat.KaraokeThai.unlock"
    static let trialDays = 7
    static let dailyLimit = 50
    /// People who downloaded the app while it was paid keep everything: set this to the first
    /// build number (CFBundleVersion) released as free. On iOS, AppTransaction.originalAppVersion
    /// is the build number of the first download, not the marketing version.
    static let firstFreeBuild = "100"

    private let defaults: UserDefaults
    private let now: () -> Date
    private let active: Bool

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init, active: Bool = Gate.enabled) {
        self.defaults = defaults
        self.now = now
        self.active = active
    }

    /// Set from StoreKit (see `refreshUnlocked`); remembered so the keyboard works offline.
    var unlocked: Bool {
        get { defaults.bool(forKey: "gate.unlocked") }
        nonmutating set { defaults.set(newValue, forKey: "gate.unlocked") }
    }

    private var firstUse: Date {
        if let d = defaults.object(forKey: "gate.firstUse") as? Date { return d }
        let d = now()
        defaults.set(d, forKey: "gate.firstUse")
        return d
    }

    var inTrial: Bool {
        now().timeIntervalSince(firstUse) < Double(Self.trialDays) * 86_400
    }

    private var dayKey: String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: now())
        return "gate.count.\(c.year!)-\(c.month!)-\(c.day!)"
    }

    var usedToday: Int { defaults.integer(forKey: dayKey) }

    /// Words left today, or nil when there is no limit.
    var remainingToday: Int? {
        if !active || unlocked || inTrial { return nil }
        return max(0, Self.dailyLimit - usedToday)
    }

    /// May the keyboard type one more Thai word?
    var mayConvert: Bool { remainingToday.map { $0 > 0 } ?? true }

    /// Counts one Thai word typed (only while a limit applies).
    func didConvert() {
        guard remainingToday != nil else { return }
        defaults.set(usedToday + 1, forKey: dayKey)
    }

    static let limitMessage = "หมดโควตาวันนี้ · Free words used up today. Unlock in the Karaoke Thai app."

    #if canImport(StoreKit)
    /// Looks up the purchase (or an original paid download) and remembers the answer.
    func refreshUnlocked() async {
        guard Self.enabled else { return }
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.unlockProductID, t.revocationDate == nil { owned = true }
        }
        if !owned, case .verified(let app)? = try? await AppTransaction.shared {
            owned = app.originalAppVersion.compare(Self.firstFreeBuild, options: .numeric) == .orderedAscending
        }
        unlocked = owned
    }
    #endif
}
