import XCTest
@testable import OpenFeelings

@MainActor
final class AppNavigationTests: XCTestCase {
    func testDefaultTabIsToday() {
        let nav = AppNavigation()
        XCTAssertEqual(nav.selectedTab, .today)
    }

    func testSelectChanges() {
        let nav = AppNavigation()
        nav.select(.checkIn)
        XCTAssertEqual(nav.selectedTab, .checkIn)
    }

    func testAllTabsHaveTitleAndSymbol() {
        for tab in AppTab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
            XCTAssertFalse(tab.systemImage.isEmpty)
        }
    }

    func testTabOrderIsTodayCheckInDirectionThoughtsInsights() {
        XCTAssertEqual(AppTab.allCases,
                       [.today, .checkIn, .direction, .thoughts, .insights])
    }

    // MARK: - Drill-down

    func testDrillIntoHistorySetsFilterSelectsTodayAndPushesRoute() {
        let nav = AppNavigation()
        nav.selectedTab = .insights

        nav.drillIntoHistory(filter: .secondaryName("Anxious"))

        XCTAssertEqual(nav.historyFilter, .secondaryName("Anxious"))
        XCTAssertEqual(nav.selectedTab, .today)
        XCTAssertEqual(nav.todayPath, [.full])
    }

    func testDrillIntoHistoryDoesNotDuplicateRouteIfAlreadyOnHistory() {
        let nav = AppNavigation()
        nav.todayPath = [.full]   // user already deep on History

        nav.drillIntoHistory(filter: .secondaryName("Hopeful"))

        XCTAssertEqual(nav.todayPath, [.full],
                       "Path should not duplicate when .full is already on the stack")
        XCTAssertEqual(nav.historyFilter, .secondaryName("Hopeful"))
    }

    func testClearHistoryFilterResetsFilterButLeavesPath() {
        let nav = AppNavigation()
        nav.drillIntoHistory(filter: .secondaryName("Anxious"))

        nav.clearHistoryFilter()

        XCTAssertNil(nav.historyFilter)
        XCTAssertEqual(nav.todayPath, [.full],
                       "Clearing the filter should not pop the user out of History")
    }

    func testHistoryFilterDisplayLabelMatchesSecondaryName() {
        XCTAssertEqual(HistoryFilter.secondaryName("Anxious").displayLabel, "Anxious")
    }

    func testHistoryFilterCoreIDDisplayLabelResolvesCoreName() {
        XCTAssertEqual(HistoryFilter.coreID("happy").displayLabel, "Happy")
        XCTAssertEqual(HistoryFilter.coreID("sad").displayLabel, "Sad")
    }

    func testHistoryFilterCoreIDFallsBackToRawIDWhenUnknown() {
        XCTAssertEqual(HistoryFilter.coreID("not-a-core").displayLabel, "not-a-core")
    }

    func testHistoryFilterBodyRegionDisplayLabelMatchesEnumDisplayName() {
        let region = BodyRegion.allCases.first { $0 != .wholeBody && $0 != .nowhere }!
        XCTAssertEqual(HistoryFilter.bodyRegion(region).displayLabel, region.displayName)
    }

    func testHistoryFilterWeekdayDisplayLabelIsAShortSymbol() {
        let symbols = Calendar.current.shortWeekdaySymbols
        for weekday in 1...7 {
            XCTAssertEqual(HistoryFilter.weekday(weekday).displayLabel, symbols[weekday - 1])
        }
    }

    func testHistoryFilterEqualityIsCaseAware() {
        XCTAssertNotEqual(HistoryFilter.secondaryName("Anxious"),
                          HistoryFilter.coreID("Anxious"))
    }
}
