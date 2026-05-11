import XCTest
@testable import OpenFeelings

final class InsightsSummaryTests: XCTestCase {
    func testCheckInCountPhraseSingularAndPlural() {
        XCTAssertEqual(checkInCountPhrase(0), "no check-ins")
        XCTAssertEqual(checkInCountPhrase(1), "1 check-in")
        XCTAssertEqual(checkInCountPhrase(5), "5 check-ins")
    }

    func testCheckInsPerDayMentionsTotalAndDayCount() {
        let summary = InsightsSummary.checkInsPerDay(totalCount: 3, dayCount: 7)
        XCTAssertTrue(summary.contains("3 check-ins"))
        XCTAssertTrue(summary.contains("7 days"))
    }

    func testCheckInsPerDaySingularDay() {
        let summary = InsightsSummary.checkInsPerDay(totalCount: 1, dayCount: 1)
        XCTAssertTrue(summary.contains("1 day"))
        XCTAssertFalse(summary.contains("1 days"))
    }

    func testByCoreEmptyReturnsNoDataString() {
        XCTAssertEqual(InsightsSummary.byCore([]), "By core chart, no data")
    }

    func testByCoreReportsTopCoreNameAndCount() {
        let entries = [
            InsightsDataset.CoreCount(coreID: "happy", coreName: "Happy", colorHex: "F4D03F", count: 5),
            InsightsDataset.CoreCount(coreID: "sad", coreName: "Sad", colorHex: "3498DB", count: 2),
        ]

        let summary = InsightsSummary.byCore(entries)

        XCTAssertTrue(summary.contains("Happy"))
        XCTAssertTrue(summary.contains("5 check-ins"))
    }

    func testTopFeelingsEmptyReturnsNoDataString() {
        XCTAssertEqual(InsightsSummary.topFeelings([]), "Top feelings chart, no data")
    }

    func testTopFeelingsReportsTopName() {
        let entries = [
            InsightsDataset.FeelingCount(name: "Hopeful", coreID: "happy", count: 3),
            InsightsDataset.FeelingCount(name: "Lonely", coreID: "sad", count: 1),
        ]

        let summary = InsightsSummary.topFeelings(entries)

        XCTAssertTrue(summary.contains("Hopeful"))
        XCTAssertTrue(summary.contains("3 check-ins"))
    }

    func testByDayOfWeekAllZeroReturnsNoDataString() {
        let symbols = Calendar.current.shortWeekdaySymbols
        let entries = (1...7).map {
            InsightsDataset.DOWCount(weekday: $0, label: symbols[$0 - 1], count: 0)
        }

        XCTAssertEqual(InsightsSummary.byDayOfWeek(entries), "By day of week chart, no data")
    }

    func testByDayOfWeekReportsBusiestDay() {
        let symbols = Calendar.current.shortWeekdaySymbols
        let entries = (1...7).map {
            InsightsDataset.DOWCount(weekday: $0, label: symbols[$0 - 1], count: $0 == 3 ? 8 : 1)
        }

        let summary = InsightsSummary.byDayOfWeek(entries)

        XCTAssertTrue(summary.contains(symbols[2]))
        XCTAssertTrue(summary.contains("8 check-ins"))
    }

    func testIntensityTrendNoIntensitiesReturnsNoDataString() {
        let entries = [
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: nil, logCount: 0),
        ]

        XCTAssertEqual(InsightsSummary.intensityTrend(entries), "Intensity trend chart, no data")
    }

    func testIntensityTrendAveragesAcrossNonNilEntries() {
        let entries = [
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: 2.0, logCount: 1),
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: 4.0, logCount: 1),
        ]

        let summary = InsightsSummary.intensityTrend(entries)

        XCTAssertTrue(summary.contains("3.0 of 5"))
        XCTAssertTrue(summary.contains("2 days"))
    }

    func testIntensityTrendIgnoresDaysWithNilIntensity() {
        let entries = [
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: 3.0, logCount: 1),
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: nil, logCount: 0),
        ]

        let summary = InsightsSummary.intensityTrend(entries)

        XCTAssertTrue(summary.contains("3.0 of 5"))
        XCTAssertTrue(summary.contains("1 day"))
        XCTAssertFalse(summary.contains("2 days"))
    }

    func testBodyEmptyReturnsNoRegionsCapturedString() {
        XCTAssertEqual(InsightsSummary.body([]), "Body chart, no regions captured")
    }

    func testBodyReportsMostFeltRegion() {
        let region = BodyRegion.chest
        let entries = [InsightsDataset.BodyRegionCount(region: region, count: 4)]

        let summary = InsightsSummary.body(entries)

        XCTAssertTrue(summary.contains(region.displayName))
        XCTAssertTrue(summary.contains("4 check-ins"))
    }

    func testMoodScatterReportsPointCount() {
        XCTAssertEqual(InsightsSummary.moodScatter(0), "Mood scale chart, 0 data points")
        XCTAssertEqual(InsightsSummary.moodScatter(1), "Mood scale chart, 1 data point")
        XCTAssertEqual(InsightsSummary.moodScatter(5), "Mood scale chart, 5 data points")
    }
}
