import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class ValuesTests: XCTestCase {
    func testValueTaxonomyIntegrity() {
        let all = ValueTaxonomy.all
        XCTAssertGreaterThanOrEqual(all.count, 40, "expect ~50 curated values")

        let ids = all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate ids in taxonomy")

        let slugRegex = #"^[a-z][a-z0-9_]*$"#
        for def in all {
            XCTAssertFalse(def.name.isEmpty, "empty name for id=\(def.id)")
            XCTAssertFalse(def.description.isEmpty, "empty description for id=\(def.id)")
            XCTAssertNotNil(def.id.range(of: slugRegex, options: .regularExpression),
                            "id is not a lowercase slug: \(def.id)")
        }
    }
}
