import Observation
import StoreKit

/// Покупки через StoreKit 2. В сборке для SideStore (флаг SIDELOAD) App Store недоступен,
/// поэтому покупки там тестовые: выдаются сразу и бесплатно.
@MainActor
@Observable
final class Store {
    static let shared = Store()

    #if SIDELOAD
    static let testMode = true
    #else
    static let testMode = false
    #endif

    private(set) var products: [String: Product] = [:]
    private(set) var busy: ProductID?
    var errorMessage: String?

    @ObservationIgnored private var updates: Task<Void, Never>?

    private init() {}

    func start() {
        #if !SIDELOAD
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    self?.apply(transaction)
                    await transaction.finish()
                }
            }
        }
        Task {
            await load()
            await refresh()
        }
        #endif
    }

    func price(_ id: ProductID) -> String {
        products[id.rawValue]?.displayPrice ?? id.fallbackPrice
    }

    private func load() async {
        do {
            let list = try await Product.products(for: ProductID.allCases.map(\.rawValue))
            for product in list { products[product.id] = product }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Восстанавливает всё купленное раньше: покупки разовые и хранятся в App Store.
    private func refresh() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result { apply(transaction) }
        }
    }

    private func apply(_ transaction: Transaction) {
        guard let id = ProductID(rawValue: transaction.productID) else { return }
        if transaction.revocationDate != nil {
            // Покупку вернули через Apple: забираем то, что она давала.
            GameState.shared.revoke(id)
        } else {
            GameState.shared.grant(id)
        }
    }

    func buy(_ id: ProductID) async {
        guard busy == nil else { return }
        busy = id
        defer { busy = nil }
        #if SIDELOAD
        try? await Task.sleep(for: .milliseconds(500))
        GameState.shared.grant(id)
        GameState.shared.toast("🧪", tr("shop.testPurchase"))
        #else
        if products[id.rawValue] == nil { await load() }
        guard let product = products[id.rawValue] else {
            errorMessage = tr("shop.unavailable")
            return
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    apply(transaction)
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }

    func restore() async {
        #if SIDELOAD
        GameState.shared.toast("🧪", tr("shop.testRestore"))
        #else
        do {
            try await AppStore.sync()
            await refresh()
            GameState.shared.toast("✅", tr("shop.restored"))
        } catch {
            errorMessage = error.localizedDescription
        }
        #endif
    }
}
