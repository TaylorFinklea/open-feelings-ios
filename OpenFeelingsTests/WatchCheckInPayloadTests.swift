import XCTest
@testable import OpenFeelings

final class WatchCheckInPayloadTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let original = WatchCheckInPayload(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            coreID: "happy",
            coreName: "Happy",
            intensity: 4,
            note: "after a long walk"
        )

        let data = try WatchCheckInPayload.encoder.encode(original)
        let decoded = try WatchCheckInPayload.decoder.decode(WatchCheckInPayload.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testUserInfoDictionaryEncodesAndDecodes() throws {
        // Use a fixed whole-second Date; ISO 8601 encoding rounds to seconds and we
        // don't need sub-second precision for check-in timestamps.
        let original = WatchCheckInPayload(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_042),
            coreID: "fearful",
            coreName: "Fearful",
            intensity: nil,
            note: nil
        )

        let dict = try original.userInfoDictionary()
        XCTAssertNotNil(dict[WatchCheckInPayload.userInfoVersionKey] as? Data)

        let decoded = WatchCheckInPayload.decode(userInfo: dict)
        XCTAssertEqual(decoded, original)
    }

    func testDecodeReturnsNilForMissingVersionKey() {
        let decoded = WatchCheckInPayload.decode(userInfo: ["other": Data()])
        XCTAssertNil(decoded)
    }

    func testDecodeReturnsNilForInvalidData() {
        let decoded = WatchCheckInPayload.decode(userInfo: [
            WatchCheckInPayload.userInfoVersionKey: Data("not json".utf8)
        ])
        XCTAssertNil(decoded)
    }
}
