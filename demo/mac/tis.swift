// Lists Thai/Karaoke input sources, or enables and selects one: tis <source id>
import Carbon
let arg = CommandLine.arguments.dropFirst().first ?? "list"
let list = TISCreateInputSourceList(nil, true).takeRetainedValue() as! [TISInputSource]
func prop(_ s: TISInputSource, _ k: CFString) -> String {
  guard let p = TISGetInputSourceProperty(s, k) else { return "-" }
  return (Unmanaged<AnyObject>.fromOpaque(p).takeUnretainedValue() as? String) ?? "?"
}
for s in list {
  let id = prop(s, kTISPropertyInputSourceID)
  if arg == "list" { if id.lowercased().contains("pinyin") || id.lowercased().contains("karaoke") || id.lowercased().contains("thai") { print(id, prop(s, kTISPropertyLocalizedName)) } }
  else if id == arg { print("enable", TISEnableInputSource(s), "select", TISSelectInputSource(s)) }
}
