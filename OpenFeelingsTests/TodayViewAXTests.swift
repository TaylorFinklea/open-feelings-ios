import XCTest
@testable import OpenFeelings

final class TodayViewAXTests: XCTestCase {
    private func log(createdAt: Date = Date(timeIntervalSince1970: 1_715_000_000),
                     intensity: Int? = nil,
                     captureSource: String = "phone") -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        let log = FeelingLog(selection: selection,
                             intensity: intensity,
                             note: "",
                             captureSource: captureSource)
        log.createdAt = createdAt
        return log
    }

    func testTodayLogAXLabelIncludesFormattedTime() {
        let entry = log()
        let expectedTime = entry.createdAt.formatted(.dateTime.hour().minute())
        XCTAssertTrue(TodayView.todayLogAXLabel(for: entry).contains(expectedTime))
    }

    func testTodayLogAXLabelIncludesEmotionPath() {
        XCTAssertTrue(TodayView.todayLogAXLabel(for: log()).contains("Happy"))
    }

    func testTodayLogAXLabelIncludesIntensityOnlyWhenSet() {
        XCTAssertTrue(TodayView.todayLogAXLabel(for: log(intensity: 3)).contains("intensity 3 of 5"))
        XCTAssertFalse(TodayView.todayLogAXLabel(for: log()).contains("intensity"))
    }

    func testWeekSummaryAXLabelIncludesCountAndTopFeeling() {
        let summary = WeekSummary(topCoreID: "happy", topCoreName: "Happy", totalCount: 2)
        XCTAssertEqual(TodayView.weekSummaryAXLabel(for: summary), "This week: 2 check-ins, top feeling Happy")
    }

    func testTodayLogAXLabelMentionsAppleWatchOnlyForWatchSource() {
        XCTAssertFalse(TodayView.todayLogAXLabel(for: log()).contains("Apple Watch"))
        XCTAssertTrue(TodayView.todayLogAXLabel(for: log(captureSource: "watch"))
                      .contains("from Apple Watch"))
    }

    func testTodayAXLabelIncludesSiriSource() {
        let log = FeelingLog(selection: EmotionTaxonomy.selection(coreID: "happy", secondaryID: nil, specificID: nil)!,
                             intensity: nil, note: "", captureSource: "siri")
        XCTAssertTrue(TodayView.todayLogAXLabel(for: log).contains("from Siri"))
    }

    func testTodayAXLabelIncludesQuickEntrySource() {
        let log = FeelingLog(selection: EmotionTaxonomy.selection(coreID: "happy", secondaryID: nil, specificID: nil)!,
                             intensity: nil, note: "", captureSource: "quickentry")
        XCTAssertTrue(TodayView.todayLogAXLabel(for: log).contains("from quick entry"))
    }
}
