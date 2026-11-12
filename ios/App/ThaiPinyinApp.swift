import SwiftUI

@main
struct ThaiPinyinApp: App {
    var body: some Scene {
        WindowGroup { SetupView() }
    }
}

/// How to turn the keyboard on, and a box to try it.
struct SetupView: View {
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Type Thai by sound: **sawatdeekrap** → สวัสดีครับ, **kinkhao** → กินข้าว.")
                }
                Section("Try it") {
                    TextField("Type here…", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                        .autocorrectionDisabled()
                        .onAppear { focused = true } // open the keyboard right away
                }
                Section("Turn it on") {
                    step(1, "Open **Settings → General → Keyboard → Keyboards**.")
                    step(2, "Tap **Add New Keyboard…** and choose **Karaoke Thai**.")
                    step(3, "In any app, hold the 🌐 key and pick Karaoke Thai.")
                    step(4, "For a light tap on each key, tap **Karaoke Thai** there and turn on **Allow Full Access** (iOS requires it for haptics).")
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
