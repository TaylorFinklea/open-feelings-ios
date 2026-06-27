// OpenFeelingsTests/PendingQuickEntryStoreTests.swift
import XCTest
@testable import OpenFeelings

final class PendingQuickEntryStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "pending-test-\(UUID().uuidString)")!
        return d
    }

    func testStashThenTakeReturnsNoteOnce() {
        let store = PendingQuickEntryStore(defaults: freshDefaults())
        store.stash("anxious about nothing in particular")
        XCTAssertEqual(store.take(), "anxious about nothing in particular")
        XCTAssertNil(store.take(), "take() must clear after reading")
    }

    func testTakeWhenEmptyIsNil() {
        XCTAssertNil(PendingQuickEntryStore(defaults: freshDefaults()).take())
    }
}
