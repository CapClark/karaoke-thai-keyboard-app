import XCTest

/// Types the demo clip's phrases in Messages with the Karaoke Thai keyboard, at an even
/// pace, while `simctl io recordVideo` records the screen. Not part of the app.
/// Also types the App Store screenshots: DEMO_APP=com.kenpeeranat.KaraokeThai types in the
/// app's practice box, and DEMO_LEAVE_LAST=1 leaves the last phrase unconverted so its
/// guesses show in the bar. DEMO_SHOT=/path.png saves a screenshot at the end (the app is
/// closed when the test ends). Other devices: DEMO_ROWS="y|keys|x,x,...;..." and
/// DEMO_SPACE="x,y" give the key positions, DEMO_GLOBE="x,y" is tapped first to switch keyboard.
///
/// Before running: the simulator is booted with Karaoke Thai as its current keyboard.
/// Key positions are for iPhone 17 Pro (402 x 874 points), Karaoke Thai's letter layout.
final class DemoUITests: XCTestCase {
    private var rows: [(y: CGFloat, keys: String, x: [CGFloat])] = DemoUITests.phoneRows
    private var space = DemoUITests.space
    private static let phoneRows: [(y: CGFloat, keys: String, x: [CGFloat])] = [
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
            guard let row = rows.first(where: { $0.keys.contains(ch) }),
                  let i = row.keys.firstIndex(of: ch) else { XCTFail("no key \(ch)"); return }
            tap(CGPoint(x: row.x[row.keys.distance(from: row.keys.startIndex, to: i)], y: row.y), "key \(ch)")
        }
    }

    private func pause(_ s: Double) { Thread.sleep(forTimeInterval: s) }

    func testDemo() throws {
        let env = ProcessInfo.processInfo.environment
        let phrases = (env["DEMO_PHRASES"] ?? "sawatdeekrap kinkhaoyang")
            .split(separator: " ").map(String.init).filter { $0 != "-" }
        let leaveLast = env["DEMO_LEAVE_LAST"] == "1"
        let sms = XCUIApplication(bundleIdentifier: env["DEMO_APP"] ?? "com.apple.MobileSMS")
        sms.activate()
        screen = sms.coordinate(withNormalizedOffset: .zero)
        pause(1)
        let point = { (s: String) -> CGPoint in
            let v = s.split(separator: ",").compactMap { Double($0) }
            return CGPoint(x: v[0], y: v[1])
        }
        if let r = env["DEMO_ROWS"] {
            rows = r.split(separator: ";").map { row in
                let f = row.split(separator: "|").map(String.init)
                return (CGFloat(Double(f[0])!), f[1], f[2].split(separator: ",").map { CGFloat(Double($0)!) })
            }
        }
        if let s = env["DEMO_SPACE"] { space = point(s) }
        if let g = env["DEMO_GLOBE"] { tap(point(g), "globe"); pause(1.5) }
        if ProcessInfo.processInfo.environment["DEMO_CLEAR"] == "1" { // empty the message box first
            for _ in 0..<40 { tap(Self.delete, "delete") }
            return
        }
        // DEMO_CLEAR_FIRST=1: empty the box, then type, in one run (Messages brings back a
        // deleted draft when it's opened again, so a separate DEMO_CLEAR run doesn't stick).
        if env["DEMO_CLEAR_FIRST"] == "1" { for _ in 0..<45 { tap(Self.delete, "delete") }; pause(2) }
        pause(1)
        for (n, phrase) in phrases.enumerated() {
            // A space between phrases (DEMO_NO_GAP=1 leaves it out: a second space right after
            // a conversion types ๆ, as a double space types a full stop in English).
            if n > 0 && env["DEMO_NO_GAP"] != "1" { tap(space, "space"); pause(0.6) }
            type(phrase)
            pause(1.4) // let the guess sit in the bar
            if leaveLast && n == phrases.count - 1 { break }
            tap(space, "convert") // types the first Thai guess
            pause(1.6)
        }
        pause(1.5)
        if let path = env["DEMO_SHOT"] {
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
        }
    }
    /// Audit screenshots: SHOT_DIR and SHOT_PREFIX. Shows the app's page from the top, closing
    /// the keyboard first, then scrolls down a screen at a time (SHOT_PAGES, default 6).
    func testPageShots() throws {
        let env = ProcessInfo.processInfo.environment
        guard let dir = env["SHOT_DIR"] else { return }
        let prefix = env["SHOT_PREFIX"] ?? "page"
        let app = XCUIApplication(bundleIdentifier: "com.kenpeeranat.KaraokeThai")
        app.activate()
        pause(1.5)
        let shot = { (name: String) in
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(prefix)_\(name).png"))
        }
        if env["SHOT_KEEP_KEYBOARD"] == "1" { shot("keyboard"); return }
        if app.buttons["Done"].exists { app.buttons["Done"].tap(); pause(1) }
        if app.buttons["Not now"].exists { shot("sheet"); app.buttons["Not now"].tap(); pause(1) }
        for n in 1...(Int(env["SHOT_PAGES"] ?? "6") ?? 6) {
            shot(String(n))
            app.swipeUp(velocity: .slow)
            pause(1)
            if app.buttons["Done"].exists { app.buttons["Done"].tap(); pause(1) } // a swipe can land on the text box
        }
    }
}

