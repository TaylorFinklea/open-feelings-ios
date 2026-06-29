import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class WatchSessionClientSharedTests: XCTestCase {
    func testSharedIsSingleInstance() {
        XCTAssertTrue(WatchSessionClient.shared === WatchSessionClient.shared)
    }
}
