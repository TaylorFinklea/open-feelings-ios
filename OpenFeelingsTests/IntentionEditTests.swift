import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class IntentionEditTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Intention.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testUpdateTextTrimsAndPersists() throws {
        let context = try makeContext()
        let intention = Intention(text: "Pause when rushd")
        context.insert(intention)
        try context.save()

        IntentionsContent.updateIntentionText(intention, to: "  Pause when rushed  ", in: context)

        XCTAssertEqual(intention.text, "Pause when rushed")
    }

    func testUpdateTextToEmptyIsNoOp() throws {
        let context = try makeContext()
        let intention = Intention(text: "Keep going")
        context.insert(intention)
        try context.save()

        IntentionsContent.updateIntentionText(intention, to: "   ", in: context)

        XCTAssertEqual(intention.text, "Keep going")
    }

    func testUpdateTextPersistsAcrossFetch() throws {
        let context = try makeContext()
        let intention = Intention(text: "old")
        context.insert(intention)
        try context.save()

        IntentionsContent.updateIntentionText(intention, to: "new", in: context)

        let fetched = try context.fetch(FetchDescriptor<Intention>()).first
        XCTAssertEqual(fetched?.text, "new")
    }

    func testUpdateTextDoesNotMutateDate() throws {
        let context = try makeContext()
        let fixedDay = Calendar.current.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let intention = Intention(date: fixedDay, text: "old")
        context.insert(intention)
        try context.save()

        IntentionsContent.updateIntentionText(intention, to: "new", in: context)

        XCTAssertEqual(intention.date, fixedDay)
    }
}
