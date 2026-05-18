import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class WatchSettingsStoreTests: XCTestCase {

    func testInitializesWithDefaultSettings() {
        let store = WatchSettingsStore()
        XCTAssertEqual(store.settings, WatchCheckInSettings.default)
        XCTAssertEqual(store.settings.bodyFirst, true)
        XCTAssertEqual(store.settings.sensationsPromoted, false)
    }

    func testUpdateReplacesSettings() {
        let store = WatchSettingsStore()
        let new = WatchCheckInSettings(bodyFirst: false, sensationsPromoted: true)
        store.update(new)
        XCTAssertEqual(store.settings, new)
        XCTAssertEqual(store.settings.bodyFirst, false)
        XCTAssertEqual(store.settings.sensationsPromoted, true)
    }

    func testUpdateIsIdempotent() {
        let store = WatchSettingsStore()
        let new = WatchCheckInSettings(bodyFirst: false, sensationsPromoted: false)
        store.update(new)
        store.update(new)
        XCTAssertEqual(store.settings, new)
    }
}
