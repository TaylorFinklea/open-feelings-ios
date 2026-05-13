import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class WatchSyncServiceTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([FeelingLog.self, Intention.self, UserBodyMap.self])
        let config = ModelConfiguration(
            "WatchSyncServiceTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makePayload(
        id: UUID = UUID(),
        coreID: String = "happy",
        coreName: String = "Happy",
        intensity: Int? = 4,
        note: String? = "logged from wrist"
    ) -> WatchCheckInPayload {
        WatchCheckInPayload(
            id: id,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            coreID: coreID,
            coreName: coreName,
            intensity: intensity,
            note: note
        )
    }

    private func fetchAllLogs(in container: ModelContainer) -> [FeelingLog] {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<FeelingLog>())) ?? []
    }

    func testMakeFeelingLogMapsWatchFieldsAndLeavesPathEmpty() throws {
        let service = WatchSyncService(healthService: HealthService())
        let payload = makePayload(intensity: 3, note: "  trimmed  ")

        let log = service.makeFeelingLog(from: payload)

        XCTAssertEqual(log.id, payload.id)
        XCTAssertEqual(log.coreID, "happy")
        XCTAssertEqual(log.coreName, "Happy")
        XCTAssertEqual(log.intensity, 3)
        XCTAssertEqual(log.note, "trimmed")
        XCTAssertEqual(log.captureSource, "watch")
        XCTAssertTrue(log.secondaryID.isEmpty)
        XCTAssertTrue(log.secondaryName.isEmpty)
        XCTAssertTrue(log.specificID.isEmpty)
        XCTAssertTrue(log.specificName.isEmpty)
        XCTAssertNil(log.moodEnergy)
        XCTAssertNil(log.moodValence)
        XCTAssertTrue(log.bodyRegions.isEmpty)
        XCTAssertTrue(log.triggers.isEmpty)
    }

    func testIngestInsertsExactlyOneRow() throws {
        let container = try makeContainer()
        let service = WatchSyncService(healthService: HealthService())
        service.attach(modelContainer: container)

        service.ingest(makePayload())

        XCTAssertEqual(fetchAllLogs(in: container).count, 1)
    }

    func testIngestSamePayloadTwiceDeduplicates() throws {
        let container = try makeContainer()
        let service = WatchSyncService(healthService: HealthService())
        service.attach(modelContainer: container)

        let payload = makePayload()
        service.ingest(payload)
        service.ingest(payload)

        let logs = fetchAllLogs(in: container)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.id, payload.id)
    }

    func testIngestBeforeAttachBuffersUntilContainerReady() throws {
        let container = try makeContainer()
        let service = WatchSyncService(healthService: HealthService())

        // Pre-attach: no container, payload should be buffered, no insert yet.
        let early = makePayload(id: UUID(), coreName: "Sad")
        service.ingest(early)
        XCTAssertEqual(fetchAllLogs(in: container).count, 0)

        // Attach -> buffered payload flushes.
        service.attach(modelContainer: container)
        let logs = fetchAllLogs(in: container)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.id, early.id)
    }
}
