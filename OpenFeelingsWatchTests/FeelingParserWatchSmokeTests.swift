// OpenFeelingsWatchTests/FeelingParserWatchSmokeTests.swift
import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class FeelingParserWatchSmokeTests: XCTestCase {
    func testParserResolvesOnWatch() async {
        let parsed = await FeelingParserProvider.current().parse("really anxious about the demo")
        XCTAssertEqual(parsed.core?.name, "Fearful")
        XCTAssertEqual(parsed.secondary?.name, "Anxious")
        XCTAssertEqual(parsed.intensity, 4)   // "really" → 4
        XCTAssertEqual(parsed.confidence, .high)
    }
}
