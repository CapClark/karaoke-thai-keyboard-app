import SwiftUI
import UIKit

@main
struct ThaiPinyinApp: App {
    var body: some Scene {
        WindowGroup { SetupView() }
    }
}

/// A short thing to type, and the Thai it should give.
struct Challenge: Identifiable, Hashable {
    let typed: String
    let thai: String
    let meaning: String
    var id: String { typed }
}

/// How to turn the keyboard on, a box to try it, and practice challenges.
struct SetupView: View {
    @State private var text = ""
    @State private var current = 0
    @State private var done: Set<String> = []
    @StateObject private var store = Store()
    @FocusState private var focused: Bool

    static let challenges: [Challenge] = [
        Challenge(typed: "sawatdee", thai: "สวัสดี", meaning: "hello"),
        Challenge(typed: "kinkhaoyang", thai: "กินข้าวยัง", meaning: "have you eaten?"),
        Challenge(typed: "khobkhunmak", thai: "ขอบคุณมาก", meaning: "thank you very much"),
        Challenge(typed: "pomrakkun", thai: "ผมรักคุณ", meaning: "I love you"),
        Challenge(typed: "aroimak", thai: "อร่อยมาก", meaning: "really tasty"),
        Challenge(typed: "kaopadkai", thai: "ข้าวผัดไก่", meaning: "chicken fried rice"),
        Challenge(typed: "maiphet", thai: "ไม่เผ็ด", meaning: "not spicy"),
        Challenge(typed: "diawkoikhuikan", thai: "เดี๋ยวค่อยคุยกัน", meaning: "talk later"),
    ]

    /// Different spellings people use, all giving the same Thai.
    static let spellings: [(String, String)] = [
        ("khao · kao · kow", "ข้าว / เขา"),
        ("laew · leow · lew", "แล้ว"),
        ("kin · gin", "กิน"),
        ("krap · krub · khrap", "ครับ"),
        ("sawatdee · sawasdee · sawaddee", "สวัสดี"),
        ("mairu · mairoo", "ไม่รู้"),
        ("maiphet · maipet", "ไม่เผ็ด"),
    ]

    private var challenge: Challenge { Self.challenges[current % Self.challenges.count] }
    private var solved: Bool { text.contains(challenge.thai) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Type Thai by sound").font(.title2.bold())
                        Text("พิมพ์ไทยตามเสียง แบบคาราโอเกะ").foregroundStyle(.secondary)
                        Text("Spell it the way you would in a chat. No rules to learn: **sawatdeekrap** → สวัสดีครับ.")
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Type").foregroundStyle(.secondary)
                            Text(challenge.typed).font(.body.monospaced().bold())
                            if solved || done.contains(challenge.id) {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    .accessibilityLabel("Done")
                            }
                            Spacer()
                            Button(solved ? "Next" : "Skip") {
                                current += 1
                                text = ""
                            }
                            .bold(solved)
                            .buttonStyle(.borderless)
                        }
                        HStack {
                            Text("\(challenge.thai)  ·  \(challenge.meaning)")
                            Spacer()
                            Text("\(done.count) of \(Self.challenges.count)")
                        }
                        .font(.footnote).foregroundStyle(.secondary)
                    }
                    TextField("Type here with Karaoke Thai…", text: $text, axis: .vertical)
                        .lineLimit(2...6)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onAppear { focused = true } // open the keyboard right away
                        .onChange(of: text) { _ in
                            if solved { done.insert(challenge.id) }
                        }
                } header: {
                    Text("Practice")
                } footer: {
                    Text("Space or Return types the first guess. Tap another guess to pick it.")
                }

                if Store.enabled { UnlockSection(store: store) }

                Section("Spell it your way") {
                    ForEach(Self.spellings, id: \.0) { row in
                        HStack {
                            Text(row.0).font(.callout.monospaced())
                            Spacer()
                            Text(row.1).foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Turn it on") {
                    step(1, "Open **Settings → General → Keyboard → Keyboards**.")
                    step(2, "Tap **Add New Keyboard…** and choose **Karaoke Thai**.")
                    step(3, "In any app, hold the 🌐 key and pick Karaoke Thai.")
                    step(4, "For a light tap on each key, tap **Karaoke Thai** there and turn on **Allow Full Access** (iOS requires it for haptics).")
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    } label: {
                        Label("Open Settings", systemImage: "gear")
                    }
                    Text("The keyboard never connects to the internet: what you type stays on this device, with or without Full Access.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Section("Keys") {
                    row("Space or Return", "types the first Thai guess")
                    row("Tap a guess", "types that one")
                    row("Tap the letters", "keeps them as English")
                    row("EN / ไทย", "switches to plain English typing")
                    row("Words you pick", "come first next time")
                }
            }
            .navigationTitle("Karaoke Thai")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func step(_ n: Int, _ s: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)").font(.headline).foregroundStyle(.secondary)
            Text(s)
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k).bold(); Spacer(); Text(v).foregroundStyle(.secondary).multilineTextAlignment(.trailing) }
    }
}
