# Spec: Drill-down v2 — extend Insights tap-to-filter to By core, Body, Day-of-week

> **Tier hint:** Sonnet — multi-file but the pattern is fully established
> by the existing Top Feelings drill-down. ~80 lines of new code, ~6 new
> tests.

## Context

Build 15 shipped a tap-to-filter affordance on the **Top Feelings** chart:
tap a bar → switch to History → narrow the list to that secondary name with
a "Showing: <name> · Clear" banner. The mechanism is:

- `HistoryFilter` enum on `AppNavigation` (currently a single case
  `.secondaryName(String)`).
- `AppNavigation.drillIntoHistory(filter:)` selects the Today tab, appends
  `HistoryRoute.full` to `todayPath`, and stages the filter.
- `HistoryView` reads `navigation.historyFilter`, narrows `allLogs`, and
  shows the banner via `.safeAreaInset(edge: .top)`.
- `InsightsTopFeelingsCard` uses `chartOverlay { proxy in ... }` to detect
  taps and resolve the tapped bar via `proxy.value(atY: relativeY) as
  String`.

This spec extends that pattern to three more charts — **By core**, **Body**,
and **By day of week** — without changing the underlying mechanism.

## Goals

- Tapping a bar in the **By core** chart filters History to logs whose
  `coreID` matches.
- Tapping a bar in the **Body** chart filters History to logs whose
  `bodyRegions` *contain* the tapped region.
- Tapping a bar in the **By day of week** chart filters History to logs
  whose `createdAt` weekday matches.
- All three render the same "Tap a bar to filter History" caption already
  used on Top Feelings, so the affordance is discoverable.
- Each new filter case displays sensibly in the History banner.

## Non-goals

- Compound filters (e.g., core + day-of-week). One filter at a time.
- Tap-to-filter on the **Check-ins per day** or **Intensity trend** charts —
  the tap target is a single date, which would over-narrow History.
- Tap-to-filter on the **Mood scatter** — tapping a single (energy, valence)
  point isn't meaningful as a filter.
- Drill-down from cards in the *therapy export* PDF.

## Architecture / approach

Three pieces:

1. **Extend `HistoryFilter`** with three new cases:
   - `.coreID(String)` — match `FeelingLog.coreID`.
   - `.bodyRegion(BodyRegion)` — match logs whose `bodyRegions` array
     contains the region.
   - `.weekday(Int)` — match logs whose `Calendar.current.component(.weekday,
     from: createdAt)` equals the given weekday (1...7,
     `Calendar.current.firstWeekday` convention).

2. **Update `HistoryFilter.displayLabel`** to render each case.

3. **Update `HistoryView`'s filter switch** to handle the new cases.

4. **Add `chartOverlay` tap handlers** on each of the three target charts
   in `InsightsView.swift`, mirroring the Top Feelings pattern exactly.

No changes to `AppNavigation.drillIntoHistory(filter:)` itself — its signature
already accepts any `HistoryFilter`.

## Files affected

### `OpenFeelings/Design/AppNavigation.swift`

Extend `HistoryFilter`:

```swift
enum HistoryFilter: Equatable, Hashable, Sendable {
    case secondaryName(String)
    case coreID(String)              // NEW
    case bodyRegion(BodyRegion)      // NEW
    case weekday(Int)                // NEW — Calendar.weekday convention

    var displayLabel: String {
        switch self {
        case .secondaryName(let name):
            return name
        case .coreID(let id):
            return EmotionTaxonomy.cores.first { $0.id == id }?.name ?? id
        case .bodyRegion(let region):
            return region.displayName
        case .weekday(let weekday):
            // Calendar.current uses 1=Sunday by default. Match the same
            // short-symbol scheme InsightsDataset.byDayOfWeek uses so the
            // banner reads e.g. "Mon" / "Tue".
            let cal = Calendar.current
            let symbols = cal.shortWeekdaySymbols    // [Sun, Mon, Tue, ...]
            let idx = max(0, min(symbols.count - 1, weekday - 1))
            return symbols[idx]
        }
    }
}
```

### `OpenFeelings/Views/HistoryView.swift`

Extend the filter switch in the computed `logs`:

```swift
private var logs: [FeelingLog] {
    guard let filter = navigation.historyFilter else { return allLogs }
    switch filter {
    case .secondaryName(let name):
        return allLogs.filter { $0.secondaryName == name }
    case .coreID(let id):
        return allLogs.filter { $0.coreID == id }
    case .bodyRegion(let region):
        return allLogs.filter { $0.bodyRegions.contains(region) }
    case .weekday(let weekday):
        let cal = Calendar.current
        return allLogs.filter {
            cal.component(.weekday, from: $0.createdAt) == weekday
        }
    }
}
```

`FeelingLog.bodyRegions` already exposes a `[BodyRegion]` decoded from
`bodyRegionsRaw`. `coreID` is a stored property. No model changes needed.

### `OpenFeelings/Views/InsightsView.swift`

For each of the three target chart cards, add the same caption and
`chartOverlay` tap handler the Top Feelings card has. The card needs:

- An `@Environment(AppNavigation.self) private var navigation` field (move
  the `let dataset: ...` declaration to keep them adjacent for clarity).
- A "Tap a bar to filter History" caption in the title `HStack`.
- The Chart wrapped in `.chartOverlay { proxy in GeometryReader ... }`.
- A private `handleTap(at:proxy:geo:)` helper that resolves the tapped value
  and calls `navigation.drillIntoHistory(filter:)`.

#### `InsightsByCoreCard`

Resolve `String` at the *Y* coordinate (the y-axis is the core *name*, not
the ID). Map the name back to its core ID via `EmotionTaxonomy.cores`:

```swift
private func handleTap(at location: CGPoint,
                       proxy: ChartProxy,
                       geo: GeometryProxy) {
    guard let plotFrame = proxy.plotFrame else { return }
    let plotRect = geo[plotFrame]
    let relativeY = location.y - plotRect.minY
    guard let coreName: String = proxy.value(atY: relativeY) else { return }
    guard let core = EmotionTaxonomy.cores.first(where: { $0.name == coreName }) else { return }
    navigation.drillIntoHistory(filter: .coreID(core.id))
}
```

#### `InsightsBodyChart`

Same pattern — y-axis is `region.displayName`, map back to `BodyRegion`:

```swift
guard let regionName: String = proxy.value(atY: relativeY) else { return }
guard let region = BodyRegion.allCases.first(where: { $0.displayName == regionName })
    else { return }
navigation.drillIntoHistory(filter: .bodyRegion(region))
```

#### `InsightsByDayOfWeekCard`

This chart is *vertical* — the categorical axis is **X**. Use
`proxy.value(atX:)` instead, and the calendar to map the symbol back to a
weekday number:

```swift
private func handleTap(at location: CGPoint,
                       proxy: ChartProxy,
                       geo: GeometryProxy) {
    guard let plotFrame = proxy.plotFrame else { return }
    let plotRect = geo[plotFrame]
    let relativeX = location.x - plotRect.minX
    guard let label: String = proxy.value(atX: relativeX) else { return }
    let symbols = Calendar.current.shortWeekdaySymbols    // [Sun, Mon, ...]
    guard let idx = symbols.firstIndex(of: label) else { return }
    navigation.drillIntoHistory(filter: .weekday(idx + 1))   // 1 = Sunday
}
```

## Tests

Add to `OpenFeelingsTests/AppNavigationTests.swift`:

```swift
// MARK: - HistoryFilter cases

func testHistoryFilterCoreIDDisplayLabelResolvesCoreName() {
    XCTAssertEqual(HistoryFilter.coreID("happy").displayLabel, "Happy")
    XCTAssertEqual(HistoryFilter.coreID("sad").displayLabel,   "Sad")
}

func testHistoryFilterCoreIDFallsBackToRawIDWhenUnknown() {
    XCTAssertEqual(HistoryFilter.coreID("not-a-core").displayLabel, "not-a-core")
}

func testHistoryFilterBodyRegionDisplayLabelMatchesEnumDisplayName() {
    let region = BodyRegion.allCases.first { $0 != .wholeBody && $0 != .nowhere }!
    XCTAssertEqual(HistoryFilter.bodyRegion(region).displayLabel, region.displayName)
}

func testHistoryFilterWeekdayDisplayLabelIsAShortSymbol() {
    let symbols = Calendar.current.shortWeekdaySymbols
    for w in 1...7 {
        XCTAssertEqual(HistoryFilter.weekday(w).displayLabel, symbols[w - 1])
    }
}

func testHistoryFilterEqualityIsCaseAware() {
    XCTAssertNotEqual(HistoryFilter.secondaryName("Anxious"),
                      HistoryFilter.coreID("Anxious"))
}
```

Add to a new `OpenFeelingsTests/HistoryFilterPredicateTests.swift`:

```swift
import XCTest
import SwiftData
@testable import OpenFeelings

@MainActor
final class HistoryFilterPredicateTests: XCTestCase {
    // Replicates HistoryView.logs's filter logic. If the filter logic
    // moves into a pure helper later, point these tests at that helper.

    private func log(coreID: String,
                     secondaryName: String = "",
                     bodyRegions: [BodyRegion] = [],
                     weekdayOffset: Int = 0) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == coreID }!
        let l = FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: nil,
            note: "",
            bodyRegions: bodyRegions
        )
        l.secondaryName = secondaryName
        let cal = Calendar.current
        let now = cal.startOfDay(for: Date())
        l.createdAt = cal.date(byAdding: .day, value: weekdayOffset, to: now)!
        return l
    }

    func testCoreIDFilterMatchesByCoreID() {
        let logs = [log(coreID: "happy"), log(coreID: "sad")]
        XCTAssertEqual(filter(.coreID("happy"), logs).map(\.coreID), ["happy"])
    }

    func testBodyRegionFilterMatchesContainment() {
        let chest = BodyRegion.chest
        let logs = [log(coreID: "happy", bodyRegions: [chest]),
                    log(coreID: "sad",   bodyRegions: [])]
        XCTAssertEqual(filter(.bodyRegion(chest), logs).count, 1)
    }

    func testWeekdayFilterMatchesCalendarWeekday() {
        // log on today; assert filter for today's weekday matches.
        let entry = log(coreID: "happy")
        let weekday = Calendar.current.component(.weekday, from: entry.createdAt)
        XCTAssertEqual(filter(.weekday(weekday), [entry]).count, 1)
    }

    private func filter(_ f: HistoryFilter, _ logs: [FeelingLog]) -> [FeelingLog] {
        switch f {
        case .secondaryName(let n): return logs.filter { $0.secondaryName == n }
        case .coreID(let id):       return logs.filter { $0.coreID == id }
        case .bodyRegion(let r):    return logs.filter { $0.bodyRegions.contains(r) }
        case .weekday(let w):       return logs.filter {
            Calendar.current.component(.weekday, from: $0.createdAt) == w
        }
        }
    }
}
```

(If during implementation you decide to extract `HistoryView`'s filter
predicate into a free function for testability, point the tests at that
function instead of duplicating the switch.)

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

Expected: BUILD SUCCEEDED + 191 + ~8 new = ~199 passing tests.

### Manual verification on iPad (A16) iOS 26.0.1

With seeded check-ins covering several cores, several days, and at least
one body region:

1. Insights tab → **By core** card: caption "Tap a bar to filter History"
   visible on the right. Tap the "Happy" bar. Should land on History with
   banner "Showing: Happy · Clear" and only Happy logs visible.
2. **Clear** the filter, return to Insights.
3. **Body** card: tap a region row. Banner reads e.g. "Showing: Chest" with
   only logs that include Chest visible.
4. **By day of week** card: tap "Mon" bar. Banner reads "Showing: Mon" with
   only Monday logs visible.
5. Each filter Clears correctly and shows the unfiltered list.

## Edge cases

- **Tap miss / out of plot bounds.** `proxy.value(atY:)` returns nil — the
  guard short-circuits, no action taken. Same as Top Feelings handles it.
- **Stale filter state.** If the user drills into Body filter, then opens
  Insights and drills into Core, the filter is *replaced* (not combined).
  Existing single-filter semantics. Document in code comment.
- **Empty filter result.** Already handled by `HistoryView`'s
  filtered-vs-unfiltered empty-state copy.

## Out of scope

- Multi-tap filter combinations.
- Filter pills above the History list (would let the user *add* filters
  rather than replace). This is a v3 idea.
- Persisting filter state across launches — the filter clears on app cold
  launch since `AppNavigation` is created fresh.

## Implementation order

1. Extend `HistoryFilter` enum + `displayLabel`. Add the four
   AppNavigationTests.
2. Extend `HistoryView`'s filter switch. Add HistoryFilterPredicateTests.
3. Add the chartOverlay handlers to `InsightsByCoreCard`,
   `InsightsBodyChart`, `InsightsByDayOfWeekCard`. Reuse the exact
   pattern from `InsightsTopFeelingsCard` — including the caption, the
   `@Environment` declaration, and the `handleTap` private helper. Don't
   abstract; the duplication is small and the cards have different axis
   orientations.
4. Run tests. Manual sim verification.
5. Single feature commit. No build bump until manually QA'd.
