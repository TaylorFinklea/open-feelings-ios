import XCTest
@testable import OpenFeelings

final class ThinkingPatternTests: XCTestCase {
    func testHasExactlyEightCases() {
        XCTAssertEqual(ThinkingPattern.allCases.count, 8)
    }

    func testEveryCaseHasNonEmptyDisplayNameAndDescription() {
        for pattern in ThinkingPattern.allCases {
            XCTAssertFalse(pattern.displayName.isEmpty,
                           "displayName empty for \(pattern.rawValue)")
            XCTAssertFalse(pattern.description.isEmpty,
                           "description empty for \(pattern.rawValue)")
        }
    }

    func testRawValuesAreLowerCamelCaseSlugs() {
        let regex = #"^[a-z][A-Za-z0-9]*$"#
        for pattern in ThinkingPattern.allCases {
            XCTAssertNotNil(
                pattern.rawValue.range(of: regex, options: .regularExpression),
                "rawValue is not lowerCamelCase: \(pattern.rawValue)"
            )
        }
    }

    func testEncodeListAndParseListRoundTrip() {
        let list: [ThinkingPattern] = [.blackAndWhite, .mindReading, .alwaysNever]
        let raw = ThinkingPattern.encodeList(list)
        XCTAssertEqual(ThinkingPattern.parseList(raw), list)
    }

    func testParseListDropsUnknownRawValues() {
        let raw = "mindReading,notARealPattern,alwaysNever"
        XCTAssertEqual(ThinkingPattern.parseList(raw),
                       [.mindReading, .alwaysNever])
    }

    func testParseEmptyStringYieldsEmpty() {
        XCTAssertEqual(ThinkingPattern.parseList(""), [])
    }

    func testEncodeEmptyListYieldsEmptyString() {
        XCTAssertEqual(ThinkingPattern.encodeList([]), "")
    }
}
