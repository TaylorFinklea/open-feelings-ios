import XCTest
@testable import OpenFeelings

final class ExportServiceMarkdownTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(year: Int = 2026, month: Int = 5, day: Int,
                      hour: Int = 8, minute: Int = 32) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day
        c.hour = hour; c.minute = minute; c.timeZone = TimeZone(identifier: "America/Chicago")
        return cal.date(from: c)!
    }

    private func core(_ id: String) -> EmotionCore {
        EmotionTaxonomy.cores.first { $0.id == id }!
    }

    private func minimalLog() -> FeelingLog {
        let selection = EmotionSelection(core: core("fearful"), secondary: nil, specific: nil)
        let log = FeelingLog(selection: selection, intensity: nil, note: "")
        log.createdAt = date(day: 5)
        return log
    }

    private func maximalLog(note: String) -> FeelingLog {
        let core = core("fearful")
        let secondary = core.secondaries.first!
        let specific = secondary.specifics.first
        let selection = EmotionSelection(core: core, secondary: secondary, specific: specific)
        let log = FeelingLog(
            selection: selection,
            intensity: 4,
            note: note,
            bodyRegions: [.chest],
            bodySensations: [.tight, .buzzing],
            contextPlaces: [.work],
            contextPeople: [.coworkers],
            triggers: [.anticipation],
            coping: [.breath],
            moodEnergy: 0.6,
            moodValence: -0.4
        )
        log.createdAt = date(day: 5)
        return log
    }

    func testMarkdownMinimalLogOmitsDimensionsAndQuoteBlock() {
        let md = ExportService.markdown(log: minimalLog(), calendar: cal,
                                         locale: Locale(identifier: "en_US"))
        XCTAssertTrue(md.contains("## "), "Has a heading")
        XCTAssertFalse(md.contains("**Body:**"))
        XCTAssertFalse(md.contains("**Context:**"))
        XCTAssertFalse(md.contains("**Triggers / Coping:**"))
        XCTAssertFalse(md.contains("**Mood:**"))
        XCTAssertFalse(md.contains("\n> "), "No quote block when note empty")
    }

    func testMarkdownMaximalLogIncludesEveryDimensionAndQuotedParagraphs() {
        let note = "Tight knot before standup.\n\nThursday looms."
        let md = ExportService.markdown(log: maximalLog(note: note), calendar: cal,
                                         locale: Locale(identifier: "en_US"))
        XCTAssertTrue(md.contains("**Intensity:** 4 / 5"))
        XCTAssertTrue(md.contains("**Body:**"))
        XCTAssertTrue(md.contains("**Context:**"))
        XCTAssertTrue(md.contains("**Triggers / Coping:**"))
        XCTAssertTrue(md.contains("**Mood:**"))
        XCTAssertTrue(md.contains("> Tight knot before standup."))
        XCTAssertTrue(md.contains("> Thursday looms."))
    }

    func testMarkdownGroupsByDateDescending() {
        let logsAcrossDays: [FeelingLog] = [
            { let l = minimalLog(); l.createdAt = date(day: 3); return l }(),
            { let l = minimalLog(); l.createdAt = date(day: 5); return l }(),
            { let l = minimalLog(); l.createdAt = date(day: 4); return l }()
        ]
        let md = ExportService.markdown(logs: logsAcrossDays, calendar: cal,
                                         locale: Locale(identifier: "en_US"))
        guard let day5Range = md.range(of: "May 5, 2026"),
              let day4Range = md.range(of: "May 4, 2026"),
              let day3Range = md.range(of: "May 3, 2026") else {
            XCTFail("Missing day headings")
            return
        }
        XCTAssertLessThan(day5Range.lowerBound, day4Range.lowerBound,
                          "May 5 (most recent) appears before May 4")
        XCTAssertLessThan(day4Range.lowerBound, day3Range.lowerBound,
                          "May 4 appears before May 3")
        XCTAssertTrue(md.contains("# Open Feelings — May 3 – May 5, 2026")
                      || md.contains("# Open Feelings — May 3"),
                      "H1 contains the date range")
    }

    func testPlainTextStripsMarkdownSyntaxButPreservesContent() {
        let log = maximalLog(note: "Line one.\nLine two.")
        let plain = ExportService.plainText(log: log, calendar: cal,
                                             locale: Locale(identifier: "en_US"))
        XCTAssertFalse(plain.contains("**"))
        XCTAssertFalse(plain.contains("##"))
        XCTAssertFalse(plain.contains("> "))
        // Content survives.
        XCTAssertTrue(plain.contains("Intensity: 4 / 5"))
        XCTAssertTrue(plain.contains("Line one."))
        XCTAssertTrue(plain.contains("Line two."))
    }

    func testEmptyLogsBundle() {
        let md = ExportService.markdown(logs: [], calendar: cal,
                                         locale: Locale(identifier: "en_US"))
        XCTAssertTrue(md.contains("No check-ins to export."))
    }
}
