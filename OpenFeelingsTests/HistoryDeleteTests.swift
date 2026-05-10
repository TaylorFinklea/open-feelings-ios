import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class HistoryDeleteTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([FeelingLog.self, Intention.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func sampleLog() -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        return FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: 3,
            note: "test"
        )
    }

    func testDeleteLogRemovesItFromTheContext() throws {
        let context = try makeContext()
        let log = sampleLog()
        context.insert(log)
        try context.save()

        let descriptor = FetchDescriptor<FeelingLog>()
        XCTAssertEqual(try context.fetch(descriptor).count, 1)

        HistoryView.deleteLog(log, in: context)

        XCTAssertEqual(try context.fetch(descriptor).count, 0)
    }

    func testDeleteLogIsIdempotentIfAlreadyRemoved() throws {
        let context = try makeContext()
        let log = sampleLog()
        context.insert(log)
        try context.save()

        HistoryView.deleteLog(log, in: context)
        HistoryView.deleteLog(log, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<FeelingLog>()).count, 0)
    }
}
