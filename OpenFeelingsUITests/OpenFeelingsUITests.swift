import XCTest

/// Smoke tests for the iOS 26 Liquid Glass tab bar. The Liquid Glass tab
/// items aren't reachable via `app.tabBars.buttons[...]` on iOS 26 — they
/// expose as `_UIFloatingTabBarItemCell` — so we look them up by the
/// explicit `accessibilityIdentifier` we added on each `Label` in
/// `RootView` (e.g. "tab.today", "tab.settings").
final class OpenFeelingsUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingMode", "1"]
        app.launch()
    }

    private func tab(_ name: String) -> XCUIElement {
        // Search across all element types — the Liquid Glass tab cell isn't
        // a button or a tab bar item in the XCUITest hierarchy.
        app.descendants(matching: .any).matching(identifier: "tab.\(name)").firstMatch
    }

    // MARK: - Cold launch

    func testColdLaunchTabsAreReachable() {
        XCTAssertTrue(tab("today").waitForExistence(timeout: 5),
                      "Today tab identifier should be reachable on cold launch")
        XCTAssertTrue(tab("checkIn").exists)
        XCTAssertTrue(tab("insights").exists)
        XCTAssertTrue(tab("intentions").exists)
        XCTAssertTrue(tab("settings").exists)
    }

    // MARK: - Tab switching

    func testTabSwitchingShowsEachTabsContent() {
        // Settings has the most stable static text on a fresh launch.
        tab("settings").tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 3),
                      "Settings tab should show its navigation title")

        // Intentions tab on a fresh launch shows the empty hero with a
        // recognizable "Intention" display title.
        tab("intentions").tap()
        XCTAssertTrue(app.staticTexts["Intention"].waitForExistence(timeout: 3),
                      "Intentions tab should show its hero title")

        // Insights tab shows the "Patterns" header (or an empty-state
        // title when there are no logs).
        tab("insights").tap()
        let patternsHeader = app.staticTexts.matching(NSPredicate(format:
            "label CONTAINS[c] 'Patterns' OR label CONTAINS[c] 'No patterns'"))
        XCTAssertTrue(patternsHeader.firstMatch.waitForExistence(timeout: 3),
                      "Insights tab should show patterns or an empty state")

        // Return to Today.
        tab("today").tap()
        XCTAssertTrue(tab("today").exists, "Today tab still selectable after navigation")
    }

    // MARK: - Check In wizard

    func testCheckInTabRendersWizardFirstStep() {
        tab("checkIn").tap()
        // Wizard shows a "Step X of Y" header and a "Continue" or
        // "Save check-in" primary button — both come from StepHeader /
        // StepNav. Look for either, since the step count depends on
        // user settings (default minimum is 1).
        let stepHeader = app.staticTexts.matching(NSPredicate(format:
            "label BEGINSWITH 'Step '"))
        let continueButton = app.buttons["Continue"]
        let saveButton = app.buttons["Save check-in"]
        let anyWizardElement = stepHeader.firstMatch.exists
            || continueButton.exists
            || saveButton.exists
        // Give the view up to 3 seconds to settle after the tab tap.
        if !anyWizardElement {
            _ = stepHeader.firstMatch.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(stepHeader.firstMatch.exists
                      || continueButton.exists
                      || saveButton.exists,
                      "Check In tab should render the wizard's first step")
    }

    // MARK: - Settings exports surface

    func testSettingsExposesPeriodSummaryRow() {
        tab("settings").tap()
        let row = app.staticTexts["Period summary for therapist"]
        // The row may be below the fold on smaller devices; scroll until found.
        let scrollView = app.scrollViews.firstMatch
        var attempts = 0
        while !row.exists && attempts < 8 {
            scrollView.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(row.exists, "Settings should surface the therapy export row")
    }
}
