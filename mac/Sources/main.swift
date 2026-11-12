import Cocoa
import InputMethodKit

// Entry point of the input method. macOS launches this app in the background
// and talks to it through the IMKServer connection named in Info.plist.
let connectionName = Bundle.main.infoDictionary?["InputMethodConnectionName"] as? String
    ?? "ThaiPinyin_Connection"

let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
_ = server
_ = Engine.shared.candidates(for: "sawatdeekrap") // load + warm up the common path so the first keystroke is fast

NSApplication.shared.setActivationPolicy(.prohibited)
NSApplication.shared.run()
