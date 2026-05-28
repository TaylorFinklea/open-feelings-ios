import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class PastSortsDeleteTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([ValueSort.self, CustomValue.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func sort(daysAgo: Int, ranked: [String] = ["family"]) -> ValueSort {
        let date = Date(timeIntervalSince1970: 1_700_000_000 - Double(daysAgo) * 86_400)
        return ValueSort(createdAt: date, rankedTop: ranked)
    }

    func testDeleteRemovesSortFromStore() throws {
        let context = try makeContext()
        let s = sort(daysAgo: 0)
        context.insert(s)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ValueSort>()).count, 1)

        PastSortsSheet.delete(s, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<ValueSort>()).count, 0)
    }

    func testDeleteActiveSortPromotesNextNewest() throws {
        let context = try makeContext()
        let newest = sort(daysAgo: 0, ranked: ["newest"])
        let middle = sort(daysAgo: 1, ranked: ["middle"])
        let oldest = sort(daysAgo: 2, ranked: ["oldest"])
        [newest, middle, oldest].forEach { context.insert($0) }
        try context.save()

        PastSortsSheet.delete(newest, in: context)

        // ValuesArea picks sorts.first (newest by createdAt). After deleting
        // the newest, `middle` is the newest remaining.
        let descriptor = FetchDescriptor<ValueSort>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let remaining = try context.fetch(descriptor)
        XCTAssertEqual(remaining.count, 2)
        XCTAssertEqual(remaining.first?.rankedTop, ["middle"])
    }

    func testDeleteAllSortsLeavesStoreEmpty() throws {
        let context = try makeContext()
        let a = sort(daysAgo: 0)
        let b = sort(daysAgo: 1)
        [a, b].forEach { context.insert($0) }
        try context.save()

        PastSortsSheet.delete(a, in: context)
        PastSortsSheet.delete(b, in: context)

        XCTAssertTrue(try context.fetch(FetchDescriptor<ValueSort>()).isEmpty)
    }

    func testDeleteIsIdempotent() throws {
        let context = try makeContext()
        let s = sort(daysAgo: 0)
        context.insert(s)
        try context.save()

        PastSortsSheet.delete(s, in: context)
        PastSortsSheet.delete(s, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<ValueSort>()).count, 0)
    }

    func testDeleteDoesNotCascadeToReferencedCustomValue() throws {
        let context = try makeContext()
        let value = CustomValue(name: "Curiosity")
        context.insert(value)
        let s = sort(daysAgo: 0, ranked: [ValueRef.makeCustomRef(value.id)])
        context.insert(s)
        try context.save()

        PastSortsSheet.delete(s, in: context)

        let values = try context.fetch(FetchDescriptor<CustomValue>())
        XCTAssertEqual(values.count, 1, "Deleting a sort must not cascade to custom values it referenced")
        XCTAssertEqual(values.first?.id, value.id)
    }
}
