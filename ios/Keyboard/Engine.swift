import Foundation
import os

struct Candidate {
    let text: String
    let consume: Int
    var kind: String = "word"
    var isCorrection = false // doesn't match every typed sound exactly
}

/// Runs the matching engine (ThaiEngine, the Swift port of web/engine.js) on its own queue,
/// so the keys never wait for it. Every method that touches `engine` runs on `queue`.
final class Engine {
    static let shared = Engine()

    private let queue = DispatchQueue(label: "ThaiPinyin.engine", qos: .userInitiated)
    private let engine = ThaiEngine()
    private var ready = false
    private var saveItem: DispatchWorkItem?
    private let log = Logger(subsystem: "com.kenpeeranat.ThaiPinyin", category: "engine")
    private static let learnKey = "thaiIME.learned.v2" // same storage as the web page and the Mac keyboard

    // Only the newest lookup matters: while one runs, later keystrokes replace the waiting one.
    private let lock = NSLock()
    private var pending: (input: String, previous: String?, done: ([Candidate]) -> Void)?
    private var busy = false

    private init() {
        queue.async { self.start() }
    }

    private func start() {
        let t0 = Date()
        guard let url = Bundle(for: Engine.self).url(forResource: "dict.mobile", withExtension: "txt") else {
            log.error("missing dict.mobile.txt"); return
        }
        do {
            let learned = UserDefaults.standard.string(forKey: Self.learnKey)?.data(using: .utf8)
            try engine.load(contentsOf: url, learned: learned)
            ready = true
            log.notice("loaded \(self.engine.size) words in \(Date().timeIntervalSince(t0), format: .fixed(precision: 2))s, memory \(Engine.memoryMB(), format: .fixed(precision: 1)) MB")
        } catch {
            log.error("word list: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Looks up guesses for `input`; `done` runs on the main queue. If more letters arrive
    /// before this lookup starts, only the newest one runs.
    func candidates(for input: String, previous: String?, done: @escaping ([Candidate]) -> Void) {
        lock.lock()
        pending = (input, previous, done)
        let start = !busy
        busy = true
        lock.unlock()
        if start { queue.async { self.drain() } }
    }

    private func drain() {
        while true {
            lock.lock()
            guard let job = pending else { busy = false; lock.unlock(); return }
            pending = nil
            lock.unlock()
            let result = lookup(job.input, previous: job.previous)
            DispatchQueue.main.async { job.done(result) }
        }
    }

    /// Guesses right now, for when a pick can't wait (Space pressed before the lookup came back).
    /// Waits for startup to finish on the first keystroke.
    func candidatesNow(for input: String, previous: String?) -> [Candidate] {
        queue.sync { lookup(input, previous: previous) }
    }

    private func lookup(_ input: String, previous: String?) -> [Candidate] {
        guard ready, !input.isEmpty else { return [] }
        return engine.candidates(input, limit: 36, previous: previous).compactMap { r in
            guard r.consume >= 1, r.consume <= input.count, !r.text.isEmpty else { return nil }
            return Candidate(text: r.text, consume: r.consume, kind: r.kind, isCorrection: r.tier > 0)
        }
    }

    /// Picked words rank higher next time; saved a moment later, not on every pick.
    func learn(_ text: String, previous: String?, kind: String) {
        queue.async { [self] in
            guard ready else { return }
            engine.learn(text, previous: previous, kind: kind)
            saveItem?.cancel()
            let item = DispatchWorkItem { [weak self] in self?.save() }
            saveItem = item
            queue.asyncAfter(deadline: .now() + 2, execute: item)
        }
    }

    /// Save now (keyboard closing).
    func saveSoon() { queue.async { self.save() } }

    private func save() {
        guard ready, let data = engine.learnedData(), let s = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(s, forKey: Self.learnKey)
    }

    /// iOS is short of memory: drop caches that rebuild themselves.
    func trim() {
        queue.async { [self] in
            engine.trimCaches()
            log.notice("trimmed, memory \(Engine.memoryMB(), format: .fixed(precision: 1)) MB")
        }
    }

    static func memoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1e6 : -1
    }
}
