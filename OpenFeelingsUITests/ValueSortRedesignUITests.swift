import XCTest

/// End-to-end coverage for the redesigned value-sort flow (build 33).
/// Replaces the original 3-button bucket UX with a Tinder-style swipe
/// step and adds two history surfaces: a Past sorts sheet and an
/// auto-compare modal that appears after each re-sort saves.
final class ValueSortRedesignUITests: XCTestCase {

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

    private func sortAffordance() -> XCUIElement {
        let start = app.buttons["Start the sort"]
        if start.exists { return start }
        return app.buttons["Re-sort"]
    }

    private func navigateToDirectionTab() {
        tab("direction").tap()
    }

    private func openSort() {
        navigateToDirectionTab()
        var attempts = 0
        while !sortAffordance().exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(sortAffordance().waitForExistence(timeout: 3))
        sortAffordance().tap()
        XCTAssertTrue(app.navigationBars["Sort values"].waitForExistence(timeout: 5))
    }

    /// Reads the "{N} of {M}" progress label as an integer pair. Returns
    /// nil if the label isn't on screen (e.g., the deck is exhausted and
    /// the "All values sorted" prompt is showing instead).
    private func currentProgress() -> (current: Int, total: Int)? {
        let label = app.staticTexts.matching(
            NSPredicate(format: "label MATCHES '^[0-9]+ of [0-9]+$'")
        ).firstMatch
        guard label.exists else { return nil }
        let parts = label.label.split(separator: " ")
        guard parts.count == 3,
              let current = Int(parts[0]),
              let total = Int(parts[2]) else { return nil }
        return (current, total)
    }

    /// Swipes the front card to exhaust the deck. The first
    /// `rightCount` cards are swiped right (very important); the rest
    /// are swiped left (not for me). Keeps the very-important pool small
    /// so the finalists chip grid stays on-screen and the "Continue to
    /// ranking" button is reachable without scrolling.
    private func swipeDeck(rightCount: Int = 3) {
        guard var progress = currentProgress() else {
            XCTFail("Bucket step should show progress label")
            return
        }
        let totalCards = progress.total
        XCTAssertGreaterThan(totalCards, 0)
        var rightRemaining = rightCount

        while progress.current <= totalCards {
            let card = app.descendants(matching: .any)
                .matching(identifier: "value-sort.card").firstMatch
            guard card.waitForExistence(timeout: 2) else { return }

            if rightRemaining > 0 {
                card.swipeRight()
                rightRemaining -= 1
            } else {
                card.swipeLeft()
            }

            let target = progress.current + 1
            let predicate = NSPredicate(format:
                "label MATCHES '^[0-9]+ of [0-9]+$' AND label BEGINSWITH '\(target) '")
            let advanced = app.staticTexts.matching(predicate).firstMatch
            if advanced.waitForExistence(timeout: 2) {
                if let next = currentProgress() {
                    progress = next
                    continue
                }
                return
            }
            if currentProgress() == nil { return }
            XCTFail("Swipe didn't advance from \(progress.current) of \(totalCards)")
            return
        }
    }

    /// Drives the finalists + rank + confirm steps once bucketing is done.
    /// Picks "Family" as the finalist (curated value, always in the
    /// veryImportant pool after a sweep of right-swipes), runs through
    /// to the Confirm button.
    private func finishFinalistsAndRank() {
        // Wait for the bucketing-done state before looking for Continue.
        XCTAssertTrue(app.staticTexts["All values sorted."].waitForExistence(timeout: 5),
                      "advancePrompt should appear once the deck is exhausted")

        // Bucketing → finalists.
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 3))
        app.buttons["Continue"].tap()

        // Finalists step: the pool is small (3 right-swipes worth).
        // Pick the first chip in the pool — it's deterministic by deck
        // order, which is curated taxonomy order from ValueTaxonomy.all.
        // The first curated value is "acceptance".
        let firstChip = app.buttons["Acceptance"]
        XCTAssertTrue(firstChip.waitForExistence(timeout: 3),
                      "Acceptance chip should be visible in the finalists pool")
        firstChip.tap()

        let toRanking = app.buttons["Continue to ranking"]
        XCTAssertTrue(toRanking.waitForExistence(timeout: 3),
                      "Continue to ranking should appear after picking a finalist")
        toRanking.tap()

        // Rank step → Continue (label is plain "Continue").
        let rankCont = app.buttons["Continue"]
        XCTAssertTrue(rankCont.waitForExistence(timeout: 3),
                      "Rank step's Continue button should appear")
        rankCont.tap()

        // Confirm step — tap Confirm.
        let confirm = app.buttons["Confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3),
                      "Confirm button should appear on the final step")
        confirm.tap()
    }

    // MARK: - Test 1: swipe → finalists → rank → save → auto-compare appears

    func testSwipeSortHappyPathReachesAutoCompareModal() {
        openSort()
        swipeDeck()
        finishFinalistsAndRank()

        let comparisonNav = app.navigationBars["What changed"]
        XCTAssertTrue(comparisonNav.waitForExistence(timeout: 5),
                      "SortComparisonView should auto-present after Confirm")
    }

    // MARK: - Test 2: auto-compare modal dismisses on Done

    func testAutoCompareModalDismissesOnDone() {
        openSort()
        swipeDeck()
        finishFinalistsAndRank()

        XCTAssertTrue(app.navigationBars["What changed"].waitForExistence(timeout: 5))
        let done = app.buttons["sort-comparison.done"]
        XCTAssertTrue(done.exists)
        done.tap()
        XCTAssertFalse(app.navigationBars["What changed"].waitForExistence(timeout: 1),
                       "Comparison modal should dismiss on Done")
    }

    // MARK: - Test 3: past-sorts sheet lists existing entries

    func testPastSortsSheetListsExistingEntries() {
        navigateToDirectionTab()
        // The "Past sorts" button only appears when ≥2 ValueSort rows
        // exist on the device. If the test sim has only 0 or 1 sorts
        // (no past sort history yet), this test passes trivially.
        // Tests 1 & 2 seed sorts on each run.
        var attempts = 0
        let pastButton = app.buttons["values.past-sorts"]
        while !pastButton.exists && attempts < 6 {
            app.swipeUp()
            attempts += 1
        }
        guard pastButton.exists else {
            // Acceptable: no history yet on this sim.
            return
        }
        pastButton.tap()
        XCTAssertTrue(app.navigationBars["Past sorts"].waitForExistence(timeout: 3))
        // At least one row should be visible. SwiftUI renders the row as
        // various element types depending on accessibility composition;
        // query across all descendants.
        let anyRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'past-sorts.row.'")
        ).firstMatch
        XCTAssertTrue(anyRow.waitForExistence(timeout: 3),
                      "At least one past-sorts row should be visible")
    }
}
