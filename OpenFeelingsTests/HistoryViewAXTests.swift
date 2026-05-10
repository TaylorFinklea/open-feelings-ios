import XCTest
@testable import OpenFeelings

final class HistoryViewAXTests: XCTestCase {
    private func log(intensity: Int? = nil, note: String = "") -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        let log = FeelingLog(selection: selection, intensity: intensity, note: note)
        log.createdAt = Date(timeIntervalSince1970: 1_715_000_000)
        return log
    }

    func testCardAXLabelIncludesPathAndDate() {
        let label = LogCard.cardAXLabel(for: log())
        XCTAssertTrue(label.contains("Happy"))
        XCTAssertFalse(label.isEmpty)
    }

    func testCardAXLabelIncludesIntensityWhenSet() {
        XCTAssertTrue(LogCard.cardAXLabel(for: log(intensity: 4)).contains("intensity 4 of 5"))
    }

    func testCardAXLabelMentionsNoteWhenPresent() {
        XCTAssertTrue(LogCard.cardAXLabel(for: log(note: "x")).contains("with a note"))
    }
}
