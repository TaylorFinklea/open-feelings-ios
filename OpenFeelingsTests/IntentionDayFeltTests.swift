import XCTest
@testable import OpenFeelings

final class IntentionDayFeltTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(year: Int = 2026, month: Int = 5, day: Int, hour: Int = 12) -> Date {
        var c = DateComponents()
        c.year = year; c.month = month; c.day = day; c.hour = hour
        return cal.date(from: c)!
    }

    private func log(coreID: String, coreName: String, on date: Date) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == coreID }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        let log = FeelingLog(selection: selection, intensity: nil, note: "")
        log.createdAt = date
        return log
    }

    func testReturnsNilWhenNoLogsOnTheDay() {
        let logs = [log(coreID: "happy", coreName: "Happy", on: date(day: 1))]
        XCTAssertNil(IntentionDayFelt.topCoreNames(in: date(day: 2), logs: logs, calendar: cal))
    }

    func testSingleCoreReturnsOneName() {
        let day = date(day: 1)
        let logs = [log(coreID: "happy", coreName: "Happy", on: day)]
        XCTAssertEqual(IntentionDayFelt.topCoreNames(in: day, logs: logs, calendar: cal), ["Happy"])
    }

    func testRanksByCountDescending() {
        let day = date(day: 1)
        let logs = [
            log(coreID: "happy", coreName: "Happy", on: day),
            log(coreID: "happy", coreName: "Happy", on: day),
            log(coreID: "sad",   coreName: "Sad",   on: day)
        ]
        XCTAssertEqual(IntentionDayFelt.topCoreNames(in: day, logs: logs, calendar: cal),
                       ["Happy", "Sad"])
    }

    func testDayBoundaryFiltersOutPreviousDayLogs() {
        // A log at 23:59 on day 1 is in day 1, not day 2.
        let prev = log(coreID: "happy", coreName: "Happy", on: date(day: 1, hour: 23))
        let onDay = log(coreID: "sad", coreName: "Sad", on: date(day: 2, hour: 1))
        XCTAssertEqual(IntentionDayFelt.topCoreNames(in: date(day: 2), logs: [prev, onDay], calendar: cal),
                       ["Sad"])
    }

    func testLimitCapsResults() {
        let day = date(day: 1)
        let logs = [
            log(coreID: "happy",     coreName: "Happy",     on: day),
            log(coreID: "sad",       coreName: "Sad",       on: day),
            log(coreID: "fearful",   coreName: "Fearful",   on: day),
            log(coreID: "angry",     coreName: "Angry",     on: day),
            log(coreID: "disgusted", coreName: "Disgusted", on: day)
        ]
        let result = IntentionDayFelt.topCoreNames(in: day, logs: logs, limit: 2, calendar: cal)
        XCTAssertEqual(result?.count, 2)
    }
}
