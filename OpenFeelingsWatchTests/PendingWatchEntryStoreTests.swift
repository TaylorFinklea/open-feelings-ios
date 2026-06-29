// OpenFeelingsWatchTests/PendingWatchEntryStoreTests.swift
import XCTest
@testable import OpenFeelingsWatch

final class PendingWatchEntryStoreTests: XCTestCase {
    private func fresh() -> UserDefaults { UserDefaults(suiteName: "pending-watch-\(UUID().uuidString)")! }

    func testStashThenTakeReturnsNoteOnce() {
        let store = PendingWatchEntryStore(defaults: fresh())
        store.stash("anxious about nothing in particular")
        XCTAssertEqual(store.take(), "anxious about nothing in particular")
        XCTAssertNil(store.take())
    }

    func testTakeWhenEmptyIsNil() {
        XCTAssertNil(PendingWatchEntryStore(defaults: fresh()).take())
    }
}
