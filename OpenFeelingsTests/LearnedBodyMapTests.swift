import XCTest
@testable import OpenFeelings

final class LearnedBodyMapTests: XCTestCase {
    private func selection(_ secondary: String) -> EmotionSelection {
        // Use a synthetic selection — we only need `secondary.id` and
        // `core.id` to compute LearnedBodyMap.
        let core = EmotionTaxonomy.cores.first { $0.id == "fearful" }!
        let sec = core.secondaries.first(where: { $0.id == secondary }) ?? core.secondaries[0]
        return EmotionSelection(core: core, secondary: sec, specific: nil)
    }

    private func log(secondary: String, regions: [BodyRegion]) -> FeelingLog {
        let sel = selection(secondary)
        return FeelingLog(
            selection: sel,
            intensity: nil,
            note: "",
            healthSyncStatus: .notRequested,
            bodyRegions: regions,
            bodySensations: [],
            contextPlaces: [],
            contextPeople: [],
            triggers: [],
            coping: [],
            moodEnergy: nil,
            moodValence: nil
        )
    }

    func testEmptyLogsHasNoDominant() {
        let map = LearnedBodyMap.compute(from: [])
        XCTAssertNil(map.dominantSecondary(for: .chest))
    }

    func testDominantBelowSampleThresholdReturnsNil() {
        // Need ≥5 samples. 4 with same secondary should still return nil.
        let logs = (0..<4).map { _ in log(secondary: "anxious", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertNil(map.dominantSecondary(for: .chest))
    }

    func testDominantBelowRatioThresholdReturnsNil() {
        // 5 samples, 50/50 split — neither dominant.
        let logs = (0..<3).map { _ in log(secondary: "anxious", regions: [.chest]) }
                  + (0..<3).map { _ in log(secondary: "worried", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertNil(map.dominantSecondary(for: .chest))
    }

    func testDominantAtThreshold() {
        // 5 samples, 4 anxious (80%) — exceeds 60% and meets sample threshold.
        let logs = (0..<4).map { _ in log(secondary: "anxious", regions: [.chest]) }
                  + (0..<1).map { _ in log(secondary: "worried", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertEqual(map.dominantSecondary(for: .chest), "anxious")
    }

    func testRegionWithoutLogsIsNil() {
        let logs = (0..<5).map { _ in log(secondary: "anxious", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertNil(map.dominantSecondary(for: .hands))
    }

    func testCountAndTotalAreExposed() {
        let logs = (0..<6).map { _ in log(secondary: "anxious", regions: [.chest]) }
                  + (0..<2).map { _ in log(secondary: "worried", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertEqual(map.totals[.chest], 8)
        XCTAssertEqual(map.counts[.chest]?["anxious"], 6)
    }
}
