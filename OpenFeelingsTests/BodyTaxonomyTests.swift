import XCTest
@testable import OpenFeelings

final class BodyTaxonomyTests: XCTestCase {
    // MARK: - Display names

    func testEveryRegionHasDisplayName() {
        for region in BodyRegion.allCases {
            XCTAssertFalse(region.displayName.isEmpty, "region \(region.rawValue) missing displayName")
        }
    }

    func testEverySensationHasDisplayName() {
        for sensation in BodySensation.allCases {
            XCTAssertFalse(sensation.displayName.isEmpty, "sensation \(sensation.rawValue) missing displayName")
        }
    }

    // MARK: - Round-trip via raw strings

    func testRegionRoundTrip() {
        let all = BodyRegion.allCases
        let raw = BodyRegion.encodeList(all)
        XCTAssertEqual(BodyRegion.parseList(raw), all)
    }

    func testSensationRoundTrip() {
        let all = BodySensation.allCases
        let raw = BodySensation.encodeList(all)
        XCTAssertEqual(BodySensation.parseList(raw), all)
    }

    // MARK: - Lenient parsing

    func testRegionParseListIgnoresUnknownTokens() {
        XCTAssertEqual(BodyRegion.parseList("head,not-a-thing,chest"), [.head, .chest])
    }

    func testRegionParseListEmptyStringYieldsEmptyArray() {
        XCTAssertEqual(BodyRegion.parseList(""), [])
    }

    func testSensationParseListIgnoresUnknownTokens() {
        XCTAssertEqual(BodySensation.parseList("tight,glitched,warm"), [.tight, .warm])
    }
}
