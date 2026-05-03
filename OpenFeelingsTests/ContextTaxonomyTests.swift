import XCTest
@testable import OpenFeelings

final class ContextTaxonomyTests: XCTestCase {
    func testEveryPlaceHasDisplayName() {
        for place in ContextPlace.allCases {
            XCTAssertFalse(place.displayName.isEmpty, "place \(place.rawValue) missing displayName")
        }
    }

    func testEveryPeopleHasDisplayName() {
        for people in ContextPeople.allCases {
            XCTAssertFalse(people.displayName.isEmpty, "people \(people.rawValue) missing displayName")
        }
    }

    func testPlaceRoundTrip() {
        let all = ContextPlace.allCases
        let raw = ContextPlace.encodeList(all)
        XCTAssertEqual(ContextPlace.parseList(raw), all)
    }

    func testPeopleRoundTrip() {
        let all = ContextPeople.allCases
        let raw = ContextPeople.encodeList(all)
        XCTAssertEqual(ContextPeople.parseList(raw), all)
    }

    func testPlaceParseListIgnoresUnknownTokens() {
        XCTAssertEqual(ContextPlace.parseList("home,not-a-place,work"), [.home, .work])
    }

    func testPlaceParseListEmptyStringYieldsEmptyArray() {
        XCTAssertEqual(ContextPlace.parseList(""), [])
    }

    func testPeopleParseListIgnoresUnknownTokens() {
        XCTAssertEqual(ContextPeople.parseList("alone,robot,family"), [.alone, .family])
    }
}
