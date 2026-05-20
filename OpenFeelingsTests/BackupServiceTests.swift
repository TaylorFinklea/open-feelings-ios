import XCTest
import SwiftData
@testable import OpenFeelings

@MainActor
final class BackupServiceTests: XCTestCase {

    // MARK: - Container helper

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self, ThoughtRecord.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    // MARK: - Encode: gathers every type

    func testEncodeGathersEveryModelTypeFromContext() throws {
        let context = try makeContext()
        try seedOneOfEach(in: context)

        let envelope = try BackupService.encodeToEnvelope(context: context)
        XCTAssertEqual(envelope.feelingLogs.count, 1)
        XCTAssertEqual(envelope.intentions.count, 1)
        XCTAssertEqual(envelope.userBodyMaps.count, 1)
        XCTAssertEqual(envelope.customBodyRegions.count, 1)
        XCTAssertEqual(envelope.customValues.count, 1)
        XCTAssertEqual(envelope.valueSorts.count, 1)
        XCTAssertEqual(envelope.committedActions.count, 1)
        XCTAssertEqual(envelope.thoughtRecords.count, 1)
        XCTAssertEqual(envelope.schemaVersion, BackupService.currentSchemaVersion)
    }

    // MARK: - Codable round-trip

    func testEnvelopeJSONRoundTripPreservesAllFields() throws {
        let context = try makeContext()
        try seedOneOfEach(in: context)
        // First encode normalizes Date precision to milliseconds (JSON
        // encoder's resolution). Compare two consecutive encode-decode-encode
        // cycles for byte-for-byte equality; that guarantees every field
        // round-trips losslessly at the JSON resolution.
        let original = try BackupService.encodeToEnvelope(context: context)
        let firstEncoded = try BackupService.jsonEncoder.encode(original)
        let decoded = try BackupService.jsonDecoder.decode(BackupEnvelope.self, from: firstEncoded)
        let secondEncoded = try BackupService.jsonEncoder.encode(decoded)
        XCTAssertEqual(firstEncoded, secondEncoded,
                       "JSON encode is not stable across one round-trip")
    }

    // MARK: - Import into blank context

    func testImportIntoBlankContextInsertsEveryRow() throws {
        let source = try makeContext()
        try seedOneOfEach(in: source)
        let envelope = try BackupService.encodeToEnvelope(context: source)

        let blank = try makeContext()
        let summary = try BackupService.importBackup(from: envelope, into: blank)

        XCTAssertEqual(try blank.fetch(FetchDescriptor<FeelingLog>()).count, 1)
        XCTAssertEqual(try blank.fetch(FetchDescriptor<Intention>()).count, 1)
        XCTAssertEqual(try blank.fetch(FetchDescriptor<UserBodyMap>()).count, 1)
        XCTAssertEqual(try blank.fetch(FetchDescriptor<CustomBodyRegion>()).count, 1)
        XCTAssertEqual(try blank.fetch(FetchDescriptor<CustomValue>()).count, 1)
        XCTAssertEqual(try blank.fetch(FetchDescriptor<ValueSort>()).count, 1)
        XCTAssertEqual(try blank.fetch(FetchDescriptor<CommittedAction>()).count, 1)
        XCTAssertEqual(try blank.fetch(FetchDescriptor<ThoughtRecord>()).count, 1)

        XCTAssertEqual(summary.imported, 8)
        XCTAssertEqual(summary.skipped, 0)
    }

    // MARK: - Dedup on re-import

    func testReImportingTheSameEnvelopeSkipsAllRows() throws {
        let context = try makeContext()
        try seedOneOfEach(in: context)
        let envelope = try BackupService.encodeToEnvelope(context: context)

        let summary = try BackupService.importBackup(from: envelope, into: context)

        // Every row's dedup key (id or date or singleton-exists) matches.
        XCTAssertEqual(summary.imported, 0)
        XCTAssertEqual(summary.skipped, 8)
        // And no duplicate rows landed.
        XCTAssertEqual(try context.fetch(FetchDescriptor<FeelingLog>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Intention>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserBodyMap>()).count, 1)
    }

    // MARK: - Intention dedup is by start-of-day date

    func testIntentionDedupUsesStartOfDayDate() throws {
        let context = try makeContext()
        // Two intentions on the same calendar day at different times.
        let day = Calendar.current.startOfDay(for: Date())
        let morning = Calendar.current.date(byAdding: .hour, value: 6, to: day)!
        let evening = Calendar.current.date(byAdding: .hour, value: 21, to: day)!

        let local = Intention(date: morning, text: "local one")
        context.insert(local)
        try context.save()

        let backupEnvelope = BackupEnvelope(
            appVersion: "test",
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: Date(),
            feelingLogs: [], intentions: [
                BackupIntention(Intention(date: evening, text: "from backup"))
            ],
            userBodyMaps: [], customBodyRegions: [], customValues: [],
            valueSorts: [], committedActions: [], thoughtRecords: []
        )

        let summary = try BackupService.importBackup(from: backupEnvelope, into: context)
        XCTAssertEqual(summary.perType["Intention"]?.imported, 0)
        XCTAssertEqual(summary.perType["Intention"]?.skipped, 1)
        // Local "local one" stays; backup's "from backup" is skipped.
        let rows = try context.fetch(FetchDescriptor<Intention>())
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.text, "local one")
    }

    // MARK: - UserBodyMap singleton: skip if exists

    func testUserBodyMapImportSkipsWhenLocalSingletonExists() throws {
        let context = try makeContext()
        let local = UserBodyMap()
        local.setOverride(for: .chest, coreIDs: ["happy"])
        context.insert(local)
        try context.save()

        let backupMap = UserBodyMap()
        backupMap.setOverride(for: .stomach, coreIDs: ["sad"])
        let envelope = BackupEnvelope(
            appVersion: "test",
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: Date(),
            feelingLogs: [], intentions: [],
            userBodyMaps: [BackupUserBodyMap(backupMap)],
            customBodyRegions: [], customValues: [], valueSorts: [],
            committedActions: [], thoughtRecords: []
        )

        let summary = try BackupService.importBackup(from: envelope, into: context)
        XCTAssertEqual(summary.perType["UserBodyMap"]?.imported, 0)
        XCTAssertEqual(summary.perType["UserBodyMap"]?.skipped, 1)
        let rows = try context.fetch(FetchDescriptor<UserBodyMap>())
        XCTAssertEqual(rows.count, 1)
        // Local map untouched: its .chest override is still there, .stomach not.
        XCTAssertEqual(rows.first?.coreIDs(for: .chest), ["happy"])
        XCTAssertNil(rows.first?.coreIDs(for: .stomach))
    }

    // MARK: - Schema version too new

    func testImportRejectsEnvelopeWithHigherSchemaVersion() throws {
        let context = try makeContext()
        let envelope = BackupEnvelope(
            appVersion: "future",
            schemaVersion: BackupService.currentSchemaVersion + 1,
            exportedAt: Date(),
            feelingLogs: [], intentions: [], userBodyMaps: [],
            customBodyRegions: [], customValues: [], valueSorts: [],
            committedActions: [], thoughtRecords: []
        )

        XCTAssertThrowsError(try BackupService.importBackup(from: envelope, into: context)) { error in
            guard case BackupService.ImportError.schemaVersionTooNew(let have, let supported) = error else {
                XCTFail("Expected schemaVersionTooNew, got \(error)"); return
            }
            XCTAssertEqual(have, BackupService.currentSchemaVersion + 1)
            XCTAssertEqual(supported, BackupService.currentSchemaVersion)
        }
    }

    // MARK: - decodeEnvelope error mapping

    func testDecodeEnvelopeMapsJSONErrorsToDecodeFailed() {
        let garbage = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try BackupService.decodeEnvelope(from: garbage)) { error in
            guard case BackupService.ImportError.decodeFailed = error else {
                XCTFail("Expected decodeFailed, got \(error)"); return
            }
        }
    }

    // MARK: - Mixed dedup case

    func testMixedExistingAndNewRowsImportCorrectly() throws {
        let context = try makeContext()
        let existingLog = makeFeelingLog(intensity: 3, note: "local")
        context.insert(existingLog)
        try context.save()

        let envelope = BackupEnvelope(
            appVersion: "test",
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: Date(),
            feelingLogs: [
                // Same id as local — should skip.
                BackupFeelingLog(existingLog),
                // New id — should import.
                BackupFeelingLog(makeFeelingLog(intensity: 4, note: "new from backup"))
            ],
            intentions: [], userBodyMaps: [], customBodyRegions: [],
            customValues: [], valueSorts: [], committedActions: [],
            thoughtRecords: []
        )

        let summary = try BackupService.importBackup(from: envelope, into: context)
        XCTAssertEqual(summary.perType["FeelingLog"]?.imported, 1)
        XCTAssertEqual(summary.perType["FeelingLog"]?.skipped, 1)

        let rows = try context.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(Set(rows.map(\.note)), Set(["local", "new from backup"]))
    }

    // MARK: - Helpers

    private func seedOneOfEach(in context: ModelContext) throws {
        context.insert(makeFeelingLog(intensity: 3, note: "fixture"))

        let intention = Intention(date: Date(), text: "today's intention")
        context.insert(intention)

        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["happy"])
        context.insert(map)

        context.insert(CustomBodyRegion(name: "left arm"))
        context.insert(CustomValue(name: "Curiosity"))

        let sort = ValueSort(
            bucketAssignments: ["family": .veryImportant],
            rankedTop: ["family"]
        )
        context.insert(sort)

        context.insert(CommittedAction(
            title: "Call my brother",
            valueRef: "family",
            whatsHard: "We haven't talked in months."
        ))

        let record = ThoughtRecord(
            situation: "morning",
            automaticThought: "I'll fail the standup",
            intensityBefore: 4,
            patterns: [.fortuneTelling, .worstCase],
            balancedThought: "I've prepped",
            intensityAfter: 2
        )
        context.insert(record)

        try context.save()
    }

    private func makeFeelingLog(intensity: Int?, note: String) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        return FeelingLog(selection: selection, intensity: intensity, note: note)
    }
}
