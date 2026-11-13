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
        // Downloaded while the app was paid: everything stays unlocked. App Store downloads
        // only: in TestFlight and the sandbox originalAppVersion is always "1.0".
        if !owned, case .verified(let app)? = try? await AppTransaction.shared, app.environment == .production {
            owned = app.originalAppVersion.compare(Self.firstFreeBuild, options: .numeric) == .orderedAscending
        }
        unlocked = owned
        SharedState.unlocked = owned // for the keyboard (read while Full Access is on)
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
                    Text("Free: \(7) days unlimited, then \(50) Thai words a day.")
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
