import StoreKit

/// App-specific tip-jar state. Loads the three consumable tiers and runs
/// fire-and-forget purchases — tips unlock nothing, so there's no
/// entitlement state to persist. `thankedProductID` and `purchaseFailed`
/// are transient flags the view reads to show a gentle in-place
/// acknowledgment or a quiet error.
@MainActor
@Observable
final class TipJarService {
    enum LoadState: Equatable { case idle, loading, loaded, failed }

    static let productIDs = [
        "dev.finklea.openfeelings.tip.soda",
        "dev.finklea.openfeelings.tip.lunch",
        "dev.finklea.openfeelings.tip.dinner",
    ]

    private(set) var tiers: [Product] = []
    private(set) var loadState: LoadState = .idle
    private(set) var thankedProductID: String?
    private(set) var purchaseFailed = false

    private let client: StoreKitClienting

    init(client: StoreKitClienting = StoreKitClient()) {
        self.client = client
    }

    func load() async {
        loadState = .loading
        do {
            let products = try await client.products(for: Self.productIDs)
            tiers = products.sorted { $0.price < $1.price }
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    func tip(_ product: Product) async {
        purchaseFailed = false
        do {
            let outcome = try await client.purchase(product)
            if outcome == .success {
                thankedProductID = product.id
            }
        } catch {
            purchaseFailed = true
        }
    }

    func clearThanks() {
        thankedProductID = nil
    }
}
