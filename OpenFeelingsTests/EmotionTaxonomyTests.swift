import XCTest
@testable import OpenFeelings

final class EmotionTaxonomyTests: XCTestCase {
    func testTaxonomyHasExpectedShape() {
        XCTAssertEqual(EmotionTaxonomy.cores.count, 5)
        XCTAssertEqual(EmotionTaxonomy.cores.reduce(0) { $0 + $1.secondaries.count }, 25)
        XCTAssertEqual(
            EmotionTaxonomy.cores.reduce(0) { total, core in
                total + core.secondaries.reduce(0) { $0 + $1.specifics.count }
            },
            50
        )

        for core in EmotionTaxonomy.cores {
            XCTAssertGreaterThan(core.leafCount, 0, core.name)
            XCTAssertFalse(core.colorHex.isEmpty)

            for secondary in core.secondaries {
                XCTAssertFalse(secondary.colorHex.isEmpty)
                XCTAssertGreaterThan(secondary.leafCount, 0, "\(core.name) > \(secondary.name)")

                for specific in secondary.specifics {
                    XCTAssertFalse(specific.colorHex.isEmpty)
                }
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
            coreID: "happy",
            secondaryID: "peaceful",
            specificID: "thankful"
        )

        XCTAssertEqual(selection?.pathTitle, "Happy > Peaceful > Thankful")
        XCTAssertEqual(selection?.isComplete, true)
    }

    func testEveryEmotionNodeHasDefinition() {
        for core in EmotionTaxonomy.cores {
            XCTAssertTrue(EmotionDefinitions.hasDefinition(for: core.id), core.name)

            for secondary in core.secondaries {
                XCTAssertTrue(EmotionDefinitions.hasDefinition(for: secondary.id), "\(core.name) > \(secondary.name)")

                for specific in secondary.specifics {
                    XCTAssertTrue(
                        EmotionDefinitions.hasDefinition(for: specific.id),
                        "\(core.name) > \(secondary.name) > \(specific.name)"
                    )
                }
            }
        }
    }

    func testSelectionUsesMostSpecificDefinition() {
        let broadSelection = EmotionTaxonomy.selection(coreID: "happy", secondaryID: nil, specificID: nil)
        XCTAssertEqual(broadSelection?.definition.title, "Happy")

        let secondarySelection = EmotionTaxonomy.selection(
            coreID: "happy",
            secondaryID: "peaceful",
            specificID: nil
        )
        XCTAssertEqual(secondarySelection?.definition.title, "Peaceful")

        let specificSelection = EmotionTaxonomy.selection(
            coreID: "happy",
            secondaryID: "peaceful",
            specificID: "thankful"
        )
        XCTAssertEqual(specificSelection?.definition.title, "Thankful")
    }

    func testDefinitionReferencesAreDocumented() {
        XCTAssertFalse(EmotionDefinitions.sourceSummary.isEmpty)
        XCTAssertFalse(EmotionDefinitions.disclaimer.isEmpty)
        XCTAssertGreaterThanOrEqual(EmotionDefinitions.referenceURLs.count, 5)
    }

    func testTaxonomyCarriesAttribution() {
        XCTAssertEqual(EmotionTaxonomy.sourceName, "Open Emotion Wheel v1.1")
        XCTAssertEqual(EmotionTaxonomy.sourceLicenseName, "CC BY-SA 4.0")
        XCTAssertTrue(EmotionTaxonomy.sourceAttribution.contains("openemotionwheel.com"))
    }
}
