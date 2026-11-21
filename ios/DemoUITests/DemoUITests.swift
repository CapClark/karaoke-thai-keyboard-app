import XCTest

/// Types the demo clip's phrases in Messages with the Karaoke Thai keyboard, at an even
/// pace, while `simctl io recordVideo` records the screen. Not part of the app.
///
/// Before running: the simulator is booted with Karaoke Thai as its current keyboard.
/// Key positions are for iPhone 17 Pro (402 x 874 points), Karaoke Thai's letter layout.
final class DemoUITests: XCTestCase {
    private static let rows: [(y: CGFloat, keys: String, x: [CGFloat])] = [
        (620, "qwertyuiop", [21, 61, 101, 141, 180, 221, 260, 300, 340, 380]),
        (673, "asdfghjkl", [41, 81, 121, 161, 201, 240, 280, 320, 360]),
        (728, "zxcvbnm", [81, 121, 161, 201, 240, 280, 320]),
    ]
    private static let space = CGPoint(x: 203, y: 779)
    private static let delete = CGPoint(x: 371, y: 728)

    private var screen: XCUICoordinate!

    /// Each tap is logged with the wall clock so the edit can put a key sound on it.
    private func tap(_ p: CGPoint, _ kind: String) {
        screen.withOffset(CGVector(dx: p.x, dy: p.y)).press(forDuration: 0.02)
        print(String(format: "DEMO_EVENT %.3f %@", Date().timeIntervalSince1970, kind))
    }

    private func type(_ word: String) {
        for ch in word {
            guard let row = Self.rows.first(where: { $0.keys.contains(ch) }),
                  let i = row.keys.firstIndex(of: ch) else { XCTFail("no key \(ch)"); return }
            tap(CGPoint(x: row.x[row.keys.distance(from: row.keys.startIndex, to: i)], y: row.y), "key \(ch)")
        }
    }

    private func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    func testDemo() throws {
        let phrases = (ProcessInfo.processInfo.environment["DEMO_PHRASES"] ?? "sawatdeekrap kinkhaoyang")
            .split(separator: " ").map(String.init)
        let sms = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        sms.activate()
        screen = sms.coordinate(withNormalizedOffset: .zero)
        pause(1)
        if ProcessInfo.processInfo.environment["DEMO_CLEAR"] == "1" { // empty the message box first
            for _ in 0..<40 { tap(Self.delete, "delete") }
            return
        }
        pause(1)
        for (n, phrase) in phrases.enumerated() {
            if n > 0 { tap(Self.space, "space"); pause(0.6) } // a space between phrases
            type(phrase)
            pause(1.4) // let the guess sit in the bar
            tap(Self.space, "convert") // types the first Thai guess
            pause(1.6)
        }
        pause(1.5)
    }
}
