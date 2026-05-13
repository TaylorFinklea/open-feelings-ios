import XCTest
@testable import OpenFeelings

final class WatchCheckInPayloadTests: XCTestCase {
    func testCodableRoundTripFullPayload() throws {
        let original = WatchCheckInPayload(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            coreID: "happy",
            coreName: "Happy",
            secondaryID: "optimistic",
            secondaryName: "Optimistic",
            specificID: "hopeful",
            specificName: "Hopeful",
            intensity: 4,
            bodyRegions: ["chest", "head"],
            bodySensations: ["warm", "fluttery"],
            note: "after a long walk"
        )

        let data = try WatchCheckInPayload.encoder.encode(original)
        let decoded = try WatchCheckInPayload.decoder.decode(WatchCheckInPayload.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.schemaVersion, 2)
    }

    func testCodableRoundTripCoreOnly() throws {
        // Watch lets the user stop at any drill level — minimal payloads must
        // round-trip cleanly.
        let original = WatchCheckInPayload(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            coreID: "sad",
            coreName: "Sad",
            intensity: 2
        )

        let data = try WatchCheckInPayload.encoder.encode(original)
        let decoded = try WatchCheckInPayload.decoder.decode(WatchCheckInPayload.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertNil(decoded.secondaryID)
        XCTAssertNil(decoded.specificName)
        XCTAssertTrue(decoded.bodyRegions.isEmpty)
        XCTAssertTrue(decoded.bodySensations.isEmpty)
    }

    func testUserInfoDictionaryEncodesAndDecodes() throws {
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

    func testDecodesLegacyV1PayloadWithoutNewFields() throws {
        // A v1 watch (still queued from before the upgrade) emits JSON missing
        // secondaryID/secondaryName/specificID/specificName/bodyRegions/bodySensations.
        // The v2 decoder must accept it and default the new fields cleanly so
        // queued offline entries are never dropped.
        let legacyJSON = """
        {
          "schemaVersion": 1,
          "id": "11111111-1111-1111-1111-111111111111",
          "createdAt": "2023-11-14T22:13:20Z",
          "coreID": "happy",
          "coreName": "Happy",
          "intensity": 3,
          "note": "queued before upgrade"
        }
        """
        let data = Data(legacyJSON.utf8)
        let decoded = try WatchCheckInPayload.decoder.decode(WatchCheckInPayload.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.coreName, "Happy")
        XCTAssertNil(decoded.secondaryID)
        XCTAssertNil(decoded.specificName)
        XCTAssertTrue(decoded.bodyRegions.isEmpty)
        XCTAssertTrue(decoded.bodySensations.isEmpty)
    }
}
