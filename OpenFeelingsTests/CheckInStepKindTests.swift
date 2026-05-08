import XCTest
@testable import OpenFeelings

final class CheckInStepKindTests: XCTestCase {
    func testAllKindsHaveStorageKey() {
        for kind in CheckInStepKind.allCases {
            XCTAssertFalse(kind.storageKey.isEmpty, "kind \(kind) missing storageKey")
        }
    }

    func testStorageKeysAreUnique() {
        let keys = CheckInStepKind.allCases.map(\.storageKey)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testParseListIgnoresUnknownTokens() {
        XCTAssertEqual(CheckInStepKind.parseList("strength,not-a-thing,context"),
                       [.strength, .context])
    }

    func testEncodeListRoundTrip() {
        let all: [CheckInStepKind] = [.strength, .sensations, .mood]
        let raw = CheckInStepKind.encodeList(all)
        XCTAssertEqual(CheckInStepKind.parseList(raw), all)
    }
}
