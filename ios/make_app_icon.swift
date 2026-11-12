// Draws the 1024px app icon: a white key cap on a sunset gradient, with a small "k" turning
// into the Thai letter ก (iOS masks the corners).  Usage: swift make_app_icon.swift icon.png
import Cocoa
let out = CommandLine.arguments[1]
let px: CGFloat = 1024

func rgb(_ h: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

/// The text's outline, centred on `c` with ink height `h`.
func glyph(_ s: String, font: String, height h: CGFloat, center c: CGPoint) -> NSBezierPath {
    let f = NSFont(name: font, size: 500) ?? NSFont.systemFont(ofSize: 500, weight: .bold)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f]))
    let path = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let rf = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName as String] as! CTFont
        for i in 0..<CTRunGetGlyphCount(run) {
            var g = CGGlyph(), p = CGPoint()
            CTRunGetGlyphs(run, CFRange(location: i, length: 1), &g)
            CTRunGetPositions(run, CFRange(location: i, length: 1), &p)
            if let gp = CTFontCreatePathForGlyph(rf, g, nil) { path.addPath(gp, transform: CGAffineTransform(translationX: p.x, y: p.y)) }
        }
    }
    let b = path.boundingBoxOfPath
    let k = h / b.height
    var t = CGAffineTransform(translationX: c.x - b.midX * k, y: c.y - b.midY * k).scaledBy(x: k, y: k)
    return NSBezierPath(cgPath: path.copy(using: &t)!)
}

// No alpha channel: the App Store refuses icons that have one.
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(px), pixelsHigh: Int(px), bitsPerSample: 8, samplesPerPixel: 3,
                           hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 32)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let full = NSRect(x: 0, y: 0, width: px, height: px)
NSGradient(colors: [rgb(0xFF9A3D), rgb(0xFF5A5F), rgb(0xD63384)])!.draw(in: full, angle: -60)

// The key: a darker lip under it and a soft shadow, so it looks raised.
let cap = NSRect(x: 172, y: 190, width: 680, height: 680)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = rgb(0x5A0A2A, 0.45); shadow.shadowBlurRadius = 60; shadow.shadowOffset = NSSize(width: 0, height: -34)
shadow.set()
rgb(0xE9E3EA).setFill()
NSBezierPath(roundedRect: cap.offsetBy(dx: 0, dy: -26), xRadius: 150, yRadius: 150).fill()
NSGraphicsContext.restoreGraphicsState()
NSGradient(starting: rgb(0xFFFFFF), ending: rgb(0xF6F1F4))!.draw(in: NSBezierPath(roundedRect: cap, xRadius: 150, yRadius: 150), angle: -90)

rgb(0x1F1630).setFill()
glyph("ก", font: "SukhumvitSet-Bold", height: 400, center: CGPoint(x: 530, y: 500)).fill()
rgb(0xFF5A5F).setFill()
glyph("k", font: "SFProRounded-Bold", height: 124, center: CGPoint(x: 292, y: 758)).fill()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
