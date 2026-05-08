import XCTest
@testable import OpenFeelings

final class CheckInDraftTests: XCTestCase {
    func testEmptyDraftCannotSave() {
        XCTAssertFalse(CheckInDraft().canSave)
    }

    func testCompleteSelectionEnablesSave() {
        let core = EmotionTaxonomy.cores[0]
        let sec = core.secondaries[0]
        var draft = CheckInDraft()
        draft.selection = EmotionSelection(core: core, secondary: sec, specific: nil)
        // Selection requires both secondary AND specific; isComplete should be false here.
        XCTAssertFalse(draft.canSave)
        let spec = sec.specifics[0]
        draft.selection = EmotionSelection(core: core, secondary: sec, specific: spec)
        XCTAssertTrue(draft.canSave)
    }

    func testResetClearsEverything() {
        var draft = CheckInDraft()
        draft.note = "Hello"
        draft.includeIntensity = true
        draft.intensity = 4
        draft.bodyRegions = [.chest]
        draft.reset()
        XCTAssertEqual(draft.note, "")
        XCTAssertFalse(draft.includeIntensity)
        XCTAssertEqual(draft.intensity, 3)
        XCTAssertTrue(draft.bodyRegions.isEmpty)
    }

    func testEverywhereExclusivity() {
        var draft = CheckInDraft()
        draft.toggleRegion(.chest)
        draft.toggleRegion(.head)
        XCTAssertEqual(draft.bodyRegions, [.chest, .head])
        draft.toggleRegion(.wholeBody)
        // Picking Everywhere clears all other regions and is now exclusive.
        XCTAssertEqual(draft.bodyRegions, [.wholeBody])
    }

    func testNowhereExclusivity() {
        var draft = CheckInDraft()
        draft.toggleRegion(.chest)
        draft.toggleRegion(.nowhere)
        XCTAssertEqual(draft.bodyRegions, [.nowhere])
    }

    func testPickingNormalRegionClearsEverywhere() {
        var draft = CheckInDraft()
        draft.toggleRegion(.wholeBody)
        draft.toggleRegion(.chest)
        XCTAssertEqual(draft.bodyRegions, [.chest])
    }
}
