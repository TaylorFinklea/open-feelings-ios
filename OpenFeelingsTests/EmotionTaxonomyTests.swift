import XCTest
@testable import OpenFeelings

final class EmotionTaxonomyTests: XCTestCase {
    func testTaxonomyHasExpectedShape() {
        XCTAssertEqual(EmotionTaxonomy.cores.count, 8)

        for core in EmotionTaxonomy.cores {
            XCTAssertEqual(core.secondaries.count, 4, core.name)

            for secondary in core.secondaries {
                XCTAssertEqual(secondary.specifics.count, 3, "\(core.name) > \(secondary.name)")
            }
        }
    }

    func testTaxonomyHasStableNonEmptyIDsAndLabels() {
        var ids = Set<String>()

        for core in EmotionTaxonomy.cores {
            XCTAssertFalse(core.id.isEmpty)
            XCTAssertFalse(core.name.isEmpty)
            XCTAssertTrue(ids.insert(core.id).inserted)

            for secondary in core.secondaries {
                XCTAssertFalse(secondary.id.isEmpty)
                XCTAssertFalse(secondary.name.isEmpty)
                XCTAssertTrue(ids.insert("\(core.id).\(secondary.id)").inserted)

                for specific in secondary.specifics {
                    XCTAssertFalse(specific.id.isEmpty)
                    XCTAssertFalse(specific.name.isEmpty)
                    XCTAssertTrue(ids.insert("\(core.id).\(secondary.id).\(specific.id)").inserted)
                }
            }
        }
    }

    func testSelectionLookupBuildsCompletePath() {
        let selection = EmotionTaxonomy.selection(
            coreID: "joy",
            secondaryID: "grateful",
            specificID: "thankful"
        )

        XCTAssertEqual(selection?.pathTitle, "Joy > Grateful > Thankful")
        XCTAssertEqual(selection?.isComplete, true)
    }
}
