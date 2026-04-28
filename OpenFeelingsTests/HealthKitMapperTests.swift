import HealthKit
import XCTest
@testable import OpenFeelings

final class HealthKitMapperTests: XCTestCase {
    func testHappyMapsToPleasantStateOfMind() {
        let mapping = HealthKitMapper.mapping(coreID: "happy", secondaryID: "optimistic")

        XCTAssertGreaterThan(mapping.valence, 0)
        XCTAssertTrue(mapping.labels.contains(.hopeful))
    }

    func testFearfulMapsToUnpleasantStateOfMind() {
        let mapping = HealthKitMapper.mapping(coreID: "fearful", secondaryID: "threatened")

        XCTAssertLessThan(mapping.valence, 0)
        XCTAssertTrue(mapping.labels.contains(.scared))
    }
}
