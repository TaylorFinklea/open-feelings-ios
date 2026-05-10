import XCTest
@testable import OpenFeelings

final class TherapyReportDataTests: XCTestCase {
    private func log(coreID: String,
                     daysAgo: Double,
                     now: Date,
                     intensity: Int? = nil,
                     note: String = "") -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == coreID }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        let l = FeelingLog(selection: selection, intensity: intensity, note: note)
        l.createdAt = now.addingTimeInterval(-daysAgo * 86_400)
        return l
    }

    private func intention(daysAgo: Int,
                           text: String,
                           reflection: String = "",
                           now: Date) -> Intention {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        return Intention(date: date, text: text, reflection: reflection)
    }

    // MARK: - Window filtering

    func testFilterLast7DaysDropsOlderLogs() {
        let now = Date()
        let logs = [
            log(coreID: "happy", daysAgo: 1, now: now),
            log(coreID: "sad",   daysAgo: 6, now: now),
            log(coreID: "angry", daysAgo: 8, now: now),
        ]
        let filtered = TherapyReportData.filter(logs: logs, window: .last7Days, now: now)
        XCTAssertEqual(filtered.count, 2)
    }

    func testFilterAllTimeKeepsEverything() {
        let now = Date()
        let logs = [
            log(coreID: "happy", daysAgo: 1, now: now),
            log(coreID: "sad",   daysAgo: 90, now: now),
            log(coreID: "angry", daysAgo: 365, now: now),
        ]
        XCTAssertEqual(TherapyReportData.filter(logs: logs, window: .allTime, now: now).count, 3)
    }

    func testWindowMapsToInsightsPeriod() {
        XCTAssertEqual(TherapyReportData.Window.last7Days.insightsPeriod, .week)
        XCTAssertEqual(TherapyReportData.Window.last30Days.insightsPeriod, .month)
        XCTAssertEqual(TherapyReportData.Window.allTime.insightsPeriod, .all)
    }

    // MARK: - Notable logs ordering

    func testNotableLogsSortByIntensityFirst() {
        let now = Date()
        let logs = [
            log(coreID: "happy", daysAgo: 1, now: now, intensity: 2),
            log(coreID: "sad",   daysAgo: 1, now: now, intensity: 5),
            log(coreID: "angry", daysAgo: 1, now: now, intensity: 3),
        ]
        let notable = TherapyReportData.topNotableLogs(in: logs, limit: 5)
        XCTAssertEqual(notable.map(\.intensity), [5, 3, 2])
    }

    func testNotableLogsBreakIntensityTieByNotePresence() {
        let now = Date()
        let withoutNote = log(coreID: "happy", daysAgo: 1, now: now, intensity: 4, note: "")
        let withNote    = log(coreID: "sad",   daysAgo: 1, now: now, intensity: 4, note: "important")
        let notable = TherapyReportData.topNotableLogs(in: [withoutNote, withNote], limit: 5)
        XCTAssertEqual(notable.first?.note, "important")
    }

    func testNotableLogsBreakIntensityAndNoteTieByRecency() {
        let now = Date()
        let older  = log(coreID: "happy", daysAgo: 5, now: now, intensity: 3, note: "x")
        let newer  = log(coreID: "sad",   daysAgo: 1, now: now, intensity: 3, note: "x")
        let notable = TherapyReportData.topNotableLogs(in: [older, newer], limit: 5)
        XCTAssertEqual(notable.first?.coreName, "Sad")
    }

    func testNotableLogsCappedAtLimit() {
        let now = Date()
        let logs = (1...10).map { log(coreID: "happy", daysAgo: Double($0), now: now, intensity: $0) }
        let notable = TherapyReportData.topNotableLogs(in: logs, limit: 5)
        XCTAssertEqual(notable.count, 5)
    }

    func testNotableLogsTreatNilIntensityAsZero() {
        let now = Date()
        let nilLog = log(coreID: "happy", daysAgo: 1, now: now, intensity: nil)
        let oneLog = log(coreID: "sad",   daysAgo: 1, now: now, intensity: 1)
        let notable = TherapyReportData.topNotableLogs(in: [nilLog, oneLog], limit: 5)
        XCTAssertEqual(notable.first?.intensity, 1)
    }

    // MARK: - Detail level controls allLogs population

    func testFullEntriesDetailPopulatesAllLogs() {
        let now = Date()
        let logs = [
            log(coreID: "happy", daysAgo: 1, now: now),
            log(coreID: "sad",   daysAgo: 3, now: now),
        ]
        let report = TherapyReportData.build(window: .last7Days,
                                             detailLevel: .fullEntries,
                                             logs: logs,
                                             intentions: [],
                                             now: now)
        XCTAssertEqual(report.allLogs.count, 2)
    }

    func testPatternsOnlyDetailLeavesAllLogsEmpty() {
        let now = Date()
        let logs = [log(coreID: "happy", daysAgo: 1, now: now)]
        let report = TherapyReportData.build(window: .last7Days,
                                             detailLevel: .patternsOnly,
                                             logs: logs,
                                             intentions: [],
                                             now: now)
        XCTAssertTrue(report.allLogs.isEmpty)
    }

    func testPatternsAndNotableDetailLeavesAllLogsEmpty() {
        let now = Date()
        let logs = [log(coreID: "happy", daysAgo: 1, now: now, intensity: 4)]
        let report = TherapyReportData.build(window: .last7Days,
                                             detailLevel: .patternsAndNotable,
                                             logs: logs,
                                             intentions: [],
                                             now: now)
        XCTAssertTrue(report.allLogs.isEmpty)
        XCTAssertEqual(report.notableLogs.count, 1)
    }

    // MARK: - Intentions filtering

    func testIntentionSummariesFilteredByWindow() {
        let now = Date()
        let summaries = TherapyReportData.intentionSummaries(
            intentions: [
                intention(daysAgo: 2, text: "in", now: now),
                intention(daysAgo: 9, text: "out", now: now),
            ],
            logs: [],
            window: .last7Days,
            now: now
        )
        XCTAssertEqual(summaries.map(\.text), ["in"])
    }

    func testIntentionSummaryCarriesReflectionAndCores() {
        let now = Date()
        let dayBack = Calendar.current.date(byAdding: .day, value: -2, to: now)!
        let summaries = TherapyReportData.intentionSummaries(
            intentions: [intention(daysAgo: 2, text: "be kind", reflection: "went well", now: now)],
            logs: [
                log(coreID: "happy", daysAgo: 2, now: now),
                log(coreID: "happy", daysAgo: 2, now: now),
            ],
            window: .last7Days,
            now: now
        )
        XCTAssertEqual(summaries.first?.reflection, "went well")
        XCTAssertEqual(summaries.first?.topCoreNamesOnDay, ["Happy"])
        XCTAssertEqual(Calendar.current.startOfDay(for: summaries.first!.date),
                       Calendar.current.startOfDay(for: dayBack))
    }

    // MARK: - Smoke

    func testEmptyWindowProducesZeroAggregates() {
        let now = Date()
        let report = TherapyReportData.build(window: .last7Days,
                                             detailLevel: .patternsAndNotable,
                                             logs: [],
                                             intentions: [],
                                             now: now)
        XCTAssertEqual(report.dataset.totalCount, 0)
        XCTAssertTrue(report.notableLogs.isEmpty)
        XCTAssertTrue(report.allLogs.isEmpty)
        XCTAssertTrue(report.intentions.isEmpty)
    }
}
