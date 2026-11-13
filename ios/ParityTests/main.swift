// Checks the Swift engine (Keyboard/ThaiEngine.swift) against the web engine: same sound
// keys and the same guesses, in the same order, for every input tools/ios_parity.js wrote.
// Also reports speed and memory. Run by ios/build.sh:
//   swiftc -O ParityTests/main.swift Keyboard/ThaiEngine.swift -o parity && ./parity dict.mobile.txt expected.json
import Foundation

func memoryMB() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kr = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1e6 : -1
}

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: parity dict.mobile.txt expected.json"); exit(2) }
let before = memoryMB()
let t0 = Date()
let engine = ThaiEngine()
try engine.load(contentsOf: URL(fileURLWithPath: args[1]))
let loadTime = Date().timeIntervalSince(t0)
let loadedMem = memoryMB()

let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: args[2]))) as! [String: Any]
var failures = 0
if let size = json["size"] as? Int, size != engine.size {
    print("word count differs: web \(size), swift \(engine.size)"); failures += 1
}
var tokBad = 0
for t in json["tokens"] as! [[String]] {
    let k = ThaiEngine.tokenize(t[0])
    if k.key != t[1] || k.full != t[2] {
        if tokBad < 10 { print("tokenize \(t[0]): web \(t[1]) \(t[2]), swift \(k.key) \(k.full)") }
        tokBad += 1
    }
}
failures += tokBad

var caseBad = 0, total = 0
var worst = 0.0, sum = 0.0, worstTyped = ""
for c in json["cases"] as! [[String: Any]] {
    let typed = c["typed"] as! String
    let prev = c["prev"] as? String
    let want = (c["want"] as! [[Any]]).map { "\($0[0])|\($0[1])|\($0[2])|\($0[3])" }
    let s = Date()
    let got = engine.candidates(typed, limit: 36, previous: prev).map { "\($0.text)|\($0.consume)|\($0.tier)|\($0.kind)" }
    let ms = Date().timeIntervalSince(s) * 1000
    if ms > worst { worst = ms; worstTyped = typed }
    sum += ms; total += 1
    if got != want {
        if caseBad < 15 {
            let i = (0..<min(got.count, want.count)).first { got[$0] != want[$0] } ?? min(got.count, want.count)
            print("\(typed) (prev \(prev ?? "-")): differ at #\(i + 1): web \(i < want.count ? want[i] : "(end)") swift \(i < got.count ? got[i] : "(end)")")
        }
        caseBad += 1
    }
}
failures += caseBad
print(String(format: "parity: %d inputs, %d differ; %d spellings tokenized, %d differ; load %.2fs; per keystroke avg %.2f ms, worst %.1f ms (%@); memory %.1f MB (word list %.1f MB)",
             total, caseBad, (json["tokens"] as! [Any]).count, tokBad, loadTime, sum / Double(max(total, 1)), worst, worstTyped, memoryMB(), loadedMem - before))
exit(failures == 0 ? 0 : 1)
