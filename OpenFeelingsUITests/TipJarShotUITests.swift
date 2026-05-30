import XCTest

/// Captures a review screenshot of the tip jar (Support section) for the
/// three consumable IAPs. Live StoreKit products only vend once the IAPs are
/// "Ready to Submit" in App Store Connect, and `xcodebuild test` doesn't
/// reliably apply a StoreKit testing config — so `-tipJarDemo` renders the
/// real tiers (names/prices match App Store Connect) from static data.
///
///   xcodebuild test -scheme OpenFeelings \
///     -only-testing:OpenFeelingsUITests/TipJarShotUITests \
///     -destination 'id=<sim-udid>' -resultBundlePath build/Shots-tipjar.xcresult
final class TipJarShotUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-screenshotMode", "-tipJarDemo"]
        app.launch()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The first tier ("Soda") is on-screen (not merely present in the
    /// hierarchy). `.isHittable` — unlike `.exists` — is only true once the
    /// element is actually visible, so it's a reliable "scrolled far enough"
    /// signal.
    private func tipOnScreen() -> Bool {
        let fmt = "label CONTAINS[c] 'Soda'"
        return app.staticTexts.containing(NSPredicate(format: fmt)).firstMatch.isHittable
            || app.buttons.containing(NSPredicate(format: fmt)).firstMatch.isHittable
    }

    func testCaptureTipJar() {
        app.buttons["settings.gear"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 10),
                      "Settings modal should appear")

        // The Support section sits near the bottom of Settings. Scroll until
        // the tiers are actually on-screen (or we hit the scroll limit).
        for _ in 0..<8 {
            if tipOnScreen() { break }
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        Thread.sleep(forTimeInterval: 1.0)
        snap("IAP-TipJar")

        XCTAssertTrue(tipOnScreen(), "Tip tiers should be visible after scrolling.")
    }
}
