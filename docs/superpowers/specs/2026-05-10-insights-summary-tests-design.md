# Spec: Unit tests for Insights chart summary strings

> **Tier hint:** Haiku. Tests-only deliverable plus a small mechanical
> refactor. Touches one production file (extract 5 short helpers) and
> adds one new test file. No UI changes, no model changes.

## Context

Build 15 shipped chart-level `.accessibilityLabel(...)` summaries on every
Insights chart. The label values come from five `private var` computed
properties inside individual card structs in
`OpenFeelings/Views/InsightsView.swift`:

| Card | Property | Lines (approx) |
|---|---|---|
| `InsightsByCoreCard` | `coreSummary` | 277 |
| `InsightsTopFeelingsCard` | `topFeelingsSummary` | 353 |
| `InsightsByDayOfWeekCard` | `dayOfWeekSummary` | 425 |
| `InsightsIntensityTrendCard` | `intensityTrendSummary` | 484 |
| `InsightsBodyChart` | `bodySummary` | 557 |

Plus two file-private helpers reading the dataset directly:

- `checkInCountPhrase(_:) -> String` (top-level in file)
- The Check-ins-per-day chart's inline summary on `InsightsCheckInChart`'s
  `Chart`'s `.accessibilityLabel(...)` (uses `dataset.totalCount` directly)

None of this has test coverage. The summary strings are user-facing
(VoiceOver hears them) and easy to break with an off-by-one or
pluralization slip. This spec adds the missing coverage.

## Goals

- Each summary helper becomes individually testable.
- One new test file covers all six summaries (the five card summaries plus
  `checkInCountPhrase` plurality).
- No visible UI change. No model change.
- No regression in the existing 210 tests.

## Non-goals

- New summary strings, copy changes, or localization work.
- Tests for the actual Swift Charts rendering output (covered by build
  green; runtime AX label correctness is verified manually).
- Tests for the per-mark `.accessibilityLabel(...)` / `.accessibilityValue(...)`
  on the individual bars — those are mostly just identity passthroughs and
  not worth the test ceremony.

## Approach

Move each summary into a top-level `enum InsightsSummary` with `static func`
methods. The card views call into the enum; tests call into the enum
directly.

### `OpenFeelings/Views/InsightsView.swift`

At the bottom of the file (alongside the existing `checkInCountPhrase`
helper), introduce:

```swift
/// Builders for chart-level `.accessibilityLabel` strings. Pulled out so
/// they can be unit-tested without instantiating the card views.
enum InsightsSummary {
    static func checkInsPerDay(totalCount: Int, dayCount: Int) -> String {
        "Check-ins per day chart, \(checkInCountPhrase(totalCount)) over \(dayCount) day\(dayCount == 1 ? "" : "s")"
    }

    static func byCore(_ entries: [InsightsDataset.CoreCount]) -> String {
        guard let top = entries.first else {
            return "By core chart, no data"
        }
        return "By core chart, top is \(top.coreName) with \(checkInCountPhrase(top.count))"
    }

    static func topFeelings(_ entries: [InsightsDataset.FeelingCount]) -> String {
        guard let top = entries.first else {
            return "Top feelings chart, no data"
        }
        return "Top feelings chart, top is \(top.name) with \(checkInCountPhrase(top.count))"
    }

    static func byDayOfWeek(_ entries: [InsightsDataset.DOWCount]) -> String {
        let busiest = entries.max(by: { $0.count < $1.count })
        guard let top = busiest, top.count > 0 else {
            return "By day of week chart, no data"
        }
        return "By day of week chart, busiest is \(top.label) with \(checkInCountPhrase(top.count))"
    }

    static func intensityTrend(_ entries: [InsightsDataset.DayIntensity]) -> String {
        let values = entries.compactMap(\.avgIntensity)
        guard !values.isEmpty else { return "Intensity trend chart, no data" }
        let avg = values.reduce(0, +) / Double(values.count)
        return String(format: "Intensity trend chart, average %.1f of 5 across %d day%@",
                      avg, values.count, values.count == 1 ? "" : "s")
    }

    static func body(_ entries: [InsightsDataset.BodyRegionCount]) -> String {
        guard let top = entries.first else {
            return "Body chart, no regions captured"
        }
        return "Body chart, most-felt is \(top.region.displayName) with \(checkInCountPhrase(top.count))"
    }

    static func moodScatter(_ pointCount: Int) -> String {
        "Mood scale chart, \(pointCount) data point\(pointCount == 1 ? "" : "s")"
    }
}
```

Then replace each private computed property and each inline `.accessibilityLabel(...)`
that builds these strings with a call to the enum. For example:

```swift
// before, on InsightsByCoreCard:
.accessibilityLabel(coreSummary)
// ...
private var coreSummary: String { ... }

// after:
.accessibilityLabel(InsightsSummary.byCore(dataset.byCore))
// (delete the private var)
```

Same pattern for the four other card summaries and the mood-scatter inline
label. For the Check-ins-per-day chart's `.accessibilityLabel(...)`, pass
`(totalCount: dataset.totalCount, dayCount: dataset.countsPerDay.count)`.

Promote `checkInCountPhrase` from `private` to `internal` (or move it
*into* `InsightsSummary` — either works; the simpler move is just to drop
the `private` keyword and let the new enum use it as a file-internal
top-level helper).

### `OpenFeelingsTests/InsightsSummaryTests.swift` (new)

```swift
import XCTest
@testable import OpenFeelings

final class InsightsSummaryTests: XCTestCase {

    // MARK: - Pluralization helper

    func testCheckInCountPhraseSingularAndPlural() {
        XCTAssertEqual(checkInCountPhrase(0), "no check-ins")
        XCTAssertEqual(checkInCountPhrase(1), "1 check-in")
        XCTAssertEqual(checkInCountPhrase(5), "5 check-ins")
    }

    // MARK: - Check-ins per day

    func testCheckInsPerDayMentionsTotalAndDayCount() {
        let s = InsightsSummary.checkInsPerDay(totalCount: 3, dayCount: 7)
        XCTAssertTrue(s.contains("3 check-ins"))
        XCTAssertTrue(s.contains("7 days"))
    }

    func testCheckInsPerDaySingularDay() {
        XCTAssertTrue(InsightsSummary
            .checkInsPerDay(totalCount: 1, dayCount: 1)
            .contains("1 day"))
        XCTAssertFalse(InsightsSummary
            .checkInsPerDay(totalCount: 1, dayCount: 1)
            .contains("1 days"))
    }

    // MARK: - By core

    func testByCoreEmptyReturnsNoDataString() {
        XCTAssertEqual(InsightsSummary.byCore([]), "By core chart, no data")
    }

    func testByCoreReportsTopCoreNameAndCount() {
        let entries = [
            InsightsDataset.CoreCount(coreID: "happy", coreName: "Happy", colorHex: "F4D03F", count: 5),
            InsightsDataset.CoreCount(coreID: "sad",   coreName: "Sad",   colorHex: "3498DB", count: 2)
        ]
        let s = InsightsSummary.byCore(entries)
        XCTAssertTrue(s.contains("Happy"))
        XCTAssertTrue(s.contains("5 check-ins"))
    }

    // MARK: - Top feelings

    func testTopFeelingsEmptyReturnsNoDataString() {
        XCTAssertEqual(InsightsSummary.topFeelings([]), "Top feelings chart, no data")
    }

    func testTopFeelingsReportsTopName() {
        let entries = [
            InsightsDataset.FeelingCount(name: "Hopeful", coreID: "happy", count: 3),
            InsightsDataset.FeelingCount(name: "Lonely",  coreID: "sad",   count: 1)
        ]
        XCTAssertTrue(InsightsSummary.topFeelings(entries).contains("Hopeful"))
    }

    // MARK: - By day of week

    func testByDayOfWeekAllZeroReturnsNoDataString() {
        let symbols = Calendar.current.shortWeekdaySymbols
        let entries = (1...7).map {
            InsightsDataset.DOWCount(weekday: $0, label: symbols[$0 - 1], count: 0)
        }
        XCTAssertEqual(InsightsSummary.byDayOfWeek(entries), "By day of week chart, no data")
    }

    func testByDayOfWeekReportsBusiestDay() {
        let symbols = Calendar.current.shortWeekdaySymbols
        var entries: [InsightsDataset.DOWCount] = []
        for w in 1...7 {
            entries.append(InsightsDataset.DOWCount(weekday: w, label: symbols[w - 1], count: w == 3 ? 8 : 1))
        }
        let s = InsightsSummary.byDayOfWeek(entries)
        XCTAssertTrue(s.contains(symbols[2]))     // weekday 3 → index 2
        XCTAssertTrue(s.contains("8 check-ins"))
    }

    // MARK: - Intensity trend

    func testIntensityTrendNoIntensitiesReturnsNoDataString() {
        let entries = [
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: nil, logCount: 0)
        ]
        XCTAssertEqual(InsightsSummary.intensityTrend(entries), "Intensity trend chart, no data")
    }

    func testIntensityTrendAveragesAcrossNonNilEntries() {
        let entries = [
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: 2.0, logCount: 1),
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: 4.0, logCount: 1)
        ]
        let s = InsightsSummary.intensityTrend(entries)
        XCTAssertTrue(s.contains("3.0 of 5"))
        XCTAssertTrue(s.contains("2 days"))
    }

    func testIntensityTrendIgnoresDaysWithNilIntensity() {
        let entries = [
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: 3.0, logCount: 1),
            InsightsDataset.DayIntensity(day: Date(), avgIntensity: nil, logCount: 0)
        ]
        let s = InsightsSummary.intensityTrend(entries)
        XCTAssertTrue(s.contains("3.0 of 5"))
        XCTAssertTrue(s.contains("1 day"),
                      "Should report 1 day (the day with intensity), not 2.")
    }

    // MARK: - Body

    func testBodyEmptyReturnsNoRegionsCapturedString() {
        XCTAssertEqual(InsightsSummary.body([]), "Body chart, no regions captured")
    }

    func testBodyReportsMostFeltRegion() {
        let region = BodyRegion.chest
        let entries = [InsightsDataset.BodyRegionCount(region: region, count: 4)]
        let s = InsightsSummary.body(entries)
        XCTAssertTrue(s.contains(region.displayName))
        XCTAssertTrue(s.contains("4 check-ins"))
    }

    // MARK: - Mood scatter

    func testMoodScatterReportsPointCount() {
        XCTAssertEqual(InsightsSummary.moodScatter(0), "Mood scale chart, 0 data points")
        XCTAssertEqual(InsightsSummary.moodScatter(1), "Mood scale chart, 1 data point")
        XCTAssertEqual(InsightsSummary.moodScatter(5), "Mood scale chart, 5 data points")
    }
}
```

If the `InsightsDataset.CoreCount` / `FeelingCount` / `DOWCount` /
`DayIntensity` / `BodyRegionCount` initializers aren't currently `internal`,
expose them as `internal` (the structs themselves are already nested inside
`InsightsDataset` which is `internal`). They're plain value types with no
sensitive invariants.

## Verification

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED + 210 + ~16 new = ~226 passing tests.

## Implementation order

1. Add the `InsightsSummary` enum at the end of `InsightsView.swift`. Make
   `checkInCountPhrase` non-private (drop the `private` keyword).
2. Replace each card's `private var ...Summary: String` with a call to the
   matching `InsightsSummary.<func>(...)` at the `.accessibilityLabel(...)`
   site. Delete the now-unused private vars.
3. For the two inline `.accessibilityLabel(...)` calls (the check-ins-per-day
   chart and the mood scatter chart), swap them for
   `InsightsSummary.checkInsPerDay(...)` and `InsightsSummary.moodScatter(...)`.
4. Run the existing test suite — must still be green (no behavior change).
5. Add the new `InsightsSummaryTests.swift` file. Run tests.
6. Single feature commit.

## Out of scope

- Any change to per-mark `.accessibilityLabel` / `.accessibilityValue`.
- Localizing the summaries.
- Promoting `InsightsSummary` to a public API.
- Snapshot/UI tests for VoiceOver actual announcement (manual on device).
