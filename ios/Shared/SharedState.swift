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

/// What the keyboard last saw of the free plan, so the app can show it (the app can't read
/// the keyboard's own storage). Written only while Full Access is on: no report at all tells
/// the app that Full Access is off or the keyboard hasn't been used yet.
enum KeyboardReport {
    static let seenKey = "shared.kb.seenAt"
    static let trialEndsKey = "shared.kb.trialEnds"
    static let wordsLeftKey = "shared.kb.wordsLeft" // -1: no daily limit right now
    static let dayKey = "shared.kb.day"

    static func write(trialEnds: Date?, wordsLeft: Int?, now: Date = Date(), in d: UserDefaults? = SharedState.defaults) {
        guard let d else { return }
        d.set(now, forKey: seenKey)
        d.set(trialEnds, forKey: trialEndsKey)
        d.set(wordsLeft ?? -1, forKey: wordsLeftKey)
        d.set(Usage.dayKey(now), forKey: dayKey)
    }

    static func seenAt(in d: UserDefaults? = SharedState.defaults) -> Date? { d?.object(forKey: seenKey) as? Date }
    static func trialEnds(in d: UserDefaults? = SharedState.defaults) -> Date? { d?.object(forKey: trialEndsKey) as? Date }

    /// Free words left today: the last count if it was written today, a full allowance on a
    /// new day, nil when there was no limit (free week or unlocked).
    static func wordsLeft(now: Date = Date(), in d: UserDefaults? = SharedState.defaults) -> Int? {
        guard let d, d.object(forKey: wordsLeftKey) != nil else { return nil }
        let left = d.integer(forKey: wordsLeftKey)
        if left < 0 { return nil }
        return d.string(forKey: dayKey) == Usage.dayKey(now) ? left : FreePlan.wordsPerDay
    }
}

/// How much the keyboard has really been used, so the app asks for a rating only after
/// that. Written by the keyboard on each Thai word it types, which needs Full Access (iOS
/// blocks the App Group otherwise); read by the app.
enum Usage {
    static let wordsKey = "shared.usage.words"
    static let daysKey = "shared.usage.days"
    static let lastDayKey = "shared.usage.lastDay"

    /// One Thai word typed. Counts each calendar day once (a clock set back adds no day).
    static func noteWord(now: Date = Date(), in d: UserDefaults? = SharedState.defaults) {
        guard let d else { return }
        d.set(d.integer(forKey: wordsKey) + 1, forKey: wordsKey)
        let day = dayKey(now)
        if day > (d.string(forKey: lastDayKey) ?? "") {
            d.set(day, forKey: lastDayKey)
            d.set(d.integer(forKey: daysKey) + 1, forKey: daysKey)
        }
    }

    static func words(in d: UserDefaults? = SharedState.defaults) -> Int { d?.integer(forKey: wordsKey) ?? 0 }
    static func days(in d: UserDefaults? = SharedState.defaults) -> Int { d?.integer(forKey: daysKey) ?? 0 }

    /// "2026-11-13": sorts in date order.
    static func dayKey(_ t: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: t)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

/// When the app may ask for an App Store rating: after real use of the keyboard, never on
/// the first days, never on a day the free limit stopped the keyboard, and at most once in
/// 60 days (iOS also shows the request at most three times a year). No question first and
/// nothing given for a rating (App Review Guidelines 5.6.1).
enum RatingAsk {
    static let minWords = 30
    static let minDays = 3
    /// Without Full Access the keyboard can't report its use: then the app being opened on
    /// this many different days stands in for it.
    static let minAppDays = 4
    static let gapDays = 60.0

    static func isDue(words: Int, keyboardDays: Int, appDays: Int, lastAsked: Date?,
                      limitHitAt: Date?, now: Date) -> Bool {
        if let l = lastAsked, now.timeIntervalSince(l) < gapDays * 86_400 { return false }
        if let h = limitHitAt, now.timeIntervalSince(h) < 86_400 { return false }
        if words > 0 { return words >= minWords && keyboardDays >= minDays }
        return appDays >= minAppDays
    }
}
