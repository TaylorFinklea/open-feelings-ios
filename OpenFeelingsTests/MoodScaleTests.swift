import XCTest
@testable import OpenFeelings

final class MoodScaleTests: XCTestCase {
    func testEnergyBandCalm() {
        XCTAssertEqual(MoodScale.energyBand(-1.0), "calm")
        XCTAssertEqual(MoodScale.energyBand(-0.5), "calm")
        XCTAssertEqual(MoodScale.energyBand(-0.34), "calm")
    }

    func testEnergyBandBalanced() {
        XCTAssertEqual(MoodScale.energyBand(-0.33), "balanced")
        XCTAssertEqual(MoodScale.energyBand(0), "balanced")
        XCTAssertEqual(MoodScale.energyBand(0.33), "balanced")
    }

    func testEnergyBandActivated() {
        XCTAssertEqual(MoodScale.energyBand(0.34), "activated")
        XCTAssertEqual(MoodScale.energyBand(0.7), "activated")
        XCTAssertEqual(MoodScale.energyBand(1.0), "activated")
    }

    func testValenceBandUnpleasant() {
        XCTAssertEqual(MoodScale.valenceBand(-1.0), "unpleasant")
        XCTAssertEqual(MoodScale.valenceBand(-0.5), "unpleasant")
        XCTAssertEqual(MoodScale.valenceBand(-0.34), "unpleasant")
    }

    func testValenceBandNeutral() {
        XCTAssertEqual(MoodScale.valenceBand(-0.33), "neutral")
        XCTAssertEqual(MoodScale.valenceBand(0), "neutral")
        XCTAssertEqual(MoodScale.valenceBand(0.33), "neutral")
    }

    func testValenceBandPleasant() {
        XCTAssertEqual(MoodScale.valenceBand(0.34), "pleasant")
        XCTAssertEqual(MoodScale.valenceBand(0.7), "pleasant")
        XCTAssertEqual(MoodScale.valenceBand(1.0), "pleasant")
    }

    func testBoundariesIncludedInMiddleBand() {
        // The thresholds -0.33 and 0.33 should fall inside the middle band, not the outer bands.
        XCTAssertEqual(MoodScale.energyBand(-0.33), "balanced")
        XCTAssertEqual(MoodScale.energyBand(0.33), "balanced")
        XCTAssertEqual(MoodScale.valenceBand(-0.33), "neutral")
        XCTAssertEqual(MoodScale.valenceBand(0.33), "neutral")
    }
}
