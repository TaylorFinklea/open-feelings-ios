import HealthKit
import XCTest
@testable import OpenFeelings

final class HealthKitMapperTests: XCTestCase {
    func testJoyMapsToPleasantStateOfMind() {
        let mapping = HealthKitMapper.mapping(coreID: "joy", secondaryID: "hopeful")

        XCTAssertGreaterThan(mapping.valence, 0)
        XCTAssertTrue(mapping.labels.contains(.hopeful))
    }

    func testFearMapsToUnpleasantStateOfMind() {
        let mapping = HealthKitMapper.mapping(coreID: "fear", secondaryID: "alarmed")

        XCTAssertLessThan(mapping.valence, 0)
        XCTAssertTrue(mapping.labels.contains(.scared))
    }
}
