import XCTest
@testable import OpenFeelings

@MainActor
final class HistoryDateGroupingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeNow() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 10
        components.hour = 14
        components.minute = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: components)!
    }

    private func log(daysAgo: Int, hour: Int = 12, now: Date) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let log = FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: nil,
            note: ""
        )
        let day = calendar.date(
            byAdding: .day,
            value: -daysAgo,
            to: calendar.startOfDay(for: now)
        )!
        log.createdAt = calendar.date(byAdding: .hour, value: hour, to: day)!
        return log
    }

    func testEmptyLogsProducesEmptyGroups() {
        XCTAssertTrue(HistoryView.groupByDay([], now: makeNow(), calendar: calendar).isEmpty)
    }

    func testLogsOnTheSameDayBucketIntoOneGroup() {
        let now = makeNow()
        let logs = [
            log(daysAgo: 0, hour: 9, now: now),
            log(daysAgo: 0, hour: 15, now: now),
        ]

        let groups = HistoryView.groupByDay(logs, now: now, calendar: calendar)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.logs.count, 2)
    }

    func testLogsOnDifferentDaysProduceSeparateGroups() {
        let now = makeNow()
        let logs = [
            log(daysAgo: 0, now: now),
            log(daysAgo: 1, now: now),
            log(daysAgo: 2, now: now),
        ]

        let groups = HistoryView.groupByDay(logs, now: now, calendar: calendar)

        XCTAssertEqual(groups.count, 3)
    }

    func testGroupsAreSortedDescendingByDay() {
        let now = makeNow()
        let logs = [
            log(daysAgo: 3, now: now),
            log(daysAgo: 1, now: now),
            log(daysAgo: 5, now: now),
        ]

        let groups = HistoryView.groupByDay(logs, now: now, calendar: calendar)

        XCTAssertEqual(groups.map(\.day), groups.map(\.day).sorted(by: >))
    }

    func testLogsWithinAGroupRemainCreatedAtDescending() {
        let now = makeNow()
        let logs = [
            log(daysAgo: 0, hour: 9, now: now),
            log(daysAgo: 0, hour: 18, now: now),
        ]

        let groups = HistoryView.groupByDay(logs, now: now, calendar: calendar)

        XCTAssertEqual(
            groups.first?.logs.first?.createdAt,
            logs.max(by: { $0.createdAt < $1.createdAt })?.createdAt
        )
    }

    func testTodayBucketHasTodayLabel() {
        let now = makeNow()

        let groups = HistoryView.groupByDay([log(daysAgo: 0, now: now)], now: now, calendar: calendar)

        XCTAssertEqual(groups.first?.label, "Today")
    }

    func testYesterdayBucketHasYesterdayLabel() {
        let now = makeNow()

        let groups = HistoryView.groupByDay([log(daysAgo: 1, now: now)], now: now, calendar: calendar)

        XCTAssertEqual(groups.first?.label, "Yesterday")
    }

    func testOlderBucketHasFormattedDateLabel() throws {
        let now = makeNow()

        let groups = HistoryView.groupByDay([log(daysAgo: 3, now: now)], now: now, calendar: calendar)
        let label = try XCTUnwrap(groups.first?.label)

        XCTAssertNotEqual(label, "Today")
        XCTAssertNotEqual(label, "Yesterday")
        XCTAssertTrue(label.contains(where: { $0.isNumber }))
    }
}
