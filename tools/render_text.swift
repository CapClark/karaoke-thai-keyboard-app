// Renders one line of text to a transparent PNG with the system font (macOS shapes Thai
// properly and falls back to a Thai font on its own). Used by tools/caption_shots.py.
//
//   swift tools/render_text.swift <out.png> <size> <bold 0|1> <hex colour> <text>
import AppKit

let a = CommandLine.arguments
guard a.count == 6, let size = Double(a[2]) else {
    FileHandle.standardError.write("usage: render_text.swift out.png size bold hex text\n".data(using: .utf8)!)
    exit(1)
}
let hex = UInt32(a[4], radix: 16) ?? 0xFFFFFF
let colour = NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                     blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
let font = NSFont.systemFont(ofSize: size, weight: a[3] == "1" ? .bold : .medium)
let text = NSAttributedString(string: a[5], attributes: [.font: font, .foregroundColor: colour])
let bounds = text.boundingRect(with: NSSize(width: 100_000, height: 100_000), options: [.usesLineFragmentOrigin])
let pad = size * 0.4
let w = Int(ceil(bounds.width + pad * 2)), h = Int(ceil(bounds.height + pad * 2))
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
text.draw(with: NSRect(x: pad, y: pad, width: bounds.width, height: bounds.height), options: [.usesLineFragmentOrigin])
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[1]))
