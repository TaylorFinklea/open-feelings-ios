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
        secondaryID: String? = nil,
        secondaryName: String? = nil,
        specificID: String? = nil,
        specificName: String? = nil,
        intensity: Int? = 4,
        bodyRegions: [String] = [],
        bodySensations: [String] = [],
        note: String? = "logged from wrist"
    ) -> WatchCheckInPayload {
        WatchCheckInPayload(
            id: id,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            coreID: coreID,
            coreName: coreName,
            secondaryID: secondaryID,
            secondaryName: secondaryName,
            specificID: specificID,
            specificName: specificName,
            intensity: intensity,
            bodyRegions: bodyRegions,
            bodySensations: bodySensations,
            note: note
        )
    }

    private func fetchAllLogs(in container: ModelContainer) -> [FeelingLog] {
        let context = ModelContext(container)
        return (try? context.fetch(FetchDescriptor<FeelingLog>())) ?? []
    }

    func testMakeFeelingLogCoreOnlyPath() throws {
        let service = WatchSyncService(healthService: HealthService())
        let payload = makePayload(intensity: 3, note: "  trimmed  ")

        let log = service.makeFeelingLog(from: payload)

        XCTAssertEqual(log.coreID, "happy")
        XCTAssertEqual(log.coreName, "Happy")
        XCTAssertEqual(log.intensity, 3)
        XCTAssertEqual(log.note, "trimmed")
        XCTAssertEqual(log.captureSource, "watch")
        XCTAssertTrue(log.secondaryID.isEmpty)
        XCTAssertTrue(log.secondaryName.isEmpty)
        XCTAssertTrue(log.specificID.isEmpty)
        XCTAssertTrue(log.specificName.isEmpty)
        XCTAssertTrue(log.bodyRegions.isEmpty)
        XCTAssertTrue(log.bodySensations.isEmpty)
    }

    func testMakeFeelingLogFullDrillAndBody() throws {
        let service = WatchSyncService(healthService: HealthService())
        let payload = makePayload(
            secondaryID: "optimistic",
            secondaryName: "Optimistic",
            specificID: "hopeful",
            specificName: "Hopeful",
            bodyRegions: ["chest", "head"],
            bodySensations: ["warm", "fluttery"]
        )

        let log = service.makeFeelingLog(from: payload)

        XCTAssertEqual(log.secondaryID, "optimistic")
        XCTAssertEqual(log.secondaryName, "Optimistic")
        XCTAssertEqual(log.specificID, "hopeful")
        XCTAssertEqual(log.specificName, "Hopeful")
        XCTAssertEqual(log.pathTitle, "Happy > Optimistic > Hopeful")
        XCTAssertEqual(Set(log.bodyRegions), Set([.chest, .head]))
        XCTAssertEqual(Set(log.bodySensations), Set([.warm, .fluttery]))
    }

    func testMakeFeelingLogPartialDrillCoreAndSecondary() throws {
        let service = WatchSyncService(healthService: HealthService())
        let payload = makePayload(
            coreName: "Fearful",
            secondaryID: "anxious",
            secondaryName: "Anxious"
        )

        let log = service.makeFeelingLog(from: payload)

        XCTAssertEqual(log.secondaryName, "Anxious")
        XCTAssertTrue(log.specificName.isEmpty)
        XCTAssertEqual(log.pathTitle, "Fearful > Anxious")
    }

    func testMakeFeelingLogDropsUnknownBodyTokensSilently() throws {
        let service = WatchSyncService(healthService: HealthService())
        let payload = makePayload(
            bodyRegions: ["chest", "elbow_typo"],
            bodySensations: ["warm", "vibrating_typo"]
        )

        let log = service.makeFeelingLog(from: payload)

        XCTAssertEqual(log.bodyRegions, [.chest])
        XCTAssertEqual(log.bodySensations, [.warm])
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
