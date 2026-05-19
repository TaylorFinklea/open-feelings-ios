import XCTest
@testable import OpenFeelings

@MainActor
final class ThoughtRecordDraftTests: XCTestCase {

    private func sampleLog(intensity: Int? = 4) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "angry" }!
        let secondary = core.secondaries.first { $0.name == "Bitter" }
        let selection = EmotionSelection(core: core, secondary: secondary, specific: nil)
        let log = FeelingLog(selection: selection, intensity: intensity, note: "")
        log.createdAt = Date(timeIntervalSince1970: 1_715_000_000)
        return log
    }

    // MARK: - Initial state

    func testInitialDraftIsAllEmptyOrNil() {
        let draft = ThoughtRecordDraft()
        XCTAssertEqual(draft.situation, "")
        XCTAssertEqual(draft.automaticThought, "")
        XCTAssertNil(draft.intensityBefore)
        XCTAssertTrue(draft.patterns.isEmpty)
        XCTAssertEqual(draft.balancedThought, "")
        XCTAssertNil(draft.intensityAfter)
        XCTAssertNil(draft.linkedLogID)
    }

    // MARK: - from(log:)

    func testDraftFromLogCarriesLinkedID() {
        let log = sampleLog()
        let draft = ThoughtRecordDraft.from(log: log)
        XCTAssertEqual(draft.linkedLogID, log.id)
    }

    func testDraftFromLogPrefillsSituationWithPathAndTime() {
        let log = sampleLog()
        let draft = ThoughtRecordDraft.from(log: log)
        XCTAssertTrue(draft.situation.contains("Angry"),
                      "Situation should include the emotion path: \(draft.situation)")
        XCTAssertTrue(draft.situation.contains("·"),
                      "Situation should use middle-dot separator: \(draft.situation)")
    }

    func testDraftFromLogPrefillsIntensityWhenLogHasOne() {
        let log = sampleLog(intensity: 4)
        let draft = ThoughtRecordDraft.from(log: log)
        XCTAssertEqual(draft.intensityBefore, 4)
    }

    func testDraftFromLogLeavesIntensityNilWhenLogHasNone() {
        let log = sampleLog(intensity: nil)
        let draft = ThoughtRecordDraft.from(log: log)
        XCTAssertNil(draft.intensityBefore)
    }

    // MARK: - from(record:)

    func testDraftFromRecordCopiesAllFields() {
        let record = ThoughtRecord(
            situation: "morning",
            automaticThought: "I'll fail",
            intensityBefore: 5,
            patterns: [.fortuneTelling, .worstCase],
            balancedThought: "I've handled this before",
            intensityAfter: 2,
            linkedLogID: UUID()
        )
        let draft = ThoughtRecordDraft.from(record: record)
        XCTAssertEqual(draft.id, record.id)
        XCTAssertEqual(draft.situation, "morning")
        XCTAssertEqual(draft.automaticThought, "I'll fail")
        XCTAssertEqual(draft.intensityBefore, 5)
        XCTAssertEqual(draft.patterns, [.fortuneTelling, .worstCase])
        XCTAssertEqual(draft.balancedThought, "I've handled this before")
        XCTAssertEqual(draft.intensityAfter, 2)
        XCTAssertEqual(draft.linkedLogID, record.linkedLogID)
    }

    // MARK: - apply(to:)

    func testApplyOverwritesAllRecordFields() {
        let record = ThoughtRecord()
        var draft = ThoughtRecordDraft()
        draft.situation = "evening"
        draft.automaticThought = "they're upset with me"
        draft.intensityBefore = 4
        draft.patterns = [.mindReading]
        draft.balancedThought = "I haven't asked them"
        draft.intensityAfter = 2
        let logID = UUID()
        draft.linkedLogID = logID

        draft.apply(to: record)
        XCTAssertEqual(record.situation, "evening")
        XCTAssertEqual(record.automaticThought, "they're upset with me")
        XCTAssertEqual(record.intensityBefore, 4)
        XCTAssertEqual(record.patterns, [.mindReading])
        XCTAssertEqual(record.balancedThought, "I haven't asked them")
        XCTAssertEqual(record.intensityAfter, 2)
        XCTAssertEqual(record.linkedLogID, logID)
    }

    // MARK: - toThoughtRecord

    func testToThoughtRecordPreservesIDAndAllFields() {
        var draft = ThoughtRecordDraft()
        draft.id = UUID()
        draft.automaticThought = "x"
        draft.intensityBefore = 3
        draft.patterns = [.blackAndWhite]
        draft.balancedThought = "y"
        draft.intensityAfter = 1
        let record = draft.toThoughtRecord()
        XCTAssertEqual(record.id, draft.id)
        XCTAssertEqual(record.automaticThought, "x")
        XCTAssertEqual(record.intensityBefore, 3)
        XCTAssertEqual(record.patterns, [.blackAndWhite])
        XCTAssertEqual(record.balancedThought, "y")
        XCTAssertEqual(record.intensityAfter, 1)
    }

    // MARK: - isSaveable

    func testDraftIsSaveableMirrorsRecordLogic() {
        var draft = ThoughtRecordDraft()
        XCTAssertFalse(draft.isSaveable)
        draft.automaticThought = "x"
        draft.balancedThought = "y"
        draft.intensityBefore = 3
        XCTAssertFalse(draft.isSaveable, "Missing intensityAfter")
        draft.intensityAfter = 2
        XCTAssertTrue(draft.isSaveable)
    }
}
