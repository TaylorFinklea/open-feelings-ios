import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class HistoryNoteUpdateTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([FeelingLog.self, Intention.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func sampleLog(note: String = "") -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        return FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: 3,
            note: note
        )
    }

    func testUpdateNoteOverwritesPreviousValue() throws {
        let context = try makeContext()
        let log = sampleLog(note: "old")
        context.insert(log)
        try context.save()

        HistoryView.updateNote(log, to: "new", in: context)

        XCTAssertEqual(log.note, "new")
    }

    func testUpdateNotePersistsAcrossFetch() throws {
        let context = try makeContext()
        let log = sampleLog(note: "old")
        context.insert(log)
        try context.save()

        HistoryView.updateNote(log, to: "persisted", in: context)

        let fetched = try context.fetch(FetchDescriptor<FeelingLog>()).first
        XCTAssertEqual(fetched?.note, "persisted")
    }

    func testUpdateNoteToEmptyClearsTheNote() throws {
        let context = try makeContext()
        let log = sampleLog(note: "old")
        context.insert(log)
        try context.save()

        HistoryView.updateNote(log, to: "", in: context)

        XCTAssertEqual(log.note, "")
    }

    func testUpdateNoteDoesNotMutateOtherFields() throws {
        let context = try makeContext()
        let log = sampleLog(note: "old")
        context.insert(log)
        try context.save()

        HistoryView.updateNote(log, to: "new", in: context)

        XCTAssertEqual(log.coreID, "happy")
        XCTAssertEqual(log.intensity, 3)
    }
}
