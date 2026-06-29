// OpenFeelingsWatchTests/WatchCheckInIntentTests.swift
import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class WatchCheckInIntentTests: XCTestCase {
    func testHighConfidenceBuildsSendPayload() async {
        let outcome = await WatchCheckInIntent.run(phrase: "anxious 4 out of 5")
        guard case let .send(payload, spoken) = outcome else { return XCTFail("expected .send, got \(outcome)") }
        XCTAssertEqual(payload.coreName, "Fearful")
        XCTAssertEqual(payload.secondaryName, "Anxious")
        XCTAssertEqual(payload.intensity, 4)
        XCTAssertTrue(spoken.contains("Anxious"))
    }

    func testNoneStashesAndHandsOff() async {
        let defaults = UserDefaults(suiteName: "watch-intent-\(UUID().uuidString)")!
        let outcome = await WatchCheckInIntent.run(phrase: "zzzz qqqq",
                                                   pending: PendingWatchEntryStore(defaults: defaults))
        guard case .handOff = outcome else { return XCTFail("expected .handOff, got \(outcome)") }
        XCTAssertEqual(PendingWatchEntryStore(defaults: defaults).take(), "zzzz qqqq")
    }
}
