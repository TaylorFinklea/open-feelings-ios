import XCTest

/// UI smoke tests for the Direction tab and Values sort flow. Like the
/// rest of OpenFeelingsUITests, these run against the simulator's
/// persistent SwiftData store — they're written defensively so they
/// pass whether or not prior runs left logs, intentions, or a saved
/// ValueSort behind.
final class DirectionUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingMode", "1"]
        app.launch()
    }

    private func tab(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "tab.\(name)").firstMatch
    }

    /// Intentions ↔ Values segmented toggle button, by identifier.
    private func segment(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "direction.segment.\(name)").firstMatch
    }

    /// The Direction tab opens on Intentions; the Values area only renders once
    /// its segment is selected. Sort-flow tests call this first.
    private func showValues() {
        let values = segment("Values")
        XCTAssertTrue(values.waitForExistence(timeout: 3),
                      "Direction tab should expose a Values segment")
        values.tap()
    }

    /// "Start the sort" appears in the empty-state card; "Re-sort" appears
    /// once a ValueSort exists. Both lead to SortFlowView.
    private func sortAffordance() -> XCUIElement {
        let start = app.buttons["Start the sort"]
        if start.exists { return start }
        return app.buttons["Re-sort"]
    }

    // MARK: - Segmented toggle

    func testDirectionSegmentTogglesToValues() {
        tab("direction").tap()

        XCTAssertTrue(segment("Intentions").waitForExistence(timeout: 3),
                      "Direction tab should expose an Intentions segment")
        XCTAssertTrue(segment("Values").exists,
                      "Direction tab should expose a Values segment")

        // Defaults to Intentions, so the Values sort affordance is not present.
        XCTAssertFalse(sortAffordance().exists,
                       "Values content should be hidden while Intentions is selected")

        // Switching to Values reveals the Values area's sort affordance.
        segment("Values").tap()
        var attempts = 0
        while !sortAffordance().exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(sortAffordance().exists,
                      "Selecting the Values segment should reveal the Values area")
    }

    // MARK: - Sort affordance

    func testValuesAreaExposesSortAffordance() {
        tab("direction").tap()
        showValues()

        // Scroll to bring the ValuesArea into view if needed.
        var attempts = 0
        while !sortAffordance().exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }

        XCTAssertTrue(sortAffordance().exists,
                      "Values area should expose either 'Start the sort' or 'Re-sort'")
    }

    // MARK: - Sort flow modal

    func testSortFlowOpensSwipeStep() {
        tab("direction").tap()
        showValues()

        var attempts = 0
        while !sortAffordance().exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(sortAffordance().waitForExistence(timeout: 3))
        sortAffordance().tap()

        // SortFlowView mounts a NavigationStack with title "Sort values".
        XCTAssertTrue(app.navigationBars["Sort values"].waitForExistence(timeout: 5),
                      "Sort flow should open with Sort values navigation title")

        // Bucket step exposes a swipe card (build 33+).
        let card = app.descendants(matching: .any)
            .matching(identifier: "value-sort.card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3),
                      "Bucket step should expose a swipe card")
    }

    // MARK: - Bucket progress + undo

    /// Locates the "{N} of {M}" progress text. Stable across deck sizes.
    private func progressText() -> XCUIElement {
        app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '^[0-9]+ of [0-9]+$'")
        ).firstMatch
    }

    private func progressIndex() -> Int? {
        let label = progressText().label
        return Int(label.split(separator: " ").first.map(String.init) ?? "")
    }

    func testBucketAdvancesProgressAndUndoRestoresIt() {
        tab("direction").tap()
        showValues()

        var attempts = 0
        while !sortAffordance().exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(sortAffordance().waitForExistence(timeout: 3))
        sortAffordance().tap()

        XCTAssertTrue(progressText().waitForExistence(timeout: 5),
                      "Bucket step should render '{N} of {M}' progress text")
        guard let before = progressIndex() else {
            return XCTFail("Could not parse initial bucket progress index")
        }

        let card = app.descendants(matching: .any)
            .matching(identifier: "value-sort.card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 3),
                      "Swipe card should be visible to bucket the first value")
        card.swipeRight()

        // The card advances and the progress text re-renders with index+1.
        // Re-query the progress text in case the previous element invalidated.
        let advancedPredicate = NSPredicate(format:
            "label MATCHES '^[0-9]+ of [0-9]+$' AND label BEGINSWITH '\(before + 1) '")
        let advanced = app.staticTexts.matching(advancedPredicate).firstMatch
        XCTAssertTrue(advanced.waitForExistence(timeout: 3),
                      "Progress should advance from \(before) to \(before + 1) after bucketing")

        // Undo restores the prior index.
        XCTAssertTrue(app.buttons["Undo"].exists,
                      "Undo affordance should appear after bucketing the first card")
        app.buttons["Undo"].tap()

        let restoredPredicate = NSPredicate(format:
            "label MATCHES '^[0-9]+ of [0-9]+$' AND label BEGINSWITH '\(before) '")
        let restored = app.staticTexts.matching(restoredPredicate).firstMatch
        XCTAssertTrue(restored.waitForExistence(timeout: 3),
                      "Undo should restore progress back to \(before)")
    }

    // MARK: - Cancel

    func testSortFlowCancelDismissesModal() {
        tab("direction").tap()
        showValues()

        var attempts = 0
        while !sortAffordance().exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(sortAffordance().waitForExistence(timeout: 3))
        sortAffordance().tap()

        let bar = app.navigationBars["Sort values"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5))
        bar.buttons["Cancel"].tap()

        XCTAssertFalse(bar.waitForExistence(timeout: 1),
                       "Sort flow should dismiss after Cancel")
        XCTAssertTrue(tab("direction").exists,
                      "Direction tab should still be selectable after dismissing sort flow")
    }
}
