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

    func testTabOrderIsTodayCheckInInsightsIntentionsSettings() {
        XCTAssertEqual(AppTab.allCases,
                       [.today, .checkIn, .insights, .intentions, .settings])
    }
}
