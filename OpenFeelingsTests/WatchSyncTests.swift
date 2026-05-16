import XCTest
import SwiftData
@testable import OpenFeelings

final class WatchSyncTests: XCTestCase {

    // MARK: - WatchCheckInPayload Codable

    func testPayloadCodableRoundTripPreservesAllFields() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = WatchCheckInPayload(
            id: id,
            createdAt: createdAt,
            coreID: "happy", coreName: "Happy",
            secondaryID: "optimistic", secondaryName: "Optimistic",
            specificID: "hopeful", specificName: "Hopeful",
            intensity: 4,
            bodyRegions: ["chest", "stomach"],
            bodySensations: ["warm"],
            note: "  sunny morning  "
        )
        let data = try WatchCheckInPayload.encoder.encode(payload)
        let decoded = try WatchCheckInPayload.decoder.decode(WatchCheckInPayload.self, from: data)
        XCTAssertEqual(decoded, payload)
    }

    /// v1 watch builds shipped before secondary/specific/body fields existed.
    /// Decoding a v1-shaped JSON must yield a v1 payload with sensible nil/empty
    /// defaults so a queued payload from an older watch can still drain.
    func testPayloadDecodesV1PayloadWithMissingFieldsDefaultedToNilOrEmpty() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        let iso = ISO8601DateFormatter().string(from: createdAt)
        let v1JSON = """
        {
          "schemaVersion": 1,
          "id": "\(id.uuidString)",
          "createdAt": "\(iso)",
          "coreID": "calm",
          "coreName": "Calm",
          "intensity": 3,
          "note": "ok"
        }
        """.data(using: .utf8)!

        let decoded = try WatchCheckInPayload.decoder.decode(WatchCheckInPayload.self, from: v1JSON)
        XCTAssertEqual(decoded.schemaVersion, 1)
        XCTAssertEqual(decoded.id, id)
        XCTAssertEqual(decoded.coreID, "calm")
        XCTAssertNil(decoded.secondaryID)
        XCTAssertNil(decoded.secondaryName)
        XCTAssertNil(decoded.specificID)
        XCTAssertEqual(decoded.intensity, 3)
        XCTAssertEqual(decoded.bodyRegions, [])
        XCTAssertEqual(decoded.bodySensations, [])
        XCTAssertEqual(decoded.note, "ok")
    }

    func testPayloadDecodesWithMissingSchemaVersionDefaultedToOne() throws {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_600_000_000)
        let iso = ISO8601DateFormatter().string(from: createdAt)
        let legacyJSON = """
        {"id":"\(id.uuidString)","createdAt":"\(iso)","coreID":"sad","coreName":"Sad"}
        """.data(using: .utf8)!
        let decoded = try WatchCheckInPayload.decoder.decode(WatchCheckInPayload.self, from: legacyJSON)
        XCTAssertEqual(decoded.schemaVersion, 1, "Missing schemaVersion must default to 1")
    }

    func testUserInfoDictionaryRoundTrips() throws {
        // Use a whole-second Date because the encoder's ISO8601 strategy doesn't
        // preserve fractional seconds — round-trip comparison would otherwise
        // fail on sub-millisecond drift from `Date()`.
        let payload = WatchCheckInPayload(
            createdAt: Date(timeIntervalSince1970: 1_700_002_500),
            coreID: "fear", coreName: "Fear",
            intensity: 2
        )
        let dict = try payload.userInfoDictionary()
        XCTAssertNotNil(dict[WatchCheckInPayload.userInfoVersionKey])
        let decoded = WatchCheckInPayload.decode(userInfo: dict)
        XCTAssertEqual(decoded, payload)
    }

    func testDecodeUserInfoReturnsNilForMissingKey() {
        XCTAssertNil(WatchCheckInPayload.decode(userInfo: [:]))
        XCTAssertNil(WatchCheckInPayload.decode(userInfo: ["other": Data()]))
    }

    func testDecodeUserInfoReturnsNilForMalformedData() {
        let bogus: [String: Any] = [
            WatchCheckInPayload.userInfoVersionKey: "not a Data instance"
        ]
        XCTAssertNil(WatchCheckInPayload.decode(userInfo: bogus))
    }

    func testCurrentSchemaVersionIsTwo() {
        // Locks in the schema number — bumping this forces the decoder back-
        // compat tests above to be re-examined.
        XCTAssertEqual(WatchCheckInPayload.currentSchemaVersion, 2)
    }

    // MARK: - WatchCheckInSettings Codable

    func testSettingsDefaultMatchesIOSFlowDefaults() {
        XCTAssertEqual(WatchCheckInSettings.default.bodyFirst, true)
        XCTAssertEqual(WatchCheckInSettings.default.sensationsPromoted, false)
    }

    func testSettingsApplicationContextRoundTrips() throws {
        let settings = WatchCheckInSettings(bodyFirst: false, sensationsPromoted: true)
        let context = try settings.applicationContext()
        XCTAssertNotNil(context[WatchCheckInSettings.userInfoKey])
        let decoded = WatchCheckInSettings.decode(applicationContext: context)
        XCTAssertEqual(decoded, settings)
    }

    func testDecodeApplicationContextReturnsNilForMissingKey() {
        XCTAssertNil(WatchCheckInSettings.decode(applicationContext: [:]))
        XCTAssertNil(WatchCheckInSettings.decode(applicationContext: ["unrelated": Data()]))
    }

    // MARK: - WatchSyncService.makeFeelingLog mapping

    @MainActor
    private func makeService() -> WatchSyncService {
        WatchSyncService(healthService: HealthService())
    }

    @MainActor
    func testMakeFeelingLogStopAtCoreLeavesDeeperFieldsEmpty() {
        let payload = WatchCheckInPayload(
            coreID: "happy", coreName: "Happy",
            secondaryID: nil, secondaryName: nil,
            specificID: nil, specificName: nil
        )
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(log.coreID, "happy")
        XCTAssertEqual(log.coreName, "Happy")
        XCTAssertEqual(log.secondaryID, "")
        XCTAssertEqual(log.secondaryName, "")
        XCTAssertEqual(log.specificID, "")
        XCTAssertEqual(log.specificName, "")
        XCTAssertEqual(log.captureSource, "watch")
    }

    @MainActor
    func testMakeFeelingLogStopAtSecondaryLeavesSpecificEmpty() {
        let payload = WatchCheckInPayload(
            coreID: "happy", coreName: "Happy",
            secondaryID: "optimistic", secondaryName: "Optimistic"
        )
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(log.secondaryID, "optimistic")
        XCTAssertEqual(log.secondaryName, "Optimistic")
        XCTAssertEqual(log.specificID, "")
        XCTAssertEqual(log.specificName, "")
    }

    @MainActor
    func testMakeFeelingLogFullDrillCarriesEveryLevel() {
        let payload = WatchCheckInPayload(
            coreID: "happy", coreName: "Happy",
            secondaryID: "optimistic", secondaryName: "Optimistic",
            specificID: "hopeful", specificName: "Hopeful"
        )
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(log.coreName, "Happy")
        XCTAssertEqual(log.secondaryName, "Optimistic")
        XCTAssertEqual(log.specificName, "Hopeful")
    }

    @MainActor
    func testMakeFeelingLogPreservesIdAndCreatedAt() {
        let id = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_001_234)
        let payload = WatchCheckInPayload(
            id: id, createdAt: createdAt,
            coreID: "happy", coreName: "Happy"
        )
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(log.id, id)
        XCTAssertEqual(log.createdAt, createdAt)
    }

    @MainActor
    func testMakeFeelingLogTrimsNoteWhitespace() {
        let payload = WatchCheckInPayload(
            coreID: "calm", coreName: "Calm",
            note: "  pause  "
        )
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(log.note, "pause")
    }

    @MainActor
    func testMakeFeelingLogNilNoteBecomesEmptyString() {
        let payload = WatchCheckInPayload(coreID: "calm", coreName: "Calm")
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(log.note, "")
    }

    @MainActor
    func testMakeFeelingLogCarriesIntensity() {
        let payload = WatchCheckInPayload(
            coreID: "fear", coreName: "Fear", intensity: 5
        )
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(log.intensity, 5)
    }

    @MainActor
    func testMakeFeelingLogParsesKnownBodyRegionsAndSensations() {
        let payload = WatchCheckInPayload(
            coreID: "fear", coreName: "Fear",
            bodyRegions: ["chest", "stomach"],
            bodySensations: ["tight", "warm"]
        )
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(Set(log.bodyRegions), Set([.chest, .stomach]))
        XCTAssertEqual(Set(log.bodySensations), Set([.tight, .warm]))
    }

    @MainActor
    func testMakeFeelingLogDropsUnknownBodyTokensSilently() {
        // A future watch build might send region/sensation rawValues that don't
        // exist on this phone yet. The receive path must not crash — drop them.
        let payload = WatchCheckInPayload(
            coreID: "fear", coreName: "Fear",
            bodyRegions: ["chest", "kneecap", "stomach"],
            bodySensations: ["tight", "static_buzz"]
        )
        let log = makeService().makeFeelingLog(from: payload)
        XCTAssertEqual(Set(log.bodyRegions), Set([.chest, .stomach]))
        XCTAssertEqual(Set(log.bodySensations), Set([.tight]))
    }

    @MainActor
    func testMakeFeelingLogMarksCaptureSourceAsWatch() {
        let log = makeService().makeFeelingLog(
            from: WatchCheckInPayload(coreID: "happy", coreName: "Happy")
        )
        XCTAssertEqual(log.captureSource, "watch")
    }

    // MARK: - WatchSyncService.ingest dedup + buffering

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    @MainActor
    func testIngestInsertsExactlyOneLog() throws {
        let service = makeService()
        let container = try makeContainer()
        service.attach(modelContainer: container)

        let payload = WatchCheckInPayload(coreID: "happy", coreName: "Happy")
        service.ingest(payload)

        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.id, payload.id)
        XCTAssertEqual(rows.first?.captureSource, "watch")
    }

    @MainActor
    func testIngestDedupesByPayloadID() throws {
        let service = makeService()
        let container = try makeContainer()
        service.attach(modelContainer: container)

        let payload = WatchCheckInPayload(coreID: "happy", coreName: "Happy")
        service.ingest(payload)
        service.ingest(payload)  // restore-from-backup or replayed queue
        service.ingest(payload)

        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(rows.count, 1, "Same payload.id must not produce duplicate FeelingLogs")
    }

    @MainActor
    func testIngestBuffersBeforeAttachAndDrainsOnAttach() throws {
        let service = makeService()
        // Ingest two payloads before the container is attached — they should
        // buffer rather than drop.
        let first = WatchCheckInPayload(coreID: "happy", coreName: "Happy")
        let second = WatchCheckInPayload(coreID: "sad", coreName: "Sad")
        service.ingest(first)
        service.ingest(second)

        let container = try makeContainer()
        service.attach(modelContainer: container)

        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(rows.count, 2,
                       "Both buffered payloads must drain when the container attaches")
        XCTAssertEqual(Set(rows.map(\.coreID)), Set(["happy", "sad"]))
    }

    @MainActor
    func testIngestAcceptsDifferentIDsAsSeparateLogs() throws {
        let service = makeService()
        let container = try makeContainer()
        service.attach(modelContainer: container)

        service.ingest(WatchCheckInPayload(coreID: "happy", coreName: "Happy"))
        service.ingest(WatchCheckInPayload(coreID: "happy", coreName: "Happy"))

        let context = ModelContext(container)
        let rows = try context.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(rows.count, 2,
                       "Same coreID with different payload UUIDs should produce two logs")
    }
}
