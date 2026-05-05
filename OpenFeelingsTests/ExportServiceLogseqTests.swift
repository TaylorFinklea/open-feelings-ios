import XCTest
@testable import OpenFeelings

final class ExportServiceLogseqTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(day: Int, hour: Int = 8) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = day; c.hour = hour
        c.timeZone = TimeZone(identifier: "America/Chicago")
        return cal.date(from: c)!
    }

    private func core(_ id: String) -> EmotionCore {
        EmotionTaxonomy.cores.first { $0.id == id }!
    }

    private func sampleLog(note: String = "",
                           bodyRegions: [BodyRegion] = [],
                           triggers: [Trigger] = []) -> FeelingLog {
        let core = core("fearful")
        let secondary = core.secondaries.first!
        let selection = EmotionSelection(core: core, secondary: secondary, specific: nil)
        let log = FeelingLog(
            selection: selection,
            intensity: 3,
            note: note,
            bodyRegions: bodyRegions,
            triggers: triggers
        )
        log.createdAt = date(day: 5)
        return log
    }

    func testLogseqBulletStructureForSingleLog() {
        let output = ExportService.logseq(logs: [sampleLog()], calendar: cal,
                                            locale: Locale(identifier: "en_US"))
        XCTAssertTrue(output.contains("# 2026-05-05"))
        XCTAssertTrue(output.contains("- ## "))
        XCTAssertTrue(output.contains("  created-at:: "))
        XCTAssertTrue(output.contains("  intensity:: 3"))
        XCTAssertTrue(output.contains("  core:: [[fearful]]"))
    }

    func testLogseqWrapsBodyTagsInDoubleBracketsKebabCase() {
        let log = sampleLog(bodyRegions: [.chest])
        let output = ExportService.logseq(logs: [log], calendar: cal,
                                            locale: Locale(identifier: "en_US"))
        XCTAssertTrue(output.contains("  body:: [[chest]]"))
    }

    func testLogseqJournalAsSubBulletsWithParagraphs() {
        let note = "First paragraph.\n\nSecond paragraph."
        let log = sampleLog(note: note)
        let output = ExportService.logseq(logs: [log], calendar: cal,
                                            locale: Locale(identifier: "en_US"))
        XCTAssertTrue(output.contains("  - **Journal**"))
        XCTAssertTrue(output.contains("    - First paragraph."))
        XCTAssertTrue(output.contains("    - Second paragraph."))
    }

    func testLogseqEmptyArraysProduceNoPropertyLine() {
        let output = ExportService.logseq(logs: [sampleLog()], calendar: cal,
                                            locale: Locale(identifier: "en_US"))
        XCTAssertFalse(output.contains("body::"))
        XCTAssertFalse(output.contains("context::"))
        XCTAssertFalse(output.contains("triggers::"))
        XCTAssertFalse(output.contains("coping::"))
    }

    func testLogseqDateGroupingDescending() {
        let day3 = sampleLog(); day3.createdAt = date(day: 3)
        let day5 = sampleLog(); day5.createdAt = date(day: 5)
        let day4 = sampleLog(); day4.createdAt = date(day: 4)
        let output = ExportService.logseq(logs: [day3, day5, day4], calendar: cal,
                                            locale: Locale(identifier: "en_US"))
        guard let r5 = output.range(of: "# 2026-05-05"),
              let r4 = output.range(of: "# 2026-05-04"),
              let r3 = output.range(of: "# 2026-05-03") else {
            XCTFail("Missing day headings")
            return
        }
        XCTAssertLessThan(r5.lowerBound, r4.lowerBound)
        XCTAssertLessThan(r4.lowerBound, r3.lowerBound)
    }
}
