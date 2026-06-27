// OpenFeelingsTests/FeelingSynonymsTests.swift
import XCTest
@testable import OpenFeelings

final class FeelingSynonymsTests: XCTestCase {
    func testEveryEntryResolvesToARealNode() {
        for entry in FeelingSynonyms.entries {
            XCTAssertNotNil(
                EmotionTaxonomy.node(named: entry.targetName),
                "Synonym '\(entry.phrase)' targets unknown node '\(entry.targetName)'"
            )
        }
    }

    func testEveryCoreIsReachableBySomeSynonymOrItsOwnName() {
        for core in EmotionTaxonomy.cores {
            let reachable = EmotionTaxonomy.node(named: core.name) != nil
                || FeelingSynonyms.entries.contains {
                    EmotionTaxonomy.node(named: $0.targetName)?.core.name == core.name
                }
            XCTAssertTrue(reachable, "Core '\(core.name)' has no synonym path")
        }
    }

    func testPhrasesAreLowercasedAndNonEmpty() {
        for entry in FeelingSynonyms.entries {
            XCTAssertFalse(entry.phrase.isEmpty)
            XCTAssertEqual(entry.phrase, entry.phrase.lowercased())
        }
    }
}
