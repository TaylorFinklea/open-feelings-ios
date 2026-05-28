import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class IntentionDeleteTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Intention.self, FeelingLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testDeleteRemovesIntentionFromStore() throws {
        let context = try makeContext()
        let intention = Intention(text: "Pause when rushed")
        context.insert(intention)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<Intention>()).count, 1)

        IntentionsContent.deleteIntention(intention, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Intention>()).count, 0)
    }

    func testDeleteIsIdempotent() throws {
        let context = try makeContext()
        let intention = Intention(text: "Pause when rushed")
        context.insert(intention)
        try context.save()

        IntentionsContent.deleteIntention(intention, in: context)
        IntentionsContent.deleteIntention(intention, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Intention>()).count, 0)
    }

    func testDeleteDoesNotCascadeToLogs() throws {
        let context = try makeContext()
        let day = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let intention = Intention(date: day, text: "Pause when rushed")
        context.insert(intention)
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let log = FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: 3,
            note: ""
        )
        log.createdAt = day
        context.insert(log)
        try context.save()

        IntentionsContent.deleteIntention(intention, in: context)

        let logs = try context.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(logs.count, 1, "Deleting an intention must not cascade to logs")
        XCTAssertEqual(logs.first?.createdAt, day)
    }
}
