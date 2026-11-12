import AppKit
import ApplicationServices
// Brings TextEdit forward and sets its front window frame: win x y w h
let a = CommandLine.arguments.dropFirst().compactMap { Double($0) }
guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.TextEdit").first else { print("no TextEdit"); exit(1) }
app.activate()
let ax = AXUIElementCreateApplication(app.processIdentifier)
var wins: CFTypeRef?
AXUIElementCopyAttributeValue(ax, kAXWindowsAttribute as CFString, &wins)
guard let w = (wins as? [AXUIElement])?.first else { print("no window"); exit(1) }
var p = CGPoint(x: a[0], y: a[1]), s = CGSize(width: a[2], height: a[3])
AXUIElementSetAttributeValue(w, kAXPositionAttribute as CFString, AXValueCreate(.cgPoint, &p)!)
AXUIElementSetAttributeValue(w, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &s)!)
AXUIElementPerformAction(w, kAXRaiseAction as CFString)
print("ok")
