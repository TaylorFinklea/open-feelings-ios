import XCTest
@testable import OpenFeelings

final class TodayViewAXTests: XCTestCase {
    private func log(createdAt: Date = Date(timeIntervalSince1970: 1_715_000_000),
                     intensity: Int? = nil) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        let log = FeelingLog(selection: selection, intensity: intensity, note: "")
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
}
