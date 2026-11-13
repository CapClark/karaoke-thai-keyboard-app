import Foundation

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
}
