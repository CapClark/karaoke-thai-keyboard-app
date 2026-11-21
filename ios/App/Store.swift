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
            message = "Couldn't reach the App Store. Try again later."
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
            message = "The purchase didn't go through."
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
            message = "Couldn't restore. Try again later."
        }
    }
}

/// Shown on the setup screen only while `Store.enabled` is on.
struct UnlockSection: View {
    @ObservedObject var store: Store

    var body: some View {
        Section {
            if store.unlocked {
                Label("Unlocked: no daily limit. Thank you!", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Free: \(FreePlan.trialDays) days unlimited with Full Access on, then \(FreePlan.wordsPerDay) Thai words a day.")
                    Text("Unlock once for no limit, on all your devices.").foregroundStyle(.secondary)
                }
                Button {
                    Task { await store.buy() }
                } label: {
                    HStack {
                        Text("Unlock")
                        Spacer()
                        if let p = store.product { Text(p.displayPrice) } else { ProgressView() }
                    }
                }
                .disabled(store.product == nil || store.busy)
                Button("Restore purchase") { Task { await store.restore() } }
                    .disabled(store.busy)
                RedeemCodeButton()
            }
            if store.isTestBuild {
                Toggle("Act as not bought (test builds only)", isOn: $store.actAsNotBought)
                    .font(.footnote)
            }
            if let m = store.message {
                Text(m).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Unlimited")
        } footer: {
            Text("Bought Karaoke Thai before it was free? It's already unlocked.")
        }
    }
}

/// Opens Apple's sheet for an offer code (a free unlock). The unlock then arrives through
/// `Transaction.updates`, which the store is listening to.
struct RedeemCodeButton: View {
    @State private var redeeming = false

    var body: some View {
        Button("Redeem a code") { redeeming = true }
            .offerCodeRedemption(isPresented: $redeeming) { _ in }
    }
}

/// Offered when the free week is over or the day's free words ran out.
struct UnlockSheet: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "infinity.circle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.tint)
                        Text("Keep typing Thai, no limit").font(.title.bold())
                        Text("พิมพ์ไทยได้ไม่จำกัด").font(.title3).foregroundStyle(.secondary)
                    }
                    if store.unlocked {
                        Label("Unlocked. Thank you!", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(.green)
                    } else {
                        Text("The free plan gives \(FreePlan.wordsPerDay) Thai words a day. Unlock once to type as much as you like.")
                        VStack(alignment: .leading, spacing: 12) {
                            point("infinity", "Unlimited Thai words, every day")
                            point("ipad.and.iphone", "On all your iPhones and iPads")
                            point("checkmark.circle", "Pay once. No subscription")
                            point("lock.shield", "Still never connects to the internet")
                        }
                    }
                    if let m = store.message {
                        Text(m).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if store.unlocked {
                        Button { dismiss() } label: { Text("Done").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).controlSize(.large)
                    } else {
                        Button {
                            Task { await store.buy() }
                        } label: {
                            Group {
                                if let p = store.product { Text("Unlock for \(p.displayPrice)") } else { ProgressView() }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(store.product == nil || store.busy)
                        HStack {
                            Button("Restore") { Task { await store.restore() } }.disabled(store.busy)
                            Spacer()
                            RedeemCodeButton()
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(.bar)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !store.unlocked { Button("Not now") { dismiss() } }
                }
            }
        }
    }

    private func point(_ icon: String, _ text: String) -> some View {
        Label { Text(text) } icon: { Image(systemName: icon).foregroundStyle(.tint).frame(width: 28) }
    }
}
