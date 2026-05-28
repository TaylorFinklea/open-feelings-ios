import StoreKit

/// Outcome of a purchase attempt, reduced to the three cases callers care
/// about. Our own type (StoreKit's `Product.PurchaseResult` isn't
/// `Equatable`), so it's freely mockable in tests.
enum StoreKitPurchaseOutcome: Sendable, Equatable {
    case success
    case userCancelled
    case pending
}

/// App-agnostic StoreKit 2 surface. Lift this whole file into any project
/// that needs IAP — it knows nothing about Open Feelings or tips.
protocol StoreKitClienting: Sendable {
    func products(for ids: [String]) async throws -> [Product]
    func purchase(_ product: Product) async throws -> StoreKitPurchaseOutcome
    /// Starts a long-lived task that finishes interrupted/Ask-to-Buy
    /// transactions as they resolve. Call once at app launch.
    func observeTransactions() -> Task<Void, Never>
}

struct StoreKitClient: StoreKitClienting {
    func products(for ids: [String]) async throws -> [Product] {
        try await Product.products(for: ids)
    }

    func purchase(_ product: Product) async throws -> StoreKitPurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            // A tip grants nothing, so there's nothing to gate on
            // verification — but we must finish the transaction either
            // way to clear it from the payment queue.
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
            case .unverified(let transaction, _):
                await transaction.finish()
            }
            return .success
        case .userCancelled:
            return .userCancelled
        case .pending:
            return .pending
        @unknown default:
            return .pending
        }
    }

    func observeTransactions() -> Task<Void, Never> {
        Task.detached {
            for await update in Transaction.updates {
                switch update {
                case .verified(let transaction):
                    await transaction.finish()
                case .unverified(let transaction, _):
                    await transaction.finish()
                }
            }
        }
    }
}
