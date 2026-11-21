import Foundation

/// The free plan's numbers, used by the keyboard (`Gate`) and by the app's unlock screen.
enum FreePlan {
    static let trialDays = 7
    static let wordsPerDay = 20
}

/// State the app and the keyboard share through the App Group container.
/// Note: iOS only lets a keyboard read the shared container while "Allow Full Access" is on.
enum SharedState {
    static let appGroup = "group.com.kenpeeranat.KaraokeThai"
    static let unlockedKey = "shared.unlocked"

    static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    /// Written by the app after it checks the purchase; read by the keyboard.
    static var unlocked: Bool {
        get { defaults?.bool(forKey: unlockedKey) ?? false }
        set { defaults?.set(newValue, forKey: unlockedKey) }
    }

    /// Test builds only (TestFlight, sandbox, Xcode): act as if the unlock was never bought,
    /// so a tester whose purchase can't be cleared can still try the free plan.
    static let testIgnorePurchaseKey = "shared.test.ignorePurchase"
    static var testIgnorePurchase: Bool {
        get { defaults?.bool(forKey: testIgnorePurchaseKey) ?? false }
        set { defaults?.set(newValue, forKey: testIgnorePurchaseKey) }
    }

    /// When the keyboard last hit the daily limit, so the app can offer the unlock when it is
    /// next opened. Written only while Full Access is on (iOS blocks the App Group otherwise).
    static let limitHitAtKey = "shared.limitHitAt"
    static var limitHitAt: Date? {
        get { defaults?.object(forKey: limitHitAtKey) as? Date }
        set { defaults?.set(newValue, forKey: limitHitAtKey) }
    }
}
