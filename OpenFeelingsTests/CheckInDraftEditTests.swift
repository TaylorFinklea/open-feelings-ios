import XCTest
@testable import OpenFeelings

@MainActor
final class CheckInDraftEditTests: XCTestCase {

    // MARK: - Builders

    private func core(_ id: String) -> EmotionCore {
        EmotionTaxonomy.cores.first { $0.id == id }!
    }

    /// A core that has at least one secondary with at least one specific,
    /// for the 3-level path tests.
    private func deepCore() -> (EmotionCore, EmotionSecondary, EmotionSpecific) {
        for c in EmotionTaxonomy.cores {
            for s in c.secondaries where !s.specifics.isEmpty {
                return (c, s, s.specifics[0])
            }
        }
        fatalError("Taxonomy has no core→secondary→specific path")
    }

    private func fullLog() -> FeelingLog {
        let (c, s, sp) = deepCore()
        let log = FeelingLog(
            selection: EmotionSelection(core: c, secondary: s, specific: sp),
            intensity: 4,
            note: "felt it",
            bodyRegions: [.chest],
            bodySensations: [BodySensation.allCases[0]],
            contextPlaces: [ContextPlace.allCases[0]],
            contextPeople: [ContextPeople.allCases[0]],
            triggers: [Trigger.allCases[0]],
            coping: [Coping.allCases[0]],
            moodEnergy: 0.5,
            moodValence: -0.25
        )
        log.customBodyRegionIDs = [UUID()]
        return log
    }

    // MARK: - from(log:)

    func testFromLogRoundTripsAllFields() {
        let log = fullLog()
        let draft = CheckInDraft.from(log: log)

        XCTAssertEqual(draft.selection?.core.id, log.coreID)
        XCTAssertEqual(draft.selection?.secondary?.id, log.secondaryID)
        XCTAssertEqual(draft.selection?.specific?.id, log.specificID)
        XCTAssertEqual(draft.note, "felt it")
        XCTAssertTrue(draft.includeIntensity)
        XCTAssertEqual(draft.intensity, 4)
        XCTAssertTrue(draft.includeMoodScale)
        XCTAssertEqual(draft.moodEnergy, 0.5)
        XCTAssertEqual(draft.moodValence, -0.25)
        XCTAssertEqual(draft.bodyRegions, [.chest])
        XCTAssertEqual(draft.customBodyRegionIDs, Set(log.customBodyRegionIDs))
        XCTAssertEqual(draft.bodySensations, [BodySensation.allCases[0]])
        XCTAssertEqual(draft.contextPlaces, [ContextPlace.allCases[0]])
        XCTAssertEqual(draft.contextPeople, [ContextPeople.allCases[0]])
        XCTAssertEqual(draft.triggers, [Trigger.allCases[0]])
        XCTAssertEqual(draft.coping, [Coping.allCases[0]])
    }

    func testFromCoreOnlyLogHasNilSecondaryAndSpecific() {
        let log = FeelingLog(
            selection: EmotionSelection(core: core("happy"), secondary: nil, specific: nil),
            intensity: nil,
            note: ""
        )
        let draft = CheckInDraft.from(log: log)
        XCTAssertEqual(draft.selection?.core.id, "happy")
        XCTAssertNil(draft.selection?.secondary)
        XCTAssertNil(draft.selection?.specific)
    }

    func testFromCoreSecondaryLogHasNilSpecific() {
        let (c, s, _) = deepCore()
        let log = FeelingLog(
            selection: EmotionSelection(core: c, secondary: s, specific: nil),
            intensity: nil,
            note: ""
        )
        let draft = CheckInDraft.from(log: log)
        XCTAssertEqual(draft.selection?.secondary?.id, s.id)
        XCTAssertNil(draft.selection?.specific)
    }

    func testFromLogWithoutIntensityClearsToggle() {
        let log = FeelingLog(
            selection: EmotionSelection(core: core("happy"), secondary: nil, specific: nil),
            intensity: nil,
            note: ""
        )
        let draft = CheckInDraft.from(log: log)
        XCTAssertFalse(draft.includeIntensity)
    }

    func testFromLogWithMoodSetsToggle() {
        let log = FeelingLog(
            selection: EmotionSelection(core: core("happy"), secondary: nil, specific: nil),
            intensity: nil,
            note: "",
            moodEnergy: 0.3,
            moodValence: 0.1
        )
        let draft = CheckInDraft.from(log: log)
        XCTAssertTrue(draft.includeMoodScale)
        XCTAssertEqual(draft.moodEnergy, 0.3)
        XCTAssertEqual(draft.moodValence, 0.1)
    }

    // MARK: - apply(to:)

    func testApplyWritesEveryFieldBack() {
        let log = fullLog()
        var draft = CheckInDraft.from(log: log)
        // Mutate every field.
        draft.selection = EmotionSelection(core: core("sad"), secondary: nil, specific: nil)
        draft.note = "  changed  "
        draft.intensity = 2
        draft.moodEnergy = -0.5
        draft.bodyRegions = [.stomach]

        draft.apply(to: log)

        XCTAssertEqual(log.coreID, "sad")
        XCTAssertEqual(log.secondaryID, "")
        XCTAssertEqual(log.specificID, "")
        XCTAssertEqual(log.intensity, 2)
        XCTAssertEqual(log.note, "changed")  // trimmed
        XCTAssertEqual(log.bodyRegions, [.stomach])
        XCTAssertEqual(log.moodEnergy, -0.5)
    }

    func testApplyClearsIntensityWhenToggledOff() {
        let log = fullLog()
        var draft = CheckInDraft.from(log: log)
        draft.includeIntensity = false

        draft.apply(to: log)

        XCTAssertNil(log.intensity)
    }

    func testApplyClearsMoodWhenToggledOff() {
        let log = fullLog()
        var draft = CheckInDraft.from(log: log)
        draft.includeMoodScale = false

        draft.apply(to: log)

        XCTAssertNil(log.moodEnergy)
        XCTAssertNil(log.moodValence)
    }

    func testApplyPreservesImmutableMetadata() {
        let log = fullLog()
        log.healthSyncStatus = .synced
        let originalID = log.id
        let originalDate = log.createdAt
        var draft = CheckInDraft.from(log: log)
        draft.note = "edited"

        draft.apply(to: log)

        XCTAssertEqual(log.id, originalID)
        XCTAssertEqual(log.createdAt, originalDate)
        XCTAssertEqual(log.healthSyncStatus, .synced)
        XCTAssertEqual(log.captureSource, "phone")
    }

    func testApplyDowngradesPathToCoreOnly() {
        let log = fullLog()  // has core+secondary+specific
        var draft = CheckInDraft.from(log: log)
        draft.selection = EmotionSelection(core: core("happy"), secondary: nil, specific: nil)

        draft.apply(to: log)

        XCTAssertEqual(log.coreID, "happy")
        XCTAssertEqual(log.secondaryID, "")
        XCTAssertEqual(log.secondaryName, "")
        XCTAssertEqual(log.specificID, "")
        XCTAssertEqual(log.specificName, "")
    }

    func testApplyUpgradesCoreOnlyToDeepPath() {
        let (c, s, sp) = deepCore()
        let log = FeelingLog(
            selection: EmotionSelection(core: c, secondary: nil, specific: nil),
            intensity: nil,
            note: ""
        )
        var draft = CheckInDraft.from(log: log)
        draft.selection = EmotionSelection(core: c, secondary: s, specific: sp)

        draft.apply(to: log)

        XCTAssertEqual(log.secondaryID, s.id)
        XCTAssertEqual(log.specificID, sp.id)
        XCTAssertEqual(log.specificName, sp.name)
    }

    func testApplyWithNilSelectionIsNoOp() {
        let log = fullLog()
        let originalCore = log.coreID
        var draft = CheckInDraft.from(log: log)
        draft.selection = nil

        draft.apply(to: log)

        XCTAssertEqual(log.coreID, originalCore, "apply must no-op without a selection")
    }
}
