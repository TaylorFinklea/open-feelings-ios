import XCTest
import SwiftData
@testable import OpenFeelings

@MainActor
final class ThoughtRecordsAreaPersistenceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self, ThoughtRecord.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testInsertedRecordPersistsAndIsFetchedNewestFirst() throws {
        let context = try makeContext()
        let older = ThoughtRecord(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            automaticThought: "old",
            intensityBefore: 5,
            balancedThought: "x",
            intensityAfter: 3
        )
        let newer = ThoughtRecord(
            createdAt: Date(timeIntervalSince1970: 1_700_001_000),
            automaticThought: "new",
            intensityBefore: 5,
            balancedThought: "y",
            intensityAfter: 2
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let descriptor = FetchDescriptor<ThoughtRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let rows = try context.fetch(descriptor)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].automaticThought, "new")
        XCTAssertEqual(rows[1].automaticThought, "old")
    }

    func testDeletingARecordRemovesItFromTheStore() throws {
        let context = try makeContext()
        let record = ThoughtRecord(
            automaticThought: "x",
            intensityBefore: 3,
            balancedThought: "y",
            intensityAfter: 1
        )
        context.insert(record)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ThoughtRecord>()).count, 1)

        context.delete(record)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ThoughtRecord>()).count, 0)
    }

    func testPatternsRawSurvivesPersistence() throws {
        let context = try makeContext()
        let record = ThoughtRecord(
            automaticThought: "x",
            intensityBefore: 4,
            patterns: [.mindReading, .worstCase, .alwaysNever],
            balancedThought: "y",
            intensityAfter: 2
        )
        context.insert(record)
        try context.save()

        let rows = try context.fetch(FetchDescriptor<ThoughtRecord>())
        XCTAssertEqual(rows.first?.patterns,
                       [.mindReading, .worstCase, .alwaysNever])
    }

    func testLinkedLogIDIsPersisted() throws {
        let context = try makeContext()
        let logID = UUID()
        let record = ThoughtRecord(
            automaticThought: "x",
            intensityBefore: 3,
            balancedThought: "y",
            intensityAfter: 1,
            linkedLogID: logID
        )
        context.insert(record)
        try context.save()

        let rows = try context.fetch(FetchDescriptor<ThoughtRecord>())
        XCTAssertEqual(rows.first?.linkedLogID, logID)
    }
}
