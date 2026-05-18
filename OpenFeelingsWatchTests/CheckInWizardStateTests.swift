import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class CheckInWizardStateTests: XCTestCase {

    // MARK: - feelingPath

    func testFeelingPathReturnsEmptyStringWhenNoCorePicked() {
        let state = CheckInWizardState()
        XCTAssertEqual(state.feelingPath, "")
    }

    func testFeelingPathShowsCoreOnly() {
        let state = CheckInWizardState()
        state.core = EmotionTaxonomy.cores.first { $0.id == "happy" }
        XCTAssertEqual(state.feelingPath, "Happy")
    }

    func testFeelingPathShowsCoreAndSecondary() {
        let state = CheckInWizardState()
        let happy = EmotionTaxonomy.cores.first { $0.id == "happy" }
        state.core = happy
        state.secondary = happy?.secondaries.first
        let expected = "Happy › \(happy?.secondaries.first?.name ?? "?")"
        XCTAssertEqual(state.feelingPath, expected)
    }

    func testFeelingPathShowsFullDrill() {
        let state = CheckInWizardState()
        let happy = EmotionTaxonomy.cores.first { $0.id == "happy" }
        let secondary = happy?.secondaries.first
        let specific = secondary?.specifics.first
        state.core = happy
        state.secondary = secondary
        state.specific = specific
        let expected = "Happy › \(secondary?.name ?? "?") › \(specific?.name ?? "?")"
        XCTAssertEqual(state.feelingPath, expected)
    }

    // MARK: - shouldShowSensations

    func testShouldShowSensationsFalseWhenNoRegionsPicked() {
        let state = CheckInWizardState()
        XCTAssertFalse(state.shouldShowSensations)
    }

    func testShouldShowSensationsTrueWhenAnyConcreteRegionPicked() {
        let state = CheckInWizardState()
        state.bodyRegions = [.chest]
        XCTAssertTrue(state.shouldShowSensations)

        state.bodyRegions = [.chest, .stomach]
        XCTAssertTrue(state.shouldShowSensations)
    }

    func testShouldShowSensationsFalseWhenOnlyNowherePicked() {
        // "Nowhere" semantically means "I don't feel this in my body", so the
        // sensations step should not appear.
        let state = CheckInWizardState()
        state.bodyRegions = [.nowhere]
        XCTAssertFalse(state.shouldShowSensations)
    }

    func testShouldShowSensationsFalseWhenNowhereAmongOthers() {
        // The .nowhere check is "contains" — any presence of .nowhere skips
        // sensations even if other regions are also selected. This protects
        // against accidental UI states where both are toggled on briefly.
        let state = CheckInWizardState()
        state.bodyRegions = [.chest, .nowhere]
        XCTAssertFalse(state.shouldShowSensations)
    }

    // MARK: - trimmedNote

    func testTrimmedNoteStripsLeadingAndTrailingWhitespace() {
        let state = CheckInWizardState()
        state.note = "  hello world  "
        XCTAssertEqual(state.trimmedNote, "hello world")
    }

    func testTrimmedNoteStripsNewlines() {
        let state = CheckInWizardState()
        state.note = "\n\nhello\n"
        XCTAssertEqual(state.trimmedNote, "hello")
    }

    func testTrimmedNoteEmptyWhenWhitespaceOnly() {
        let state = CheckInWizardState()
        state.note = "   \n\t  "
        XCTAssertEqual(state.trimmedNote, "")
    }

    // MARK: - reset

    func testResetClearsEveryField() {
        let state = CheckInWizardState()
        let happy = EmotionTaxonomy.cores.first { $0.id == "happy" }
        state.core = happy
        state.secondary = happy?.secondaries.first
        state.specific = state.secondary?.specifics.first
        state.intensity = 5
        state.bodyRegions = [.chest, .stomach]
        state.bodySensations = [.tight, .warm]
        state.note = "test note"
        state.didSend = true

        state.reset()

        XCTAssertNil(state.core)
        XCTAssertNil(state.secondary)
        XCTAssertNil(state.specific)
        XCTAssertEqual(state.intensity, 3)
        XCTAssertTrue(state.bodyRegions.isEmpty)
        XCTAssertTrue(state.bodySensations.isEmpty)
        XCTAssertEqual(state.note, "")
        XCTAssertFalse(state.didSend)
    }

    func testResetIsIdempotent() {
        let state = CheckInWizardState()
        state.reset()
        state.reset()
        // Defaults match the fresh-init state.
        XCTAssertNil(state.core)
        XCTAssertEqual(state.intensity, 3)
        XCTAssertFalse(state.didSend)
    }
}
