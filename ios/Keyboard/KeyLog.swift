import Foundation

/// Debug builds only: a record of key events (touches, picks, buffer changes) with times, kept
/// in Documents/keylog.txt inside the keyboard's container so it can be copied off a test
/// phone (xcrun devicectl device copy from ...). Release builds compile this to nothing.
enum KeyLog {
    #if DEBUG
    private static var lines: [String] = []
    private static let start = Date()
    private static let url: URL? = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
        .appendingPathComponent("keylog.txt")

    static func note(_ s: @autoclosure () -> String) {
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        lines.append("\(ms)\t\(s())")
        if lines.count > 3000 { lines.removeFirst(lines.count - 3000) }
        if lines.count % 40 == 0 { flush() }
    }

    static func flush() {
        guard let url else { return }
        let old = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let text = (old + lines.joined(separator: "\n") + "\n").suffix(400_000)
        try? String(text).write(to: url, atomically: true, encoding: .utf8)
        lines.removeAll()
    }
    #else
    @inline(__always) static func note(_ s: @autoclosure () -> String) {}
    @inline(__always) static func flush() {}
    #endif
}
