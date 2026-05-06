import XCTest
@testable import OpenFeelings

final class InsightsDatasetTests: XCTestCase {
    private func log(coreID: String,
                     coreName: String,
                     secondaryID: String,
                     secondaryName: String,
                     daysAgo: Double,
                     now: Date,
                     intensity: Int? = nil,
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
            intensity: intensity,
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

    func testMoodPointCarriesCoreID() {
        let now = Date()
        let logs = [
            log(coreID: "fearful", coreName: "Fearful", secondaryID: "anxious", secondaryName: "Anxious",
                daysAgo: 1, now: now, energy: 0.4, valence: -0.6)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.moodPoints.first?.coreID, "fearful")
    }

    // MARK: - topFeelings carries coreID

    func testTopFeelingsCarriesCoreIDForColorByCore() {
        let now = Date()
        let logs = [
            log(coreID: "fearful", coreName: "Fearful", secondaryID: "anxious", secondaryName: "Anxious", daysAgo: 1, now: now),
            log(coreID: "happy",   coreName: "Happy",   secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 2, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        let anxious = dataset.topFeelings.first { $0.name == "Anxious" }
        XCTAssertEqual(anxious?.coreID, "fearful")
    }

    // MARK: - byCore

    func testByCoreCountsByCoreIDAndCarriesColorHex() {
        let now = Date()
        let logs = [
            log(coreID: "fearful", coreName: "Fearful", secondaryID: "anxious", secondaryName: "Anxious", daysAgo: 1, now: now),
            log(coreID: "fearful", coreName: "Fearful", secondaryID: "anxious", secondaryName: "Anxious", daysAgo: 2, now: now),
            log(coreID: "happy",   coreName: "Happy",   secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 3, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.byCore.first?.coreID, "fearful")
        XCTAssertEqual(dataset.byCore.first?.count, 2)
        XCTAssertFalse(dataset.byCore.first?.colorHex.isEmpty ?? true)
    }

    func testByCoreSortedByCountDescending() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            log(coreID: "sad",   coreName: "Sad",   secondaryID: "lonely",   secondaryName: "Lonely",   daysAgo: 2, now: now),
            log(coreID: "sad",   coreName: "Sad",   secondaryID: "lonely",   secondaryName: "Lonely",   daysAgo: 3, now: now),
            log(coreID: "sad",   coreName: "Sad",   secondaryID: "lonely",   secondaryName: "Lonely",   daysAgo: 4, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.byCore.first?.coreID, "sad")
        XCTAssertEqual(dataset.byCore.last?.coreID, "happy")
    }

    // MARK: - byDayOfWeek

    func testByDayOfWeekHasSevenEntries() {
        let dataset = InsightsDataset.build(logs: [], period: .week, now: Date())
        XCTAssertEqual(dataset.byDayOfWeek.count, 7)
    }

    func testByDayOfWeekZeroFillsMissingDays() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 0, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.byDayOfWeek.count, 7)
        let totalCount = dataset.byDayOfWeek.reduce(0) { $0 + $1.count }
        XCTAssertEqual(totalCount, 1)
    }

    func testByDayOfWeekStartsAtCalendarFirstWeekday() {
        let dataset = InsightsDataset.build(logs: [], period: .week, now: Date())
        XCTAssertEqual(dataset.byDayOfWeek.first?.weekday, Calendar.current.firstWeekday)
    }

    // MARK: - intensityTrend

    func testIntensityTrendAveragesPerDay() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful",
                daysAgo: 0, now: now, intensity: 4),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful",
                daysAgo: 0, now: now, intensity: 2)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .week, now: now)
        let today = dataset.intensityTrend.last
        XCTAssertEqual(today?.avgIntensity, 3.0)
        XCTAssertEqual(today?.logCount, 2)
    }

    func testIntensityTrendNilForDayWithNoIntensities() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful",
                daysAgo: 0, now: now, intensity: nil)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .week, now: now)
        let today = dataset.intensityTrend.last
        XCTAssertNil(today?.avgIntensity)
        XCTAssertEqual(today?.logCount, 1)
    }

    func testIntensityTrendWeekHasSevenDays() {
        let dataset = InsightsDataset.build(logs: [], period: .week, now: Date())
        XCTAssertEqual(dataset.intensityTrend.count, 7)
        XCTAssertTrue(dataset.intensityTrend.allSatisfy { $0.avgIntensity == nil && $0.logCount == 0 })
    }

    // MARK: - previousPeriodCount

    func testPreviousPeriodCountWeek() {
        let now = Date()
        let logs = [
            // Current 7-day window (3 logs):
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 3, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 6, now: now),
            // Prior 7-day window (2 logs):
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 8, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 13, now: now),
            // Outside both windows:
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 30, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .week, now: now)
        XCTAssertEqual(dataset.totalCount, 3)
        XCTAssertEqual(dataset.previousPeriodCount, 2)
    }

    func testPreviousPeriodCountAllReturnsTotal() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 100, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        // .all sentinel: previousPeriodCount == totalCount so the UI delta is 0.
        XCTAssertEqual(dataset.previousPeriodCount, dataset.totalCount)
    }

    // MARK: - currentStreak

    func testCurrentStreakZeroWhenNoLogs() {
        let dataset = InsightsDataset.build(logs: [], period: .all, now: Date())
        XCTAssertEqual(dataset.currentStreak, 0)
    }

    func testCurrentStreakOneForTodayOnly() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 0, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.currentStreak, 1)
    }

    func testCurrentStreakCountsConsecutiveDays() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 0, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 2, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.currentStreak, 3)
    }

    func testCurrentStreakStartsFromYesterdayIfTodayEmpty() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 2, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.currentStreak, 2)
    }

    func testCurrentStreakBreaksOnGap() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 0, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 1, now: now),
            // Gap at daysAgo: 2
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 3, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 4, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.currentStreak, 2)
    }

    func testCurrentStreakZeroWhenTodayAndYesterdayEmpty() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 5, now: now),
            log(coreID: "happy", coreName: "Happy", secondaryID: "peaceful", secondaryName: "Peaceful", daysAgo: 6, now: now)
        ]
        let dataset = InsightsDataset.build(logs: logs, period: .all, now: now)
        XCTAssertEqual(dataset.currentStreak, 0)
    }
}
