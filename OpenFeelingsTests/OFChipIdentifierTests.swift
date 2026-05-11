import XCTest
@testable import OpenFeelings

final class OFChipIdentifierTests: XCTestCase {
    func testSingleWordLabelLowercased() {
        XCTAssertEqual(OFChip.identifier(for: "Chest"), "chip.chest")
    }

    func testMultiWordLabelSeparatedByDash() {
        XCTAssertEqual(OFChip.identifier(for: "Whole body"), "chip.whole-body")
    }

    func testSlashAndOtherSeparatorsCollapseToDash() {
        XCTAssertEqual(OFChip.identifier(for: "Stuck/heavy"), "chip.stuck-heavy")
        XCTAssertEqual(OFChip.identifier(for: "Hot · prickly"), "chip.hot-prickly")
    }

    func testLeadingAndTrailingSeparatorsAreTrimmed() {
        XCTAssertEqual(OFChip.identifier(for: " spaced "), "chip.spaced")
        XCTAssertEqual(OFChip.identifier(for: "-hyphenated-"), "chip.hyphenated")
    }

    func testEmptyLabelProducesNoSuffix() {
        XCTAssertEqual(OFChip.identifier(for: ""), "chip.")
    }

    func testNumericLabelPreserved() {
        XCTAssertEqual(OFChip.identifier(for: "Top 3"), "chip.top-3")
    }
}
