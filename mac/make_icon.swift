// Draws the Mac keyboard's two icons, matching the iPhone app's key-cap logo.
//   swift make_icon.swift menu icon.tiff              menu-bar icon: a key cap with ก cut out (template image)
//   swift make_icon.swift app ../ios/…/icon.png out.iconset   app icon: the iPhone icon in the Mac icon shape
import Cocoa

func bitmap(_ px: Int, _ draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// The letter's outline, centred on `c` with ink height `h`.
func glyph(_ s: String, height h: CGFloat, center c: CGPoint) -> NSBezierPath {
    let f = NSFont(name: "SukhumvitSet-Bold", size: 200) ?? NSFont.systemFont(ofSize: 200, weight: .bold)
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

let args = CommandLine.arguments
switch args[1] {
case "menu":
    let reps = [16, 32].map { px -> NSBitmapImageRep in
        let rep = bitmap(px) {
            let k = CGFloat(px) / 16
            let cap = NSBezierPath(roundedRect: NSRect(x: 0.5 * k, y: 0.5 * k, width: 15 * k, height: 15 * k), xRadius: 3.6 * k, yRadius: 3.6 * k)
            cap.append(glyph("ก", height: 8.6 * k, center: CGPoint(x: 8.1 * k, y: 7.8 * k)))
            cap.windingRule = .evenOdd // the letter is a hole in the key
            NSColor.black.setFill()
            cap.fill()
        }
        rep.size = NSSize(width: 16, height: 16)
        return rep
    }
    try! NSBitmapImageRep.tiffRepresentationOfImageReps(in: reps, using: .none, factor: 0)!.write(to: URL(fileURLWithPath: args[2]))
case "app":
    let art = NSImage(contentsOfFile: args[2])!
    try! FileManager.default.createDirectory(atPath: args[3], withIntermediateDirectories: true)
    for (pt, scale) in [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)] {
        let px = pt * scale
        let rep = bitmap(px) {
            // Mac icon shape: a rounded square inset from the edges, with a soft shadow.
            let s = CGFloat(px)
            let r = NSRect(x: s * 0.098, y: s * 0.098, width: s * 0.804, height: s * 0.804)
            let shape = NSBezierPath(roundedRect: r, xRadius: s * 0.181, yRadius: s * 0.181)
            NSGraphicsContext.saveGraphicsState()
            let shadow = NSShadow()
            shadow.shadowColor = NSColor(white: 0, alpha: 0.3); shadow.shadowBlurRadius = s * 0.02; shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
            shadow.set()
            NSColor.white.setFill(); shape.fill()
            NSGraphicsContext.restoreGraphicsState()
            shape.addClip()
            art.draw(in: r)
        }
        let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3] + "/" + name))
    }
default:
    fatalError("usage: make_icon.swift menu out.tiff | app art.png out.iconset")
}
