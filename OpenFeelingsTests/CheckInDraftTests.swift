import XCTest
@testable import OpenFeelings

final class CheckInDraftTests: XCTestCase {
    func testEmptyDraftCannotSave() {
        XCTAssertFalse(CheckInDraft().canSave)
    }

    func testCompleteSelectionEnablesSave() {
        let core = EmotionTaxonomy.cores[0]
        let sec = core.secondaries[0]
        let spec = sec.specifics[0]
        var draft = CheckInDraft()

        // Core-only is now saveable (stop-at-any-level mirrors the watch).
        draft.selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        XCTAssertTrue(draft.canSave)

        // Core + secondary is also saveable.
        draft.selection = EmotionSelection(core: core, secondary: sec, specific: nil)
        XCTAssertTrue(draft.canSave)

        // Full drill is saveable.
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

    // MARK: - Custom region toggle semantics

    func testToggleCustomRegionAddsAndRemoves() {
        var draft = CheckInDraft()
        let id = UUID()
        draft.toggleCustomRegion(id)
        XCTAssertEqual(draft.customBodyRegionIDs, [id])
        draft.toggleCustomRegion(id)
        XCTAssertTrue(draft.customBodyRegionIDs.isEmpty)
    }

    func testToggleCustomRegionClearsEverywhere() {
        var draft = CheckInDraft()
        draft.toggleRegion(.wholeBody)
        let id = UUID()
        draft.toggleCustomRegion(id)
        XCTAssertTrue(draft.bodyRegions.isEmpty)
        XCTAssertEqual(draft.customBodyRegionIDs, [id])
    }

    func testPickingEverywhereClearsCustomRegions() {
        var draft = CheckInDraft()
        let id = UUID()
        draft.toggleCustomRegion(id)
        draft.toggleRegion(.wholeBody)
        XCTAssertEqual(draft.bodyRegions, [.wholeBody])
        XCTAssertTrue(draft.customBodyRegionIDs.isEmpty)
    }

    func testCustomAndBuiltInRegularRegionsCoexist() {
        var draft = CheckInDraft()
        let id = UUID()
        draft.toggleRegion(.chest)
        draft.toggleCustomRegion(id)
        XCTAssertEqual(draft.bodyRegions, [.chest])
        XCTAssertEqual(draft.customBodyRegionIDs, [id])
    }
}
