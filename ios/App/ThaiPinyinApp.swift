import StoreKit
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
    @State private var autoFocused = false
    @State private var showUnlock = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

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
    /// Either spelling counts: the keyboard may be in chat style (ChatStyle), which the app can't see.
    private var solved: Bool { text.contains(challenge.thai) || text.contains(ChatStyle.slang(challenge.thai)) }

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
                        .onAppear { // open the keyboard right away, once: the list calls this again on every scroll back
                            if !autoFocused { autoFocused = true; focused = true }
                        }
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
                    if Store.enabled {
                        step(4, "Tap **Karaoke Thai** there and turn on **Allow Full Access**: iOS needs it for the free week, for the keyboard to see your unlock, and for a light tap on each key.")
                    } else {
                        step(4, "For a light tap on each key, tap **Karaoke Thai** there and turn on **Allow Full Access** (iOS requires it for haptics).")
                    }
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

                Section {
                    Link(destination: URL(string: "https://apps.apple.com/app/id6833730979?action=write-review")!) {
                        Label("Rate Karaoke Thai", systemImage: "star")
                    }
                } footer: {
                    Text("A rating or a review helps other people find the keyboard.")
                }
            }
            .navigationTitle("Karaoke Thai")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively) // drag the page down to close the keyboard
            .toolbar {
                if focused { Button("Done") { focused = false } }
            }
        }
        .sheet(isPresented: $showUnlock) { UnlockSheet(store: store) }
        .onChange(of: store.checked) { _ in offerUnlockIfDue() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                noteAppDay()
                Task { await store.refresh(); offerUnlockIfDue(); askForRatingIfDue() }
            }
        }
    }

    /// Shows the unlock screen when the free week is over or the keyboard ran out of words.
    private func offerUnlockIfDue() {
        if !showUnlock && store.unlockDue() { focused = false; showUnlock = true }
    }

    /// Counts the different days the app is opened (`RatingAsk` uses it without Full Access).
    private func noteAppDay() {
        let u = UserDefaults.standard, day = Usage.dayKey(Date())
        guard day > (u.string(forKey: "rating.appLastDay") ?? "") else { return }
        u.set(day, forKey: "rating.appLastDay")
        u.set(u.integer(forKey: "rating.appDays") + 1, forKey: "rating.appDays")
    }

    /// Asks for an App Store rating when the app is opened after real use of the keyboard
    /// (`RatingAsk`), never over the unlock screen.
    private func askForRatingIfDue() {
        let u = UserDefaults.standard, now = Date()
        guard !showUnlock, RatingAsk.isDue(
            words: Usage.words(), keyboardDays: Usage.days(), appDays: u.integer(forKey: "rating.appDays"),
            lastAsked: u.object(forKey: "rating.lastAsked") as? Date, limitHitAt: SharedState.limitHitAt, now: now)
        else { return }
        u.set(now, forKey: "rating.lastAsked")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { if !showUnlock { requestReview() } }
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
