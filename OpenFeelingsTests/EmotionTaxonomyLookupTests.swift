// OpenFeelingsTests/EmotionTaxonomyLookupTests.swift
import XCTest
@testable import OpenFeelings

final class EmotionTaxonomyLookupTests: XCTestCase {
    func testResolvesCoreNameCaseInsensitively() {
        let node = EmotionTaxonomy.node(named: "fearful")
        XCTAssertEqual(node?.core.name, "Fearful")
        XCTAssertNil(node?.secondary)
        XCTAssertNil(node?.specific)
    }

    func testResolvesSecondaryNameToItsCore() {
        let node = EmotionTaxonomy.node(named: "Anxious")
        XCTAssertEqual(node?.core.name, "Fearful")
        XCTAssertEqual(node?.secondary?.name, "Anxious")
        XCTAssertNil(node?.specific)
    }

    func testResolvesSpecificNameWithFullPath() {
        let node = EmotionTaxonomy.node(named: "Nervous")
        XCTAssertEqual(node?.core.name, "Fearful")
        XCTAssertEqual(node?.secondary?.name, "Threatened")
        XCTAssertEqual(node?.specific?.name, "Nervous")
    }

    func testUnknownNameReturnsNil() {
        XCTAssertNil(EmotionTaxonomy.node(named: "banana"))
    }

    func testAllNodeNamesAreGloballyUnique() {
        let names = EmotionTaxonomy.allNodeNames.map { $0.lowercased() }
        XCTAssertEqual(names.count, Set(names).count, "Taxonomy node names must be globally unique")
    }
}
