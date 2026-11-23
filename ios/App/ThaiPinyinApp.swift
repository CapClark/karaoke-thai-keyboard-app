import StoreKit
import SwiftUI
import UIKit

@main
struct ThaiPinyinApp: App {
    var body: some Scene {
        WindowGroup { SetupView() }
    }
}

/// The app's colours, taken from the icon (orange to pink, navy letter, coral k).
enum Brand {
    static let orange = Color(red: 0.96, green: 0.47, blue: 0.20)
    static let pink = Color(red: 0.86, green: 0.21, blue: 0.45)
    static let gradient = LinearGradient(colors: [orange, pink], startPoint: .leading, endPoint: .trailing)
    static let privacyURL = URL(string: "https://capclark.github.io/karaoke-thai-keyboard/privacy.html")!
    static let supportURL = URL(string: "https://capclark.github.io/karaoke-thai-keyboard/")!
    static let reviewURL = URL(string: "https://apps.apple.com/app/id6833730979?action=write-review")!
}

/// Whether the keyboard is added in Settings, and whether it has reported in (it can only
/// do that with Full Access on).
enum KeyboardSetup {
    /// iOS lists the keyboards the person added in the global "AppleKeyboards" setting.
    static var added: Bool {
        let list = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] ?? []
        return list.contains { $0.hasPrefix("com.kenpeeranat.KaraokeThai") }
    }

    static var fullAccessSeen: Bool { KeyboardReport.seenAt() != nil }

    static func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
}

/// A short thing to type, and the Thai it should give.
struct Challenge: Identifiable, Hashable {
    let typed: String
    let thai: String
    let meaning: String
    var id: String { typed }
}

/// One screen: setting up the keyboard, practice, tips, and the free plan.
struct SetupView: View {
    @State private var text = ""
    @State private var current = 0
    @State private var done: Set<String> = []
    @StateObject private var store = Store()
    @FocusState private var focused: Bool
    @State private var autoFocused = false
    @State private var showUnlock = false
    /// Re-read when the app comes back from Settings.
    @State private var added = KeyboardSetup.added
    @State private var fullAccessSeen = KeyboardSetup.fullAccessSeen
    /// "You're all set" is shown once, after setup.
    @State private var showMoreTips = false
    @State private var readyShown = UserDefaults.standard.bool(forKey: "app.readyShown")
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    static let practiceID = "practiceField"

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
    static let spellings: [(typed: String, thai: String, meaning: String)] = [
        ("khao · kao · kow", "ข้าว", "rice"),
        ("laew · leow · lew", "แล้ว", "already"),
        ("kin · gin", "กิน", "eat"),
        ("krap · krub · khrap", "ครับ", "polite ending"),
        ("sawatdee · sawasdee", "สวัสดี", "hello"),
        ("mairu · mairoo", "ไม่รู้", "don’t know"),
        ("maiphet · maipet", "ไม่เผ็ด", "not spicy"),
    ]

    /// Today's free words are gone: the practice field says so instead of inviting typing.
    private var wordsUsedUp: Bool {
        guard Store.enabled, !store.unlocked, case .words(let n) = PlanStatus.current().kind else { return false }
        return n == 0
    }

    private var challenge: Challenge { Self.challenges[current % Self.challenges.count] }
    /// Either spelling counts: the keyboard may be in chat style (ChatStyle), which the app can't see.
    private var solved: Bool { text.contains(challenge.thai) || text.contains(ChatStyle.slang(challenge.thai)) }
    /// The free plan needs a decision: shown high up instead of at the bottom.
    private var planUrgent: Bool { Store.enabled && store.checked && !store.unlocked && PlanStatus.current().urgent }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            Form {
                header
                if !added {
                    addKeyboardSection
                } else if !fullAccessSeen && Store.enabled {
                    fullAccessSection
                } else if planUrgent {
                    UnlockSection(store: store)
                } else if !readyShown && Usage.words() == 0 {
                    readySection
                }
                if added && !wordsUsedUp { practiceSection } // nothing to practice with no words left: the plan card says why
                spellingsSection
                tipsSection
                if Store.enabled && !planUrgent { UnlockSection(store: store) }
                aboutSection
            }
            .tint(.accentColor)
            .compactSections()
            .navigationTitle("Karaoke Thai")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively) // drag the page down to close the keyboard
            .toolbar {
                if focused { Button("Done") { focused = false } }
            }
            .onChange(of: focused) { on in
                guard on else { return }
                // Wait for the keyboard, then lift the field clear of it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation { proxy.scrollTo(Self.practiceID, anchor: .center) }
                }
            }
            }
        }
        .sheet(isPresented: $showUnlock) { UnlockSheet(store: store) }
        .onChange(of: store.checked) { _ in offerUnlockIfDue() }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                added = KeyboardSetup.added
                fullAccessSeen = KeyboardSetup.fullAccessSeen
                noteAppDay()
                Task { await store.refresh(); offerUnlockIfDue(); askForRatingIfDue() }
            }
        }
    }

    // MARK: sections

    private var header: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image("Logo")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Type Thai the way it sounds").font(.title3.bold())
                        Text("พิมพ์ไทยตามเสียง แบบคาราโอเกะ").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                DemoBubble(typed: "sawatdeekrap", thai: "สวัสดีครับ")
                Text("“Karaoke” is what Thais call Thai written in English letters. Spell words the way they sound, and the keyboard finds the Thai.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
    }

    private var addKeyboardSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add the keyboard").font(.headline)
                    Text("About 30 seconds. Open Settings, then:").font(.subheadline).foregroundStyle(.secondary)
                }
                step(1, "Tap **Keyboards**.")
                step(2, "Turn on **Karaoke Thai**.")
                step(3, "For your free week, turn on **Allow\u{00A0}Full\u{00A0}Access**, then tap **Allow**.", note: "Nothing you type leaves your device")
                step(4, "Come back here to practice.")
                settingsButton
                Divider()
                fullAccessNote(link: true)
            }
            .padding(.vertical, 6)
        } header: {
            Text("Start here")
        }
    }

    private var fullAccessSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(.green).frame(width: 24)
                    Text("Keyboard added").foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Turn on Full Access").font(.headline)
                    Text("Open Settings, then:").font(.subheadline).foregroundStyle(.secondary)
                }
                step(1, "Tap **Keyboards**.")
                step(2, "Turn on **Allow\u{00A0}Full\u{00A0}Access**, then tap **Allow**.", note: "Nothing you type leaves your device")
                step(3, "Come back and practice below.")
                settingsButton
                Divider()
                fullAccessNote(link: true)
            }
            .padding(.vertical, 6)
        } header: {
            Text("Start your free week")
        }
    }

    static let withoutFullAccessShort = "without it, you still get \(FreePlan.wordsPerDay) free Thai words a day."
    static let withoutFullAccess = "Prefer to leave Full Access off? The keyboard still works, with \(FreePlan.wordsPerDay) free Thai words a day."

    private var readySection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 4) {
                    Text("You’re all set").font(.headline)
                    Text("Karaoke Thai works in every app. Try it below, then in LINE or Messages.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Button("Got it") { UserDefaults.standard.set(true, forKey: "app.readyShown"); readyShown = true }
                    .buttonStyle(.borderless).font(.subheadline.bold())
            }
            .padding(.vertical, 4)
        }
    }

    private var settingsButton: some View {
        Button { KeyboardSetup.openSettings() } label: {
            Text("Open Settings").fontWeight(.semibold).frame(maxWidth: .infinity) // centered: no hidden icon
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    /// What Full Access is for, in one sentence used everywhere.
    static let fullAccessWhy = "Full Access lets the keyboard remember your free week, know you’ve paid, and vibrate on key taps. That’s all."

    /// Apple's warning, answered where people see it.
    private func fullAccessNote(link: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill").font(.title2).foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 8) {
                Text("About Full Access").font(.subheadline.bold()).padding(.bottom, -4)
                Text("iOS warns that a keyboard with Full Access could send what you type. Karaoke Thai’s keyboard never goes online and collects no data.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text(Self.fullAccessWhy + " It’s optional: " + Self.withoutFullAccessShort)
                    .font(.footnote).foregroundStyle(.secondary)
                if link { Link("Privacy policy", destination: Brand.privacyURL).font(.footnote) }
            }
        }
        .padding(.vertical, 4)
    }

    private var practiceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Type").foregroundStyle(.secondary)
                    Text(challenge.typed).font(.title3.weight(.semibold))
                    if solved || done.contains(challenge.id) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            .accessibilityLabel("Done")
                    }
                    Spacer()
                    if !wordsUsedUp { Button(solved ? "Next" : "Skip") {
                        current += 1
                        text = ""
                    }
                    .bold(solved)
                    .buttonStyle(.borderless) }
                }
                HStack {
                    Text("\(challenge.thai) · \(challenge.meaning)")
                    Spacer()
                    Text("\(done.count) of \(Self.challenges.count)")
                }
                .font(.footnote).foregroundStyle(.secondary)
            }
            if wordsUsedUp {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No free Thai words left today").font(.body.weight(.medium))
                        Text("\(FreePlan.wordsPerDay) more at midnight.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Unlock") { showUnlock = true }
                        .buttonStyle(.borderedProminent).fontWeight(.semibold)
                }
                .padding(.vertical, 4)
            } else {
            TextField("Type here with Karaoke Thai…", text: $text, axis: .vertical)
                .id(Self.practiceID)
                .font(.title3)
                .lineLimit(1...6)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onAppear { // open the keyboard right away, once, and only when it's added
                    if !autoFocused && added { autoFocused = true; focused = true }
                }
                .onChange(of: text) { _ in
                    if solved { done.insert(challenge.id) }
                }
            }
        } header: {
            Text("Practice")
        } footer: {
            // Only when it helps: nothing typed yet, or English letters went in instead of Thai.
            if text.isEmpty || !text.unicodeScalars.contains(where: { (0x0E00...0x0E7F).contains($0.value) }) {
                Text("No Thai guesses? Hold \(Image(systemName: "globe")) and pick Karaoke Thai")
            }
        }
    }

    private var spellingsSection: some View {
        Section {
            ForEach(Self.spellings, id: \.typed) { row in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.typed).font(.callout.weight(.medium))
                        Text(row.meaning).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(row.thai).font(.title3)
                }
            }
        } header: {
            Text("Spell it your way")
        } footer: {
            Text("Every spelling on a row gives the same Thai")
        }
    }

    private var tipsSection: some View {
        Section("Keyboard tips") {
            tip(Text("Space or Return"), "Types the first Thai guess")
            tip(Text("Tap a guess"), "Types that one instead")
            tip(Text("แชท (chat) button"), "Sits at the right of the bar before you start a word. Turns chat spelling on or off: krap gives คับ, jing gives จิง. While it’s on, it also stays in the bar as you type.")
            tip(Text("สวัสดี ") + Text("+krap").font(.subheadline).foregroundColor(.secondary),
                "Some guesses show a gray +word. Pick สวัสดี and ครับ comes up as the next guess.")
            tip(Text("EN / ไทย key"), "Switches between Thai guesses and plain English. Like Apple’s ABC key, it shows the mode you’ll switch to.")
            Button { withAnimation { showMoreTips.toggle() } } label: {
                HStack {
                    Text("More tips").foregroundStyle(.tint)
                    Spacer()
                    Image(systemName: showMoreTips ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundColor(Color(.tertiaryLabel))
                }
            }
            if showMoreTips {
                tip(Text("Stretch a word"), "Repeat the last letter: krappp gives ครับบบ")
                tip(Text("Typed letters"), "Tap the letters at the left of the bar to keep them as English")
                tip(Text("Palette button"), "At the right of the bar, before you type. Changes the key colors.")
                tip(Text("Your picks"), "Words you pick come first next time")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            if added {
                Button { KeyboardSetup.openSettings() } label: {
                    captioned("Keyboard settings", "Manage keyboards and Full Access", icon: "gearshape")
                }
            }
            Link(destination: Brand.reviewURL) {
                captioned("Rate Karaoke Thai", "It helps other people find the keyboard", icon: "star")
            }
            Link(destination: Brand.supportURL) {
                captioned("Help and contact", "Questions, or a word it got wrong?", icon: "questionmark.circle")
            }
            Link(destination: Brand.privacyURL) {
                captioned("Privacy policy", "The full details", icon: "lock.doc")
            }
        } header: {
            Text("Support")
        }
    }

    // MARK: free plan and rating

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

    // MARK: pieces

    private func step(_ n: Int, _ s: LocalizedStringKey, note: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(n)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor))
            VStack(alignment: .leading, spacing: 3) {
                Text(s)
                if let note {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.shield.fill")
                        Text(note)
                    }
                    .font(.footnote).foregroundStyle(.green)
                }
            }
        }
    }

    /// A row title with a grey caption lined up under it (not under the icon).
    private func captioned(_ title: String, _ caption: String, icon: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(caption).font(.footnote).foregroundColor(Color(.secondaryLabel))
            }
        } icon: { Image(systemName: icon) }
    }

    private func tip(_ key: Text, _ what: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            key.bold()
            Text(what).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// What the app knows of the free plan, from the keyboard's last report.
struct PlanStatus {
    enum Kind { case trial(daysLeft: Int), words(left: Int), unknown }
    let kind: Kind

    static func current(now: Date = Date()) -> PlanStatus {
        if let end = KeyboardReport.trialEnds(), end > now {
            return PlanStatus(kind: .trial(daysLeft: max(1, Int((end.timeIntervalSince(now) / 86_400).rounded(.up)))))
        }
        if let left = KeyboardReport.wordsLeft(now: now) { return PlanStatus(kind: .words(left: left)) }
        return PlanStatus(kind: .unknown)
    }

    /// The free week is over: the unlock is worth showing near the top.
    var icon: String {
        switch kind {
        case .trial: return "clock"
        case .words: return "clock"
        case .unknown: return "gift"
        }
    }

    var urgent: Bool { if case .words = kind { return true }; return false }

    var title: String {
        switch kind {
        case .trial(let d): return d == 1 ? "Free week: last day" : "Free week: \(d) days left"
        case .words(let n): return n == 0 ? "No free words left today" : "\(n) of \(FreePlan.wordsPerDay) free words left today"
        case .unknown: return "Free: \(FreePlan.trialDays) days unlimited, then \(FreePlan.wordsPerDay) Thai words a day"
        }
    }

    var detail: String {
        switch kind {
        case .trial: return "Then \(FreePlan.wordsPerDay) free Thai words a day"
        case .words(let n): return n == 0 ? "\(FreePlan.wordsPerDay) more at midnight" : "Back to \(FreePlan.wordsPerDay) at midnight"
        case .unknown: return "The free week starts the first time you type with Full Access on"
        }
    }
}

/// An example of typing by sound, drawn like a chat bubble so it doesn't look like a button.
struct DemoBubble: View {
    let typed: String
    let thai: String

    var body: some View {
        HStack(spacing: 10) {
            Text(typed).font(.body.weight(.medium)).foregroundStyle(.secondary)
            Image(systemName: "arrow.right").font(.footnote.bold()).foregroundStyle(Brand.gradient)
            Text(thai).font(.title3.bold())
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.10), in: UnevenRoundedRectangleCompat())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(typed) becomes \(thai)")
    }
}

/// A chat-bubble shape (square bottom-left corner) that works on iOS 16.
struct UnevenRoundedRectangleCompat: Shape {
    var radius: CGFloat = 16
    var small: CGFloat = 4

    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + radius), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addQuadCurve(to: CGPoint(x: r.maxX - radius, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + small, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - small), control: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        p.addQuadCurve(to: CGPoint(x: r.minX + radius, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.closeSubpath()
        return p
    }
}

extension View {
    /// Same gap between all sections, so the first header doesn't float (iOS 17 and later).
    @ViewBuilder func compactSections() -> some View {
        if #available(iOS 17.0, *) {
            self.listSectionSpacing(.compact).contentMargins(.top, 12, for: .scrollContent)
        } else { self }
    }
}
