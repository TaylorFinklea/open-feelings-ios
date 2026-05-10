import XCTest
@testable import OpenFeelings

final class IntentionTests: XCTestCase {
    func testReflectionDefaultsToEmpty() {
        let i = Intention(text: "Pause when I feel rushed.")
        XCTAssertEqual(i.reflection, "")
    }

    func testReflectionInitParameterPersists() {
        let i = Intention(text: "Be kind.", reflection: "Mostly went okay.")
        XCTAssertEqual(i.reflection, "Mostly went okay.")
    }

    func testNormalizedReflectionTrimsWhitespaceAndNewlines() {
        XCTAssertEqual(Intention.normalizedReflection("  foo  \n"), "foo")
    }

    func testNormalizedReflectionTreatsAllWhitespaceAsEmpty() {
        XCTAssertEqual(Intention.normalizedReflection("   \n  \t"), "")
    }

    func testNormalizedReflectionLeavesInteriorWhitespaceAlone() {
        XCTAssertEqual(Intention.normalizedReflection("  it was fine, mostly  "),
                       "it was fine, mostly")
    }
}
