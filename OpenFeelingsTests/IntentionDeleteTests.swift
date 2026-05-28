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
}
