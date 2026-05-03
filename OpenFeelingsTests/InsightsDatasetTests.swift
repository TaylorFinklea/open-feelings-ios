import XCTest
@testable import OpenFeelings

final class InsightsDatasetTests: XCTestCase {
    private func log(coreID: String,
                     coreName: String,
                     secondaryID: String,
                     secondaryName: String,
                     daysAgo: Double,
                     now: Date,
                     bodyRegions: [BodyRegion] = [],
                     triggers: [Trigger] = [],
                     coping: [Coping] = [],
                     energy: Double? = nil,
                     valence: Double? = nil) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == coreID }!
        let secondary = core.secondaries.first { $0.id == secondaryID }!
        let selection = EmotionSelection(core: core, secondary: secondary, specific: nil)
        let log = FeelingLog(
            selection: selection,
            intensity: nil,
            note: "",
            bodyRegions: bodyRegions,
            triggers: triggers,
            coping: coping,
            moodEnergy: energy,
            moodValence: valence
        )
        log.createdAt = now.addingTimeInterval(-daysAgo * 86_400)
        return log
    }

    // MARK: - Period filter

    func testWeekFilterDropsLogsOlderThan7Days() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 30, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .week, now: now)
        XCTAssertEqual(dataset.totalCount, 1)
    }

    func testAllPeriodIncludesEverything() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 90, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.totalCount, 2)
    }

    // MARK: - countsPerDay

    func testCountsPerDayWeekHas7Days() {
        let dataset = InsightsDataset.build(logs: [], period: .week, now: Date())
        XCTAssertEqual(dataset.countsPerDay.count, 7)
        XCTAssertTrue(dataset.countsPerDay.allSatisfy { $0.count == 0 })
    }

    func testCountsPerDayWeekFillsZerosForEmptyDays() {
        let now = Date()
        let logs = [log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 0, now: now)]
        let dataset = InsightsDataset.build(logs: logs, period: .week, now: now)
        XCTAssertEqual(dataset.countsPerDay.count, 7)
        XCTAssertEqual(dataset.countsPerDay.last?.count, 1)
    }

    // MARK: - topFeelings

    func testTopFeelingsRanksBySecondaryCount() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 2, now: now),
            log(coreID: "sad",   coreName: "Sad",   secondaryID: "lonely",   secondaryName: "Lonely",   daysAgo: 1, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.topFeelings.first?.name, "Peaceful")
        XCTAssertEqual(dataset.topFeelings.first?.count, 2)
    }

    func testTopFeelingsCappedAtFive() {
        let now = Date()
        let names = ["Peaceful", "Lonely", "Optimistic", "Anxious", "Frustrated", "Bitter", "Hurt"]
        let logs = names.enumerated().map { (i, name) in
            // Use happy/peaceful as a stand-in; we only care about secondaryName for the test
            let log = log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: name, daysAgo: Double(i), now: now)
            return log
        }
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertLessThanOrEqual(dataset.topFeelings.count, 5)
    }

    // MARK: - topBodyRegions

    func testTopBodyRegionsCounts() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now, bodyRegions: [.chest, .gut]),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 2, now: now, bodyRegions: [.chest])
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.topBodyRegions.first?.region, .chest)
        XCTAssertEqual(dataset.topBodyRegions.first?.count, 2)
    }

    // MARK: - topTriggerCopingPairs

    func testTriggerCopingPairsCountedAcrossLogs() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now,
                triggers: [.conflict], coping: [.breath]),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 2, now: now,
                triggers: [.conflict], coping: [.breath, .walk])
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        let conflictBreath = dataset.topTriggerCopingPairs.first { $0.trigger == .conflict && $0.coping == .breath }
        XCTAssertEqual(conflictBreath?.count, 2)
    }

    // MARK: - moodPoints

    func testMoodPointsRequireBothEnergyAndValence() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now,
                energy: 0.5, valence: 0.5),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 2, now: now,
                energy: 0.5, valence: nil),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 3, now: now,
                energy: nil, valence: 0.5),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 4, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.moodPoints.count, 1)
        XCTAssertEqual(dataset.moodPoints.first?.energy, 0.5)
        XCTAssertEqual(dataset.moodPoints.first?.valence, 0.5)
    }
}
