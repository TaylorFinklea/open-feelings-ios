import XCTest
import StoreKit
import StoreKitTest
@testable import OpenFeelings

@MainActor
final class TipJarServiceTests: XCTestCase {
    private var session: SKTestSession!
    private var products: [Product]!

    override func setUp() async throws {
        session = try SKTestSession(configurationFileNamed: "OpenFeelings")
        session.clearTransactions()
        session.disableDialogs = true
        products = try await Product.products(for: TipJarService.productIDs)
        try XCTSkipIf(products.count != 3,
                      "StoreKit test config did not load 3 products")
    }

    override func tearDown() {
        session = nil
        products = nil
    }

    private struct DummyError: Error {}

    private struct MockClient: StoreKitClienting {
        var productsResult: Result<[Product], Error>
        var purchaseResult: Result<StoreKitPurchaseOutcome, Error>
        func products(for ids: [String]) async throws -> [Product] {
            try productsResult.get()
        }
        func purchase(_ product: Product) async throws -> StoreKitPurchaseOutcome {
            try purchaseResult.get()
        }
        func observeTransactions() -> Task<Void, Never> { Task {} }
    }

    func testLoadSuccessSortsTiersByPriceAscending() async {
        let svc = TipJarService(client: MockClient(
            productsResult: .success(products.shuffled()),
            purchaseResult: .success(.success)))
        await svc.load()
        let prices = svc.tiers.map(\.price)
        XCTAssertEqual(prices, prices.sorted())
        XCTAssertEqual(svc.tiers.count, 3)
    }

    func testLoadSuccessSetsLoadedState() async {
        let svc = TipJarService(client: MockClient(
            productsResult: .success(products),
            purchaseResult: .success(.success)))
        await svc.load()
        XCTAssertEqual(svc.loadState, .loaded)
    }

    func testLoadFailureSetsFailedState() async {
        let svc = TipJarService(client: MockClient(
            productsResult: .failure(DummyError()),
            purchaseResult: .success(.success)))
        await svc.load()
        XCTAssertEqual(svc.loadState, .failed)
    }

    func testTipSuccessSetsThankedProductID() async {
        let svc = TipJarService(client: MockClient(
            productsResult: .success(products),
            purchaseResult: .success(.success)))
        await svc.tip(products[0])
        XCTAssertEqual(svc.thankedProductID, products[0].id)
        XCTAssertFalse(svc.purchaseFailed)
    }

    func testTipCancelLeavesThankedProductIDNil() async {
        let svc = TipJarService(client: MockClient(
            productsResult: .success(products),
            purchaseResult: .success(.userCancelled)))
        await svc.tip(products[0])
        XCTAssertNil(svc.thankedProductID)
        XCTAssertFalse(svc.purchaseFailed)
    }

    func testTipErrorSetsPurchaseFailed() async {
        let svc = TipJarService(client: MockClient(
            productsResult: .success(products),
            purchaseResult: .failure(DummyError())))
        await svc.tip(products[0])
        XCTAssertTrue(svc.purchaseFailed)
        XCTAssertNil(svc.thankedProductID)
    }
}
