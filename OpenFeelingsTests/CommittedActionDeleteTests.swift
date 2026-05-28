import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class CommittedActionDeleteTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([CommittedAction.self, CustomValue.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testDeleteRemovesActionFromStore() throws {
        let context = try makeContext()
        let action = CommittedAction(title: "Call Mom", valueRef: "family")
        context.insert(action)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<CommittedAction>()).count, 1)

        CommittedActionDetail.delete(action, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<CommittedAction>()).count, 0)
    }

    func testDeleteIsIdempotent() throws {
        let context = try makeContext()
        let action = CommittedAction(title: "Call Mom", valueRef: "family")
        context.insert(action)
        try context.save()

        CommittedActionDetail.delete(action, in: context)
        CommittedActionDetail.delete(action, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<CommittedAction>()).count, 0)
    }

    func testDeleteCompletedActionStillDeletes() throws {
        let context = try makeContext()
        let action = CommittedAction(title: "Call Mom", valueRef: "family")
        action.markDone()
        action.reflection = "Glad I did."
        context.insert(action)
        try context.save()

        CommittedActionDetail.delete(action, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<CommittedAction>()).count, 0)
    }

    func testDeleteLeavesOtherActions() throws {
        let context = try makeContext()
        let keep = CommittedAction(title: "Keep me", valueRef: "family")
        let remove = CommittedAction(title: "Remove me", valueRef: "health")
        context.insert(keep)
        context.insert(remove)
        try context.save()

        CommittedActionDetail.delete(remove, in: context)

        let remaining = try context.fetch(FetchDescriptor<CommittedAction>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.title, "Keep me")
    }
}
