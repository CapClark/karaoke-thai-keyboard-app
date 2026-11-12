import AppKit
// Waits up to 120 s for TextEdit to be the frontmost app.
for _ in 0..<6000 {
  if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.TextEdit" { print("front"); exit(0) }
  RunLoop.current.run(until: Date().addingTimeInterval(0.1))
}
print("timeout"); exit(1)
