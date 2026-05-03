import XCTest
@testable import OpenFeelings

final class TriggerCopingTaxonomyTests: XCTestCase {
    func testEveryTriggerHasDisplayName() {
        for t in Trigger.allCases {
            XCTAssertFalse(t.displayName.isEmpty, "trigger \(t.rawValue) missing displayName")
        }
    }

    func testEveryCopingHasDisplayName() {
        for c in Coping.allCases {
            XCTAssertFalse(c.displayName.isEmpty, "coping \(c.rawValue) missing displayName")
        }
    }

    func testTriggerRoundTrip() {
        let all = Trigger.allCases
        let raw = Trigger.encodeList(all)
        XCTAssertEqual(Trigger.parseList(raw), all)
    }

    func testCopingRoundTrip() {
        let all = Coping.allCases
        let raw = Coping.encodeList(all)
        XCTAssertEqual(Coping.parseList(raw), all)
    }

    func testTriggerParseListIgnoresUnknownTokens() {
        XCTAssertEqual(Trigger.parseList("conflict,not-a-trigger,sleep"), [.conflict, .sleep])
    }

    func testTriggerParseListEmptyStringYieldsEmptyArray() {
        XCTAssertEqual(Trigger.parseList(""), [])
    }

    func testCopingParseListIgnoresUnknownTokens() {
        XCTAssertEqual(Coping.parseList("breath,glitched,walk"), [.breath, .walk])
    }
}
