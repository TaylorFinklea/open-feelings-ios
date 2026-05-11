import XCTest
@testable import OpenFeelings

@MainActor
final class TherapyReportPDFServiceTests: XCTestCase {
    private func log(intensity: Int? = nil, note: String = "", daysAgo: Double = 1) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let log = FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: intensity,
            note: note
        )
        log.createdAt = Date().addingTimeInterval(-daysAgo * 86_400)
        return log
    }

    private func intention(daysAgo: Int, text: String = "be kind", reflection: String = "") -> IntentionSummary {
        IntentionSummary(
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            text: text,
            reflection: reflection,
            topCoreNamesOnDay: []
        )
    }

    private func report(
        detailLevel: TherapyReportData.DetailLevel,
        logs: [FeelingLog] = [],
        notableLogs: [FeelingLog] = [],
        intentions: [IntentionSummary] = []
    ) -> TherapyReportData {
        TherapyReportData(
            window: .last7Days,
            detailLevel: detailLevel,
            generatedAt: Date(),
            dataset: .empty,
            intentions: intentions,
            notableLogs: notableLogs,
            allLogs: logs
        )
    }

    func testCoverAndPatternsAlwaysAppear() {
        let pages = TherapyReportPDFService.pages(for: report(detailLevel: .patternsOnly))

        XCTAssertEqual(pages.prefix(2), [.cover, .patterns])
    }

    func testPatternsOnlyOmitsNotableEvenIfNotableLogsPresent() {
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .patternsOnly, notableLogs: [log()])
        )

        XCTAssertFalse(pages.contains(.notable))
    }

    func testPatternsOnlyWithoutIntentionsIsExactlyTwoPages() {
        let pages = TherapyReportPDFService.pages(for: report(detailLevel: .patternsOnly))

        XCTAssertEqual(pages, [.cover, .patterns])
    }

    func testPatternsAndNotableSkipsNotableWhenNotableLogsEmpty() {
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .patternsAndNotable, notableLogs: [])
        )

        XCTAssertFalse(pages.contains(.notable))
    }

    func testPatternsAndNotableIncludesNotablePageWhenLogsPresent() {
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .patternsAndNotable, notableLogs: [log()])
        )

        XCTAssertEqual(pages.filter { $0 == .notable }.count, 1)
    }

    func testFullEntriesNoLogsProducesZeroEntriesPages() {
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: [])
        )

        XCTAssertEqual(pages.filter(\.isEntries).count, 0)
    }

    func testFullEntriesFiveLogsProducesOnePage() {
        let logs = (0..<5).map { _ in log() }
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: logs)
        )

        XCTAssertEqual(pages.filter(\.isEntries), [.entries(pageNumber: 1, totalPages: 1)])
    }

    func testFullEntriesSixLogsProducesTwoPagesNumbered() {
        let logs = (0..<6).map { _ in log() }
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: logs)
        )

        XCTAssertEqual(pages.filter(\.isEntries), [
            .entries(pageNumber: 1, totalPages: 2),
            .entries(pageNumber: 2, totalPages: 2),
        ])
    }

    func testFullEntriesTwelveLogsProducesThreePages() {
        let logs = (0..<12).map { _ in log() }
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: logs)
        )

        XCTAssertEqual(pages.filter(\.isEntries).count, 3)
    }

    func testIntentionsPageOmittedWhenIntentionsEmpty() {
        let pages = TherapyReportPDFService.pages(for: report(detailLevel: .patternsOnly))

        XCTAssertFalse(pages.contains(.intentions))
    }

    func testIntentionsPageAppearsLastWhenIntentionsPresent() {
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .patternsOnly, intentions: [intention(daysAgo: 1)])
        )

        XCTAssertEqual(pages.last, .intentions)
    }

    func testIntentionsAppearsAfterEntriesPagesOnFullDetail() {
        let logs = (0..<6).map { _ in log() }
        let pages = TherapyReportPDFService.pages(
            for: report(detailLevel: .fullEntries, logs: logs, intentions: [intention(daysAgo: 1)])
        )

        XCTAssertEqual(pages.last, .intentions)
        XCTAssertEqual(pages.dropLast().last, .entries(pageNumber: 2, totalPages: 2))
    }

    func testEmptyReportProducesCoverAndPatternsOnly() {
        let pages = TherapyReportPDFService.pages(for: report(detailLevel: .patternsAndNotable))

        XCTAssertEqual(pages, [.cover, .patterns])
    }
}
