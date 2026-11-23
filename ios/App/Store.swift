import StoreKit
import SwiftUI

/// The one-time unlock (StoreKit 2). Switched off with `enabled = false`: the app then
/// shows nothing about purchases. Keep `enabled`, `productID` and `firstFreeBuild` the same
/// as in Keyboard/Gate.swift.
@MainActor
final class Store: ObservableObject {
    static let enabled = true
    static let productID = "com.kenpeeranat.KaraokeThai.unlock"
    static let firstFreeBuild = "8"

    @Published private(set) var product: Product?
    @Published private(set) var unlocked = false
    @Published private(set) var busy = false
    @Published var message: String?
    /// Why the unlock screen was last offered: the day's words ran out, or the free week ended.
    @Published private(set) var limitReached = false
    /// TestFlight, the sandbox or Xcode: never true for App Store downloads.
    @Published private(set) var isTestBuild = false
    /// True once the first purchase check is done: before that `unlocked` is only a guess.
    @Published private(set) var checked = false
    /// Test builds only: act as if the unlock was never bought (TestFlight purchases are made
    /// with the tester's real Apple ID and can't be cleared or refunded).
    @Published var actAsNotBought = SharedState.testIgnorePurchase {
        didSet { SharedState.testIgnorePurchase = actAsNotBought; Task { await refresh() } }
    }

    private var updates: Task<Void, Never>?

    init() {
        guard Self.enabled else { return }
        updates = Task { [weak self] in
            for await _ in Transaction.updates { await self?.refresh() }
        }
        Task { await load() }
    }

    deinit { updates?.cancel() }

    func load() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            message = "Couldn’t reach the App Store. Try again later."
        }
        await refresh()
    }

    func refresh() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.productID, t.revocationDate == nil { owned = true }
        }
        let app: AppTransaction?
        if case .verified(let a)? = try? await AppTransaction.shared { app = a } else { app = nil }
        // TestFlight and the sandbox have a "sandboxReceipt"; used when AppTransaction can't answer.
        isTestBuild = app.map { $0.environment != .production }
            ?? (Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt")
        // Downloaded while the app was paid: everything stays unlocked. App Store downloads
        // only: in TestFlight and the sandbox originalAppVersion is always "1.0".
        if !owned, let app, app.environment == .production {
            owned = app.originalAppVersion.compare(Self.firstFreeBuild, options: .numeric) == .orderedAscending
        }
        if !isTestBuild && actAsNotBought { actAsNotBought = false } // never in App Store downloads
        if actAsNotBought { owned = false }
        unlocked = owned
        SharedState.unlocked = owned // for the keyboard (read while Full Access is on)
        checked = true
    }

    /// Should the unlock screen be offered now? Never before the purchase check, never to
    /// someone who has it; then when the keyboard hit the daily limit since it was last shown,
    /// or (the keyboard can't always tell the app) once the free week is over, every few days.
    func unlockDue(now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        guard Self.enabled, checked, !unlocked else { return false }
        let first = defaults.object(forKey: "app.firstOpen") as? Date ?? now
        if defaults.object(forKey: "app.firstOpen") == nil { defaults.set(now, forKey: "app.firstOpen") }
        let shown = defaults.object(forKey: "app.unlockShownAt") as? Date ?? .distantPast
        let limitHit = (SharedState.limitHitAt ?? .distantPast) > shown
        let trialOver = now.timeIntervalSince(first) >= Double(FreePlan.trialDays) * 86_400
        guard limitHit || (trialOver && now.timeIntervalSince(shown) >= 3 * 86_400) else { return false }
        defaults.set(now, forKey: "app.unlockShownAt")
        limitReached = limitHit
        return true
    }

    func buy() async {
        guard let product else { return }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                if case .verified(let t) = result { await t.finish() }
                await refresh()
            case .pending:
                message = "Waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn’t go through."
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refresh()
            if !unlocked { message = "No earlier purchase found for this Apple Account." }
        } catch {
            message = "Couldn’t restore. Try again later."
        }
    }
}

/// Shown on the setup screen only while `Store.enabled` is on: where the free plan stands,
/// and the unlock.
struct UnlockSection: View {
    @ObservedObject var store: Store

    var body: some View {
        Section {
            if store.unlocked {
                Label("Unlocked: no daily limit. Thank you!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                let status = PlanStatus.current()
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.title).font(.headline)
                        Text(status.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                } icon: { Image(systemName: status.icon).foregroundStyle(.secondary) }
                .padding(.vertical, 2)
                Button {
                    Task { await store.buy() }
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Unlock unlimited words").fontWeight(.semibold)
                                Text("Pay once, no subscription").font(.footnote).foregroundColor(Color(.secondaryLabel))
                            }
                        } icon: { Image(systemName: "infinity.circle") }
                        Spacer()
                        if let p = store.product { Text(p.displayPrice).bold() } else { ProgressView() }
                    }
                }
                .disabled(store.product == nil || store.busy)
                Button { Task { await store.restore() } } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Restore purchase")
                            Text("Bought it on another device?")
                                .font(.footnote).foregroundColor(Color(.secondaryLabel))
                        }
                    } icon: { Image(systemName: "arrow.clockwise") }
                }
                .disabled(store.busy)
                RedeemCodeButton(icon: true)
            }
            if store.isTestBuild {
                Toggle("Act as not bought (test builds only)", isOn: $store.actAsNotBought)
                    .font(.footnote)
            }
            if let m = store.message {
                Text(m).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Your plan")
        } footer: {
            Text("One purchase works on all your iPhones and iPads")
        }
    }
}

/// Opens Apple's sheet for an offer code (a free unlock). The unlock then arrives through
/// `Transaction.updates`, which the store is listening to.
struct RedeemCodeButton: View {
    var icon = false
    @State private var redeeming = false

    var body: some View {
        Button { redeeming = true } label: {
            if icon {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Redeem a code")
                        Text("Have an offer code?").font(.footnote).foregroundColor(Color(.secondaryLabel))
                    }
                } icon: { Image(systemName: "gift") }
            } else { Text("Redeem a code") }
        }
            .offerCodeRedemption(isPresented: $redeeming) { _ in }
    }
}

/// Offered when the free week is over or the day's free words ran out.
struct UnlockSheet: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image("Logo")
                            .resizable()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                            .accessibilityHidden(true)
                        Text(store.limitReached && !store.unlocked ? "No free words left today" : "Type Thai without limits").font(.title.bold())
                        Text(store.limitReached && !store.unlocked ? "ใช้ครบ \(FreePlan.wordsPerDay) คำของวันนี้แล้ว" : "พิมพ์ไทยได้ไม่จำกัด").font(.title3).foregroundStyle(.secondary)
                    }
                    if store.unlocked {
                        Label("Unlocked. Thank you!", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(.green)
                    } else {
                        Text(store.limitReached
                             ? "\(FreePlan.wordsPerDay) more at midnight"
                             : "Your free week is over. You still get \(FreePlan.wordsPerDay) free Thai words a day.")
                        VStack(alignment: .leading, spacing: 12) {
                            if store.limitReached { point("infinity.circle", "Unlimited Thai words, every day") }
                            point("ipad.and.iphone", "On all your iPhones and iPads")
                            point("tag", "Pay once, no subscription")
                            point("lock.shield", "Nothing you type leaves your device", color: .green)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            DemoBubble(typed: "kinkhaoyang", thai: "กินข้าวยัง")
                            Text("“Have you eaten yet?” The everyday Thai hello.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .accessibilityHidden(true)
                    }
                    if let m = store.message {
                        Text(m).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                // Sits on the buttons; any spare room goes at the top, under "Not now".
                .frame(minHeight: geo.size.height, alignment: .bottom)
            }
            }
            .safeAreaInset(edge: .bottom) {
                actions.padding(.horizontal, 24).padding(.bottom, 8).background(Color(.systemBackground))
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !store.unlocked { Button("Not now") { dismiss() } }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            if store.unlocked {
                Button { dismiss() } label: { Text("Done").fontWeight(.semibold).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                Button {
                    Task { await store.buy() }
                } label: {
                    Group {
                        if let p = store.product { Text("Unlock for \(p.displayPrice)").fontWeight(.semibold) } else { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(store.product == nil || store.busy)
                HStack {
                    Button("Restore purchase") { Task { await store.restore() } }.disabled(store.busy)
                    Spacer()
                    RedeemCodeButton()
                }
                .font(.subheadline)
                Text("Keep Full Access on so the keyboard sees your unlock")
                    .font(.footnote).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func point(_ icon: String, _ text: String, color: Color? = nil) -> some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: {
            Image(systemName: icon).resizable().scaledToFit().frame(width: 22, height: 22) // same box for every icon
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(color.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint)).frame(width: 28)
        }
    }
}
