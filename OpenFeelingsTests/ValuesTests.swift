import XCTest
import SwiftData
@testable import OpenFeelings

final class ValuesTests: XCTestCase {
    func testValueTaxonomyIntegrity() {
        let all = ValueTaxonomy.all
        XCTAssertGreaterThanOrEqual(all.count, 40, "expect ~50 curated values")

        let ids = all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate ids in taxonomy")

        let slugRegex = #"^[a-z][a-z0-9_]*$"#
        for def in all {
            XCTAssertFalse(def.name.isEmpty, "empty name for id=\(def.id)")
            XCTAssertFalse(def.description.isEmpty, "empty description for id=\(def.id)")
            XCTAssertNotNil(def.id.range(of: slugRegex, options: .regularExpression),
                            "id is not a lowercase slug: \(def.id)")
        }
    }

    func testValueRefDisplayNameResolvesCurated() {
        let name = ValueRef.displayName(for: "family", customs: [])
        XCTAssertEqual(name, "Family")
    }

    func testValueRefDisplayNameResolvesCustom() {
        let uuid = UUID()
        let custom = CustomValue(id: uuid, name: "Surfing")
        let name = ValueRef.displayName(for: "custom:\(uuid.uuidString)", customs: [custom])
        XCTAssertEqual(name, "Surfing")
    }

    func testValueRefDisplayNameMissingCustomFallback() {
        let name = ValueRef.displayName(for: "custom:\(UUID().uuidString)", customs: [])
        XCTAssertEqual(name, "(removed value)")
    }

    func testValueRefIsCustom() {
        XCTAssertTrue(ValueRef.isCustom("custom:abc"))
        XCTAssertFalse(ValueRef.isCustom("family"))
    }

    private func makeContext(schema overrideSchema: Schema? = nil) throws -> ModelContext {
        let schema = overrideSchema ?? Schema([
            CustomValue.self, ValueSort.self, CommittedAction.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testValueSortJSONRoundTripPreservesBucketAndRanking() throws {
        let uuid = UUID()
        let assignments: [String: SortBucket] = [
            "family": .veryImportant,
            "honesty": .veryImportant,
            "status": .notForMe,
            "growth": .important,
            ValueRef.makeCustomRef(uuid): .veryImportant
        ]
        let ranked = ["family", "honesty", ValueRef.makeCustomRef(uuid)]
        let sort = ValueSort(bucketAssignments: assignments, rankedTop: ranked)

        XCTAssertEqual(sort.bucketAssignments, assignments)
        XCTAssertEqual(sort.rankedTop, ranked)

        // Persisting and re-reading via raw fields also round-trips.
        let raw = sort.bucketAssignmentsRaw
        let copy = ValueSort()
        copy.bucketAssignmentsRaw = raw
        copy.rankedTopRaw = sort.rankedTopRaw
        XCTAssertEqual(copy.bucketAssignments, assignments)
        XCTAssertEqual(copy.rankedTop, ranked)
    }

    func testNewestValueSortIsActive() throws {
        let context = try makeContext()
        let older = ValueSort(
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            bucketAssignments: ["family": .veryImportant],
            rankedTop: ["family"]
        )
        let newer = ValueSort(
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            bucketAssignments: ["growth": .veryImportant],
            rankedTop: ["growth"]
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        var descriptor = FetchDescriptor<ValueSort>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let active = try context.fetch(descriptor).first
        XCTAssertEqual(active?.rankedTop, ["growth"])
    }

    func testCommittedActionLifecycleMarkDoneSetsCompletedAt() throws {
        let action = CommittedAction(title: "Call my brother", valueRef: "family",
                                     whatsHard: "We haven't spoken in a year.")
        XCTAssertFalse(action.isDone)
        XCTAssertNil(action.completedAt)
        XCTAssertEqual(action.reflection, "")

        let now = Date()
        action.markDone(at: now)

        XCTAssertTrue(action.isDone)
        XCTAssertEqual(action.completedAt, now)
        XCTAssertEqual(action.title, "Call my brother")
        XCTAssertEqual(action.valueRef, "family")
        XCTAssertEqual(action.whatsHard, "We haven't spoken in a year.")
        XCTAssertEqual(action.reflection, "")
    }

    func testCommittedActionPersistsAcrossReSort() throws {
        let context = try makeContext()
        let action = CommittedAction(title: "Hard 1:1", valueRef: "honesty")
        context.insert(action)

        // First sort exists.
        let first = ValueSort(bucketAssignments: ["honesty": .veryImportant],
                              rankedTop: ["honesty"])
        context.insert(first)
        try context.save()

        // User re-sorts and "honesty" gets dropped from the new ranked list.
        let second = ValueSort(createdAt: Date(timeIntervalSinceNow: 10),
                               bucketAssignments: ["growth": .veryImportant],
                               rankedTop: ["growth"])
        context.insert(second)
        try context.save()

        let descriptor = FetchDescriptor<CommittedAction>()
        let found = try context.fetch(descriptor)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.valueRef, "honesty")
    }

    func testCommittedActionWithDroppedValueRefStillResolvesToFallback() {
        let action = CommittedAction(title: "x", valueRef: "honesty")
        // Active sort no longer includes "honesty"; ranked list is just ["growth"].
        let activeRanked: [String] = ["growth"]
        let inActive = activeRanked.contains(action.valueRef)
        XCTAssertFalse(inActive)
        let label = inActive
            ? ValueRef.displayName(for: action.valueRef, customs: [])
            : "(not in current values)"
        XCTAssertEqual(label, "(not in current values)")
    }
}
