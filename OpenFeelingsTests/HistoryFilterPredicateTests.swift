import XCTest
@testable import OpenFeelings

@MainActor
final class HistoryFilterPredicateTests: XCTestCase {
    private func log(coreID: String,
                     secondaryName: String = "",
                     bodyRegions: [BodyRegion] = [],
                     dayOffset: Int = 0) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == coreID }!
        let log = FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: nil,
            note: "",
            bodyRegions: bodyRegions
        )
        log.secondaryName = secondaryName
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        log.createdAt = calendar.date(byAdding: .day, value: dayOffset, to: today)!
        return log
    }

    func testNilFilterReturnsAllLogs() {
        let logs = [log(coreID: "happy"), log(coreID: "sad")]
        XCTAssertEqual(HistoryView.filteredLogs(logs, filter: nil).count, 2)
    }

    func testSecondaryNameFilterStillMatchesBySecondaryName() {
        let logs = [
            log(coreID: "happy", secondaryName: "Hopeful"),
            log(coreID: "sad", secondaryName: "Lonely")
        ]
        XCTAssertEqual(HistoryView.filteredLogs(logs, filter: .secondaryName("Hopeful")).map(\.secondaryName), ["Hopeful"])
    }

    func testCoreIDFilterMatchesByCoreID() {
        let logs = [log(coreID: "happy"), log(coreID: "sad")]
        XCTAssertEqual(HistoryView.filteredLogs(logs, filter: .coreID("happy")).map(\.coreID), ["happy"])
    }

    func testBodyRegionFilterMatchesContainment() {
        let logs = [
            log(coreID: "happy", bodyRegions: [.chest]),
            log(coreID: "sad", bodyRegions: [])
        ]
        XCTAssertEqual(HistoryView.filteredLogs(logs, filter: .bodyRegion(.chest)).count, 1)
    }

    func testWeekdayFilterMatchesCalendarWeekday() {
        let entry = log(coreID: "happy")
        let weekday = Calendar.current.component(.weekday, from: entry.createdAt)
        XCTAssertEqual(HistoryView.filteredLogs([entry], filter: .weekday(weekday)).count, 1)
    }
}
