import XCTest

/// Captures App Store screenshots of the key surfaces against a curated,
/// privacy-safe demo dataset (seeded by `-screenshotMode`; see
/// `ScreenshotDemoSeeder`). Run on the required device sims and export the
/// attachments:
///
///   xcodebuild test -scheme OpenFeelings \
///     -only-testing:OpenFeelingsUITests/ScreenshotTourUITests \
///     -destination 'id=<sim-udid>' -resultBundlePath build/Shots-<device>.xcresult
///   xcrun xcresulttool export attachments \
///     --path build/Shots-<device>.xcresult --output-path build/shots-<device>
///
/// Not an assertion test — it navigates and snapshots. It only fails if a
/// surface never appears (which would mean a real navigation regression).
///
/// Launches in **Wheel** mode so the Check-In tab opens on the feelings wheel
/// — the app's hero surface and the first thing the App Store description
/// describes. The guided wizard is captured too by tapping the in-step pill.
final class ScreenshotTourUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-screenshotMode",        // in-memory store + curated demo data
            "-checkInBodyFirst", "0", // open the check-in on the Feeling step
            "-checkInMode", "Wheel",  // Feeling step renders the full feelings wheel
        ]
        app.launch()
    }

    private func tab(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "tab.\(name)").firstMatch
    }

    private func segment(_ name: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "direction.segment.\(name)").firstMatch
    }

    /// Capture the current screen at native device resolution as a kept attachment.
    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Brief settle so chart/segment animations finish before the snapshot.
    private func settle() { Thread.sleep(forTimeInterval: 1.2) }

    func testCaptureScreenshotTour() {
        // 1. Check-In — the feelings wheel (hero). Opens directly on the
        //    Feeling step in Wheel mode.
        tab("checkIn").tap()
        XCTAssertTrue(app.staticTexts["Tap the wheel"].waitForExistence(timeout: 10),
                      "Wheel mode 'Tap the wheel' header should appear")
        settle()
        snap("01-Wheel")

        // 2. Today — greeting + recent check-ins.
        tab("today").tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Good '")).firstMatch
                .waitForExistence(timeout: 10),
            "Today greeting should appear")
        settle()
        snap("02-Today")

        // 3. Insights — populated charts (week).
        tab("insights").tap()
        XCTAssertTrue(app.staticTexts["Patterns"].waitForExistence(timeout: 10),
                      "Insights 'Patterns' header should appear")
        settle()
        snap("03-Insights")

        // 4. Direction — Intentions (the wash card + look-back).
        tab("direction").tap()
        XCTAssertTrue(segment("Intentions").waitForExistence(timeout: 10),
                      "Direction Intentions segment should appear")
        settle()
        snap("05-Direction-Intentions")

        // 5. Direction — Values (ranked values + committed actions).
        segment("Values").tap()
        settle()
        snap("06-Direction-Values")

        // 6. Thoughts — CBT thought records list.
        tab("thoughts").tap()
        settle()
        snap("07-Thoughts")

        // 7. Settings — the modal the design centers on.
        app.buttons["settings.gear"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10),
                      "Settings modal should appear")
        settle()
        snap("08-Settings")

        // 8. Check-In — the guided one-emotion-per-row wizard (the gentle
        //    alternative to the wheel). Relaunch in Wizard mode rather than
        //    toggling the in-step pill (which XCUITest can't reliably hit).
        app.launchArguments = [
            "-screenshotMode",
            "-checkInBodyFirst", "0",
            "-checkInMode", "Wizard",
        ]
        app.launch()
        tab("checkIn").tap()
        XCTAssertTrue(
            app.descendants(matching: .any).matching(identifier: "emotion.Happy").firstMatch
                .waitForExistence(timeout: 10),
            "Wizard 'Happy' row should appear")
        settle()
        snap("04-CheckIn-Wizard")
    }
}
