# Spec: VoiceOver labels for Today, History cards, and Wizard mode picker

> **Tier hint:** Haiku. Pure pattern-matching against an established
> convention. ~10–15 small `.accessibilityLabel(...)` / `.accessibilityValue(...)` /
> `.accessibilityElement(children: .combine)` additions across three
> files, plus three small unit tests.

## Context

The Insights tab now has rich VoiceOver labels on every chart mark and a
chart-level summary on each Chart container. Three other surfaces lag:

1. **Today tab cards.** The "Today's check-ins" cards and the "This week"
   summary card render multi-element layouts with no `.accessibilityLabel`,
   so VoiceOver announces them piecewise (icon, then time, then path, etc.)
   in a way that's hard to follow.
2. **History card sub-elements.** Each `LogCard` shows a stack of mini text
   rows (intensity dots, body summary, context summary, triggers/coping).
   VoiceOver reads each row independently, with no card-level summary.
3. **Wizard mode segmented picker.** The "Wizard / Wheel" segmented buttons
   in `FeelingStep` are currently announced as "Wizard, button" without
   indicating they're a *picker* with selected state.

This spec is a single coordinated AX pass to bring these to parity with the
Insights tab's coverage.

## Goals

- Each Today card reads as one cohesive sentence under VoiceOver.
- Each History `LogCard` reads with one summary, with sub-rows still
  navigable for detail.
- The wizard mode picker announces "Wizard, picker, selected, 1 of 2" or
  similar — confirms it's a picker and which option is active.

## Non-goals

- New AX modifiers on the wizard's emotion grid — that already has stable
  `.accessibilityIdentifier("emotion.<name>")` and reads correctly.
- AX descriptors (`AXChartDescriptorRepresentable`) for charts — separate spec.
- Re-styling or layout changes. AX-only.
- Accessibility for the silhouette body view — feature-flagged off (`FeatureFlags.silhouetteBodyView == false`); no work needed there.

## Architecture / approach

Three localized passes — no shared code, no new types. Each pass uses the
existing pattern from `InsightsView`'s chart-level labels:

- `.accessibilityElement(children: .combine)` — collapses a multi-element
  view into one AX node.
- `.accessibilityLabel(_:)` — supplies the announced text.
- `.accessibilityValue(_:)` — supplies state info (e.g., "selected").

Strings are computed inline as small `private` helpers when more than one
substring needs interpolation. Otherwise inline.

## Files affected

### 1. `OpenFeelings/Views/TodayView.swift`

Wrap the three card types with `.accessibilityElement(children: .combine)`
and add a `.accessibilityLabel(...)` summary.

#### Today's check-ins card row

Locate the `ForEach(todaysLogs) { log in ... }` rendering and the small log
preview row inside it. Add to the inner row view:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(Self.todayLogAXLabel(for: log))
```

with a static helper at the bottom of the struct:

```swift
private static func todayLogAXLabel(for log: FeelingLog) -> String {
    let time = log.createdAt.formatted(.dateTime.hour().minute())
    let path = log.pathTitle.replacingOccurrences(of: " > ", with: ", ")
    if let intensity = log.intensity {
        return "\(time): \(path), intensity \(intensity) of 5"
    }
    return "\(time): \(path)"
}
```

#### Week summary card

Find the `weekSummarySection` view. Wrap the `OFCard { ... }` content with:

```swift
.accessibilityElement(children: .combine)
.accessibilityLabel(weekSummaryAXLabel)
```

and a computed property:

```swift
private var weekSummaryAXLabel: String {
    guard let summary = weekSummary else { return "Week summary" }
    return "This week: \(summary.count) check-ins, top feeling \(summary.topName)"
}
```

If `WeekSummary` doesn't expose a `topName` field, derive a sensible
substitute from the existing fields the card already renders. Inspect
`WeekSummary` and use whatever name is already shown visually.

#### "Start a check-in" empty state primary action

`OFEmptyState`'s primary action button already gets a default AX label from
its title. No change needed unless verification surfaces a regression.

### 2. `OpenFeelings/Views/HistoryView.swift`

Find the `LogCard` view (private struct inside the file) and wrap its `body`
with combine + label:

```swift
var body: some View {
    VStack(alignment: .leading, spacing: .OF.sm) {
        // ... unchanged content ...
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(Self.cardAXLabel(for: log))
}
```

```swift
private static func cardAXLabel(for log: FeelingLog) -> String {
    let date = log.createdAt.formatted(date: .abbreviated, time: .shortened)
    let path = log.pathTitle.replacingOccurrences(of: " > ", with: ", ")
    var parts = ["\(date): \(path)"]
    if let intensity = log.intensity {
        parts.append("intensity \(intensity) of 5")
    }
    if !log.note.isEmpty {
        parts.append("with a note")
    }
    return parts.joined(separator: ", ")
}
```

`children: .combine` keeps individual sub-elements navigable while supplying
a single coherent default label.

### 3. `OpenFeelings/Views/CheckInWizard/Steps/FeelingStep.swift`

The mode-segmented control is `modeSegmented` (around line 73). It's a
custom `HStack` of `Button` views, not a SwiftUI `Picker`. VoiceOver doesn't
know it's a picker.

Wrap the whole HStack:

```swift
private var modeSegmented: some View {
    HStack(spacing: 0) {
        ForEach(FeelingStepCheckInMode.allCases) { m in
            Button { ... } label: { ... }
                .accessibilityLabel(m.rawValue)
                .accessibilityValue(mode == m ? "selected" : "")
                .accessibilityAddTraits(.isButton)
        }
    }
    // ...existing modifiers...
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Picker mode")
    .accessibilityHint("Choose Wizard for a guided three-step pick or Wheel for the full wheel.")
}
```

Note: `.contain` (not `.combine`) — we want the inner buttons to remain
individually tappable under VoiceOver.

## Tests

Add to `OpenFeelingsTests/`:

### `OpenFeelingsTests/HistoryViewAXTests.swift` (new)

```swift
import XCTest
@testable import OpenFeelings

final class HistoryViewAXTests: XCTestCase {
    private func log(intensity: Int? = nil, note: String = "") -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        let l = FeelingLog(selection: selection, intensity: intensity, note: note)
        l.createdAt = Date(timeIntervalSince1970: 1_715_000_000) // stable date
        return l
    }

    func testCardAXLabelIncludesPathAndDate() {
        let label = LogCard.cardAXLabel(for: log())
        XCTAssertTrue(label.contains("Happy"))
        // Date format depends on locale; just assert non-empty.
        XCTAssertFalse(label.isEmpty)
    }

    func testCardAXLabelIncludesIntensityWhenSet() {
        XCTAssertTrue(LogCard.cardAXLabel(for: log(intensity: 4)).contains("intensity 4"))
    }

    func testCardAXLabelMentionsNoteWhenPresent() {
        XCTAssertTrue(LogCard.cardAXLabel(for: log(note: "x")).contains("with a note"))
    }
}
```

For the test to compile, change `LogCard` from `private struct` to
`struct LogCard: View {}` (or `internal`) so the test target can see it.
The `cardAXLabel(for:)` static helper must also be at least `internal`.

This is a small testability concession — leave the struct's *initializer*
internal too if it isn't already.

### `OpenFeelingsTests/TodayViewAXTests.swift` (new)

Same pattern for `TodayView.todayLogAXLabel(for:)` and
`weekSummaryAXLabel`. Three small assertions:

- Label includes time substring like `12:00`.
- Label includes the emotion path.
- Label includes "intensity X of 5" only when intensity is non-nil.

`TodayView`'s static helper must be `internal static`.

`weekSummaryAXLabel` is harder to unit-test cleanly because it's a computed
property on the view and depends on `weekSummary`. Either:

- Skip it from tests (acceptable — the helper is two lines), **or**
- Refactor to a static `Self.weekSummaryAXLabel(for: WeekSummary?) -> String`
  free function and test that.

Pick whichever feels cleaner during implementation.

### Verify on a real or simulator device

After landing the code, on iPad (A16) iOS 26.0.1:

1. Settings → Accessibility → VoiceOver → On.
2. Open Today. Swipe through the cards. Each card should announce a single
   coherent sentence (date/time, emotion path, intensity if present), then
   on the next swipe expose its sub-rows.
3. Open History. Same expectation per card.
4. Tap Check In, advance to the Feeling step. Swipe to the Wizard/Wheel
   pill. VoiceOver should announce "Picker mode", then on the next swipe
   announce "Wizard, button, selected" and "Wheel, button" (or vice versa
   depending on `@AppStorage`).
5. Tap "Wheel" — VoiceOver should announce the new selection.

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

Expected: BUILD SUCCEEDED + 191 + ~5–7 new = ~197 passing tests.

## Implementation order

1. Read `TodayView.swift`, `HistoryView.swift`, `FeelingStep.swift` to
   confirm exact line ranges and existing modifier ordering before editing.
2. Land the AX additions in the order above (Today → History → Wizard).
3. Add the new test files and run them.
4. Single feature commit.

## Out of scope

- AX coverage for the silhouette body view (feature-flagged off).
- Drill-down or tap behaviors — this is read-only AX.
- Reduce-Transparency / Reduce-Motion adjustments.
- VoiceOver custom rotors.
