import XCTest

/// End-to-end coverage for the ThoughtRecord wizard. The 33 unit tests on
/// `ThoughtRecordDraft` and `ThoughtRecord` cover the model layer; this
/// suite covers what they couldn't — the SwiftUI binding plumbing that ties
/// each step view back to the wizard host's state. It exists because a
/// regression in that plumbing (build 30 → 31, iOS 26) shipped to TestFlight:
/// the Confirm step rendered every field empty even after the user typed
/// in each TextField, and Save stayed greyed.
final class ThoughtRecordWizardUITests: XCTestCase {

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

    /// Scroll the Direction tab until the wizard entry point is visible.
    /// The entry point uses the same identifier in both empty ("Start a
    /// record") and populated ("+") states.
    private func scrollToWizardEntry() {
        let entry = app.descendants(matching: .any).matching(identifier: "thought-record.start").firstMatch
        var attempts = 0
        while !entry.exists && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
    }

    private func wizardEntry() -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "thought-record.start").firstMatch
    }

    /// The Continue button identifier is shared across every wizard step.
    /// XCUITest queries return the first hittable match — i.e., the current
    /// step's Continue button — which is what we want.
    private func tapContinue() {
        let button = app.buttons["thought-record.continue"]
        XCTAssertTrue(button.waitForExistence(timeout: 3),
                      "Continue button should be visible")
        button.tap()
    }

    /// The only visible text input on each wizard step is the step's
    /// TextField. `.accessibilityIdentifier` on a SwiftUI TextField doesn't
    /// always reach the underlying UI element's identifier, so we use
    /// `.firstMatch` here instead of the identifier. iOS 26 renders
    /// `TextField(axis: .vertical)` as a `textField` element (not a
    /// `textView` as on earlier versions), so check both.
    private func currentTextInput() -> XCUIElement {
        let textField = app.textFields.firstMatch
        if textField.exists { return textField }
        return app.textViews.firstMatch
    }

    /// Regression test for the iOS 26 binding-propagation bug. Walks every
    /// step of the wizard typing/picking sentinel values, then asserts the
    /// Confirm step renders those values back. If this test fails on
    /// Confirm with empty bodies, the wizard's state plumbing is broken.
    func testWizardCarriesEnteredValuesThroughToConfirm() throws {
        tab("thoughts").tap()
        scrollToWizardEntry()
        XCTAssertTrue(wizardEntry().waitForExistence(timeout: 3),
                      "Thought records area should expose the wizard entry point")
        wizardEntry().tap()

        // Confirm the wizard opened — its first step shows this prompt.
        XCTAssertTrue(app.staticTexts["What was happening?"].waitForExistence(timeout: 5),
                      "Wizard should open to the Situation step")

        // Step 1: Situation (optional). Type a sentinel.
        let situationField = currentTextInput()
        XCTAssertTrue(situationField.waitForExistence(timeout: 3),
                      "Situation TextField should be on screen")
        situationField.tap()
        situationField.typeText("morning standup")
        tapContinue()

        // Step 2: Thought (required). Type a sentinel.
        XCTAssertTrue(app.staticTexts["What thought went through your head?"].waitForExistence(timeout: 3),
                      "Wizard should advance to the Thought step")
        let thoughtField = currentTextInput()
        thoughtField.tap()
        thoughtField.typeText("I'm going to embarrass myself")
        tapContinue()

        // Step 3: Intensity before. Pick 4.
        let intensityBefore = app.buttons["Intensity 4"]
        XCTAssertTrue(intensityBefore.waitForExistence(timeout: 3),
                      "Intensity 4 dot should be tappable")
        intensityBefore.tap()
        tapContinue()

        // Step 4: Patterns (optional). Pick one chip so we can verify in Confirm.
        let pattern = app.descendants(matching: .any)
            .matching(identifier: "pattern.catastrophizing").firstMatch
        if pattern.exists { pattern.tap() }
        tapContinue()

        // Step 5: Balanced view (required). Type a sentinel.
        XCTAssertTrue(app.staticTexts["Is there a different way of looking at it?"].waitForExistence(timeout: 3),
                      "Wizard should advance to the Balanced view step")
        let balancedField = currentTextInput()
        balancedField.tap()
        balancedField.typeText("I've handled standups before")
        tapContinue()

        // Step 6: Intensity after. Pick 2.
        let intensityAfter = app.buttons["Intensity 2"]
        XCTAssertTrue(intensityAfter.waitForExistence(timeout: 3),
                      "Intensity 2 dot should be tappable")
        intensityAfter.tap()
        tapContinue()

        // Confirm step — every sentinel must render.
        let confirmBar = app.navigationBars["Confirm"]
        XCTAssertTrue(confirmBar.waitForExistence(timeout: 3),
                      "Confirm screen should appear after the last Continue")

        let situationCell = app.staticTexts["thought-record.confirm.situation"]
        let thoughtCell = app.staticTexts["thought-record.confirm.thought"]
        let intensityBeforeCell = app.staticTexts["thought-record.confirm.intensity-before"]
        let balancedCell = app.staticTexts["thought-record.confirm.balanced"]
        let intensityAfterCell = app.staticTexts["thought-record.confirm.intensity-after"]

        XCTAssertEqual(situationCell.label, "morning standup",
                       "Situation sentinel should reach Confirm")
        XCTAssertEqual(thoughtCell.label, "I'm going to embarrass myself",
                       "Thought sentinel should reach Confirm")
        XCTAssertEqual(intensityBeforeCell.label, "4 / 5",
                       "Intensity before should reach Confirm")
        XCTAssertEqual(balancedCell.label, "I've handled standups before",
                       "Balanced view sentinel should reach Confirm")
        XCTAssertEqual(intensityAfterCell.label, "2 / 5",
                       "Intensity after should reach Confirm")

        // Save must be enabled now that all required fields are filled.
        let save = app.buttons["thought-record.save"]
        XCTAssertTrue(save.isEnabled,
                      "Save should be enabled once all required fields carry values")
    }
}
