import XCTest
@testable import OpenFeelings

/// Coverage for the iOS-side "stop at any level" behavior that was previously
/// only on watch. EmotionSelection.isComplete and FeelingLog.emotionTitle both
/// need to gracefully handle entries with secondary/specific missing.
final class StopAtAnyLevelTests: XCTestCase {

    // MARK: - EmotionSelection.isComplete

    func testIsCompleteTrueForCoreOnlySelection() {
        let core = EmotionTaxonomy.cores.first { $0.id == "angry" }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        XCTAssertTrue(selection.isComplete,
                      "Picking just a core must be enough to save")
    }

    func testIsCompleteTrueForSecondaryStopSelection() {
        let core = EmotionTaxonomy.cores.first { $0.id == "angry" }!
        let secondary = core.secondaries.first { $0.name == "Bitter" }!
        let selection = EmotionSelection(core: core, secondary: secondary, specific: nil)
        XCTAssertTrue(selection.isComplete,
                      "Picking just core + secondary (e.g., 'Bitter') must be enough to save")
    }

    func testIsCompleteTrueForFullDrillSelection() {
        let core = EmotionTaxonomy.cores.first { $0.id == "angry" }!
        let secondary = core.secondaries.first { $0.name == "Bitter" }!
        let specific = secondary.specifics.first!
        let selection = EmotionSelection(core: core, secondary: secondary, specific: specific)
        XCTAssertTrue(selection.isComplete)
    }

    // MARK: - FeelingLog.emotionTitle fallback

    private func bareLog(coreName: String, secondaryName: String = "", specificName: String = "") -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "angry" }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        let log = FeelingLog(selection: selection, intensity: nil, note: "")
        log.coreName = coreName
        log.secondaryName = secondaryName
        log.specificName = specificName
        return log
    }

    func testEmotionTitleFallsThroughToCoreNameWhenDeeperLevelsEmpty() {
        let log = bareLog(coreName: "Angry")
        XCTAssertEqual(log.emotionTitle, "Angry",
                       "Core-only entries (watch or stop-at-core iOS) should show the core name")
    }

    func testEmotionTitleFallsThroughToSecondaryWhenSpecificEmpty() {
        let log = bareLog(coreName: "Angry", secondaryName: "Bitter")
        XCTAssertEqual(log.emotionTitle, "Bitter")
    }

    func testEmotionTitlePrefersSpecificWhenSet() {
        let log = bareLog(coreName: "Angry", secondaryName: "Bitter", specificName: "Resentful")
        XCTAssertEqual(log.emotionTitle, "Resentful")
    }

    // MARK: - pathTitle still filters empties

    func testPathTitleFiltersEmptyLevels() {
        let coreOnly = bareLog(coreName: "Angry")
        XCTAssertEqual(coreOnly.pathTitle, "Angry")

        let coreAndSecondary = bareLog(coreName: "Angry", secondaryName: "Bitter")
        XCTAssertEqual(coreAndSecondary.pathTitle, "Angry > Bitter")

        let full = bareLog(coreName: "Angry", secondaryName: "Bitter", specificName: "Resentful")
        XCTAssertEqual(full.pathTitle, "Angry > Bitter > Resentful")
    }
}
