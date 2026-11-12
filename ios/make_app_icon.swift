// Draws the 1024px app icon: the Thai letter ก on a warm rounded background (iOS masks the corners).
import Cocoa
let out = CommandLine.arguments[1]
let px = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let r = NSRect(x: 0, y: 0, width: px, height: px)
NSGradient(starting: NSColor(red: 0.85, green: 0.42, blue: 0.22, alpha: 1), ending: NSColor(red: 0.62, green: 0.25, blue: 0.12, alpha: 1))!
    .draw(in: r, angle: -90)
let s = NSAttributedString(string: "ก", attributes: [.font: NSFont.systemFont(ofSize: 640, weight: .semibold), .foregroundColor: NSColor.white])
let sz = s.size()
s.draw(at: NSPoint(x: (CGFloat(px) - sz.width) / 2, y: (CGFloat(px) - sz.height) / 2 + 20))
let small = NSAttributedString(string: "kor", attributes: [.font: NSFont.monospacedSystemFont(ofSize: 110, weight: .medium), .foregroundColor: NSColor(white: 1, alpha: 0.75)])
small.draw(at: NSPoint(x: (CGFloat(px) - small.size().width) / 2, y: 70))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
