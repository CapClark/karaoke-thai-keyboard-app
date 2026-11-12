// Draws the menu-bar icon (Thai letter ก in a rounded square) as a TIFF template image.
import Cocoa

let out = CommandLine.arguments[1]
let reps = [16, 32].map { px -> NSBitmapImageRep in
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 16, height: 16)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let r = NSRect(x: 0.5, y: 0.5, width: 15, height: 15)
    let path = NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3)
    NSColor.black.setStroke()
    path.lineWidth = 1
    path.stroke()
    let s = NSAttributedString(string: "ก", attributes: [
        .font: NSFont.systemFont(ofSize: 11, weight: .semibold), .foregroundColor: NSColor.black,
    ])
    let sz = s.size()
    s.draw(at: NSPoint(x: (16 - sz.width) / 2, y: (16 - sz.height) / 2 + 0.5))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}
let data = NSBitmapImageRep.tiffRepresentationOfImageReps(in: reps, using: .none, factor: 0)!
try! data.write(to: URL(fileURLWithPath: out))
