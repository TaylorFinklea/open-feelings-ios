import XCTest
@testable import OpenFeelings

final class WeekSummaryTests: XCTestCase {
    private func log(coreID: String, coreName: String, daysAgo: Double, now: Date) -> FeelingLog {
        let selection = EmotionTaxonomy.selection(coreID: coreID,
                                                  secondaryID: nil,
                                                  specificID: nil)!
        let log = FeelingLog(selection: selection, intensity: nil, note: "")
        log.createdAt = now.addingTimeInterval(-daysAgo * 86_400)
        return log
    }

    func testEmptyLogsReturnsNil() {
        XCTAssertNil(WeekSummary.summarize(logs: [], now: Date()))
    }

    func testReturnsTopCoreWithCount() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", daysAgo: 3, now: now),
            log(coreID: "sad",   coreName: "Sad",   daysAgo: 4, now: now),
        ]
        let summary = WeekSummary.summarize(logs: logs, now: now)
        XCTAssertEqual(summary?.topCoreName, "Happy")
        XCTAssertEqual(summary?.totalCount, 3)
    }

    func testIgnoresLogsOlderThan7Days() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", daysAgo: 2,  now: now),
            log(coreID: "sad",   coreName: "Sad",   daysAgo: 30, now: now),
        ]
        let summary = WeekSummary.summarize(logs: logs, now: now)
        XCTAssertEqual(summary?.topCoreName, "Happy")
        XCTAssertEqual(summary?.totalCount, 1)
    }

    func testTieBreaksOnMostRecentCore() {
        let now = Date()
        let logs = [
            log(coreID: "sad",   coreName: "Sad",   daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", daysAgo: 2, now: now),
        ]
        // Equal counts; "Sad" was logged most recently, so tie-break favors it.
        let summary = WeekSummary.summarize(logs: logs, now: now)
        XCTAssertEqual(summary?.topCoreName, "Sad")
    }
}
