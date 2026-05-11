# Spec: AXChartDescriptor for Top Feelings and By Core charts

> **Tier hint:** Sonnet. Apple-specific accessibility API. Two charts get
> the full `AXChartDescriptorRepresentable` treatment; the rest are
> deferred to future work.

## Context

Build 15 shipped per-mark `.accessibilityLabel(...)` and chart-level
`.accessibilityLabel(...)` strings on every Insights chart. That works
well for a VoiceOver user sweeping through the screen, but it doesn't
support the **VoiceOver rotor** "chart data" navigation, which lets the
user navigate per-axis and per-series with finer control.

The system that drives rotor navigation is
[`AXChartDescriptorRepresentable`](https://developer.apple.com/documentation/swiftui/view/accessibilitychartdescriptor(_:)).
Adopting it on Insights's two highest-value charts — **Top feelings** and
**By core** — gives VoiceOver users a richer way to explore patterns.

This spec adopts the protocol on those two charts. The rest of the
Insights charts are deferred (each has its own quirks: time-axis vs
categorical, optional values, etc.).

## Goals

- `InsightsTopFeelingsCard`'s Chart exposes an `AXChartDescriptor` such
  that VoiceOver's rotor offers a "Chart" item, which when chosen lets the
  user step through each feeling and hear its name + count.
- `InsightsByCoreCard`'s Chart exposes the same.
- Per-mark and chart-level labels continue to work unchanged.
- Build green; existing tests still pass.

## Non-goals

- AX descriptors on the other charts (Check-ins-per-day, Day-of-week,
  Intensity trend, Body, Mood scatter). Spec separately if you want them.
- Series-level audio graphs / sonification (a different Apple API).
- Changes to the visible UI.

## Approach

Apple's pattern is:

1. Conform a small type to `AXChartDescriptorRepresentable`.
2. The required `makeChartDescriptor() -> AXChartDescriptor` returns a
   value describing the chart's title, x-axis, y-axis, and series.
3. Attach via `.accessibilityChartDescriptor(_:)` on the Chart.

`AXChartDescriptor` lives in `<Accessibility/Accessibility.h>` —
implicitly available via `import SwiftUI` and `import Accessibility`.
Field shape (verbatim from Apple's docs):

```swift
AXChartDescriptor(
    title: String,
    summary: String? = nil,
    xAxis: AXDataAxisDescriptor,
    yAxis: AXNumericDataAxisDescriptor,
    additionalAxes: [AXNumericDataAxisDescriptor] = [],
    series: [AXDataSeriesDescriptor]
)
```

For both target charts the y-axis is *categorical* (feeling name / core
name) and the x-axis is *numeric* (count). Apple's pattern reverses what
you'd expect from a "horizontal bar chart", because the value axis is
numeric (counts) and the category axis is the named axis. We use:

- **xAxis (numeric):** `AXNumericDataAxisDescriptor(title:range:gridlinePositions:valueDescriptionProvider:)`
- **yAxis (categorical):** `AXCategoricalDataAxisDescriptor(title:categoryOrder:)`

`AXDataSeriesDescriptor` carries one or more series; we only have one
series per chart. Each `AXDataPoint` has an x value (numeric count) and a
y value (the category name string).

### `OpenFeelings/Views/InsightsView.swift`

Add this private helper near the bottom of the file, alongside
`InsightsSummary` (or, if `InsightsSummary` hasn't landed yet, near
`checkInCountPhrase`):

```swift
import Accessibility   // add at top if not present

/// Builds AXChartDescriptors for the categorical horizontal bar charts.
/// The pattern is shared by Top Feelings and By Core: a numeric X axis
/// (count) and a categorical Y axis (name).
enum InsightsChartDescriptor {
    static func barCategorical(
        title: String,
        items: [(category: String, count: Int)]
    ) -> AXChartDescriptor {
        let maxCount = max(1, items.map(\.count).max() ?? 1)
        let categories = items.map(\.category)

        let xAxis = AXNumericDataAxisDescriptor(
            title: "Check-ins",
            range: 0.0...Double(maxCount),
            gridlinePositions: [0.0, Double(maxCount)]
        ) { value in
            "\(Int(value.rounded())) check-ins"
        }

        let yAxis = AXCategoricalDataAxisDescriptor(
            title: title,
            categoryOrder: categories
        )

        let points = items.map { item in
            AXDataPoint(
                x: Double(item.count),
                y: 0,                          // unused for categorical y
                additionalValues: [],
                label: item.category           // the announced category
            )
        }

        let series = AXDataSeriesDescriptor(
            name: title,
            isContinuous: false,
            dataPoints: points
        )

        return AXChartDescriptor(
            title: title,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
```

> **API note for the implementer:** `AXDataPoint`'s init takes `x:` and
> `y:` as `Double`. For a category-on-y chart, we pass `y: 0` and put the
> category name in `label:`, which is what VoiceOver actually announces.
> The point's *category* membership for rotor navigation comes from
> matching `point.label` to one of `yAxis.categoryOrder`. Don't try to
> stuff the category into `y` — the API is numeric there.

#### Attach to `InsightsTopFeelingsCard`

Find the `Chart(dataset.topFeelings, id: \.name) { feeling in ... }` and
add at the same level as the other chart modifiers:

```swift
.accessibilityChartDescriptor(TopFeelingsChartAX(dataset: dataset))
```

Below the card struct, add:

```swift
private struct TopFeelingsChartAX: AXChartDescriptorRepresentable {
    let dataset: InsightsDataset
    func makeChartDescriptor() -> AXChartDescriptor {
        InsightsChartDescriptor.barCategorical(
            title: "Top feelings",
            items: dataset.topFeelings.map { (category: $0.name, count: $0.count) }
        )
    }
}
```

#### Attach to `InsightsByCoreCard`

Same pattern:

```swift
.accessibilityChartDescriptor(ByCoreChartAX(dataset: dataset))
```

```swift
private struct ByCoreChartAX: AXChartDescriptorRepresentable {
    let dataset: InsightsDataset
    func makeChartDescriptor() -> AXChartDescriptor {
        InsightsChartDescriptor.barCategorical(
            title: "By core",
            items: dataset.byCore.map { (category: $0.coreName, count: $0.count) }
        )
    }
}
```

## Tests

Add a small test file that asserts on the descriptor's *shape* — title,
series count, data-point count, ordering. Don't try to assert on
runtime VoiceOver announcement (that's a manual on-device verification).

`OpenFeelingsTests/InsightsChartDescriptorTests.swift` (new):

```swift
import XCTest
import Accessibility
@testable import OpenFeelings

final class InsightsChartDescriptorTests: XCTestCase {

    func testBarCategoricalDescriptorTitle() {
        let descriptor = InsightsChartDescriptor.barCategorical(
            title: "Top feelings",
            items: [(category: "Hopeful", count: 3)]
        )
        XCTAssertEqual(descriptor.title, "Top feelings")
    }

    func testBarCategoricalDescriptorHasOneSeries() {
        let descriptor = InsightsChartDescriptor.barCategorical(
            title: "By core",
            items: [(category: "Happy", count: 5), (category: "Sad", count: 2)]
        )
        XCTAssertEqual(descriptor.series.count, 1)
    }

    func testBarCategoricalDescriptorDataPointCountMatchesItems() {
        let descriptor = InsightsChartDescriptor.barCategorical(
            title: "Top feelings",
            items: [
                (category: "Hopeful", count: 3),
                (category: "Lonely",  count: 2),
                (category: "Calm",    count: 1)
            ]
        )
        XCTAssertEqual(descriptor.series.first?.dataPoints.count, 3)
    }

    func testBarCategoricalDescriptorPointLabelsPreserveOrder() {
        let descriptor = InsightsChartDescriptor.barCategorical(
            title: "By core",
            items: [(category: "Happy", count: 5), (category: "Sad", count: 2)]
        )
        let labels = descriptor.series.first?.dataPoints.map(\.label) ?? []
        XCTAssertEqual(labels, ["Happy", "Sad"])
    }

    func testBarCategoricalDescriptorEmptyItems() {
        let descriptor = InsightsChartDescriptor.barCategorical(
            title: "Top feelings",
            items: []
        )
        XCTAssertEqual(descriptor.series.first?.dataPoints.count, 0)
    }

    func testBarCategoricalDescriptorXAxisIsCheckInsCategoryName() {
        let descriptor = InsightsChartDescriptor.barCategorical(
            title: "By core",
            items: [(category: "Happy", count: 4)]
        )
        // The numeric x-axis is "Check-ins" regardless of chart title.
        XCTAssertEqual((descriptor.xAxis as? AXNumericDataAxisDescriptor)?.title, "Check-ins")
    }
}
```

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

Expected: BUILD SUCCEEDED + 210 + 6 new = ~216 passing tests.

### Manual VoiceOver verification on iPad (A16) iOS 26.0.1

With seeded check-ins covering 3+ different secondaries and 2+ cores:

1. Settings → Accessibility → VoiceOver → On.
2. Open Insights.
3. Focus the **Top feelings** card's chart area. Open the rotor (two-
   finger twist). A "Chart Details" item should appear (it does *not*
   appear without the descriptor — that's the regression test).
4. Select "Chart Details" → VoiceOver enters chart navigation. Swipe
   right to step through each feeling, hearing its name and count.
5. Repeat on the **By core** card.

If "Chart Details" doesn't appear in the rotor, the descriptor isn't
attached. Re-check that `.accessibilityChartDescriptor(...)` is at the
Chart-modifier level (not inside the Chart closure).

## Implementation order

1. `import Accessibility` at the top of `InsightsView.swift`.
2. Add `enum InsightsChartDescriptor` with `barCategorical(...)`.
3. Add `TopFeelingsChartAX` + attach to `InsightsTopFeelingsCard`'s Chart.
4. Add `ByCoreChartAX` + attach to `InsightsByCoreCard`'s Chart.
5. Build green.
6. Add `InsightsChartDescriptorTests.swift`. Run tests.
7. Manual sim VoiceOver verification per checklist above.
8. Single feature commit.

## Out of scope

- AX descriptors for time-axis charts (Check-ins per day, Intensity
  trend) — these need `AXNumericDataAxisDescriptor` on x with
  date-formatted value descriptions; different shape.
- AX descriptors for vertical-bar charts (Day of week) — straightforward
  extension once we know the categorical+numeric pattern works.
- AX descriptors for Mood scatter — needs two numeric axes plus
  per-point category metadata. Different shape entirely.
- Sonified data ("audio graphs").
