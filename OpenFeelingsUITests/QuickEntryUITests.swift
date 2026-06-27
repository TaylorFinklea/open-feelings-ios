// OpenFeelingsUITests/QuickEntryUITests.swift
import XCTest

final class QuickEntryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingMode", "1"]
        app.launch()
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testQuickEntryCaptureToReviewToSave() {
        let button = el("today.quickEntry")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        let field = el("quickentry.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("really anxious about the demo")

        el("quickentry.continue").tap()

        let save = el("quickentry.save")
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        // Lands back on Today; the saved ribbon or the new entry is visible.
        XCTAssertTrue(el("today.quickEntry").waitForExistence(timeout: 5))
    }
}
