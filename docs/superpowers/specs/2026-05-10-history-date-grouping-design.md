# Spec: History — group cards by date

> **Tier hint:** Sonnet. Small UX feature plus a pure-logic grouper that
> gets unit-tested. ~50 lines net of view code, ~30 lines of test code.

## Context

`HistoryView` currently renders every `FeelingLog` as a vertical scroll of
identical `OFCard`s with no visual separation between days. For a user with
30+ check-ins, scanning for "what did I feel on Tuesday" requires reading
each card's timestamp.

Add per-day section headers — same `OFSectionHeader` component used
elsewhere in the app — so the list looks like:

```
Sat, May 10
[card]
[card]
Fri, May 9
[card]
Thu, May 8
[card]
[card]
[card]
```

## Goals

- Logs in the History list visually group under date-day headers.
- "Today" / "Yesterday" labels for the two most recent day-buckets;
  abbreviated weekday + month + day for the rest.
- Behavior is filter-aware: when `historyFilter` is active and reduces
  the visible logs, the grouping recomputes against the filtered list.
- Pure-logic grouper extracted to a static helper for unit testing.
- No model change. No new dependencies.

## Non-goals

- Collapsible day sections (could be a v2).
- Sticky-header behavior — let day-headers scroll normally.
- A separate "calendar view" or month picker.
- Changes to `LogCard` itself.

## Approach

Add a tiny value-typed `DayGroup` struct that bundles a label and an array
of logs. A static helper on `HistoryView` builds an `[DayGroup]` from any
`[FeelingLog]`. The view's ForEach renders one `OFSectionHeader` per group
followed by the group's `LogCard`s.

### `OpenFeelings/Views/HistoryView.swift`

Add near the bottom of the file (alongside the existing extension
containing `filteredLogs` and `deleteLog`):

```swift
extension HistoryView {
    /// One day-bucket of logs with a human-friendly label
    /// ("Today", "Yesterday", "Thu, May 8").
    struct DayGroup: Identifiable, Equatable {
        var id: Date { day }
        let day: Date          // start-of-day
        let label: String
        let logs: [FeelingLog]
    }

    /// Groups logs by their `createdAt`'s start-of-day, sorted descending,
    /// with a friendly label per group.
    /// The input array is assumed to already be sorted by `createdAt`
    /// descending — the `@Query` in `HistoryView` provides this. The helper
    /// re-sorts defensively in case a test or future caller doesn't.
    nonisolated static func groupByDay(_ logs: [FeelingLog],
                                       now: Date = Date(),
                                       calendar: Calendar = .current) -> [DayGroup] {
        let sorted = logs.sorted { $0.createdAt > $1.createdAt }
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Bucket by start-of-day, preserving descending order.
        var buckets: [(day: Date, logs: [FeelingLog])] = []
        for log in sorted {
            let day = calendar.startOfDay(for: log.createdAt)
            if buckets.last?.day == day {
                buckets[buckets.count - 1].logs.append(log)
            } else {
                buckets.append((day: day, logs: [log]))
            }
        }

        return buckets.map { bucket in
            DayGroup(day: bucket.day, label: labelFor(day: bucket.day,
                                                     today: today,
                                                     yesterday: yesterday),
                     logs: bucket.logs)
        }
    }

    private static func labelFor(day: Date, today: Date, yesterday: Date) -> String {
        if day == today { return "Today" }
        if day == yesterday { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}
```

Then update the `content` view's non-empty branch to render groups
instead of a flat ForEach:

```swift
// Replace this block:
ScrollView {
    VStack(spacing: .OF.md) {
        ForEach(logs) { log in
            OFCard { LogCard(log: log) }
                .swipeActions(...) { ... }
                .accessibilityAction(named: "Delete") { ... }
        }
    }
    .padding(...)
}

// With:
ScrollView {
    VStack(alignment: .leading, spacing: .OF.lg) {
        ForEach(Self.groupByDay(logs)) { group in
            VStack(alignment: .leading, spacing: .OF.md) {
                OFSectionHeader(title: group.label)
                ForEach(group.logs) { log in
                    OFCard { LogCard(log: log) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDelete = log
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .accessibilityAction(named: "Delete") {
                            pendingDelete = log
                        }
                }
            }
        }
    }
    .padding(.horizontal, CGFloat.OF.lg)
    .padding(.bottom, CGFloat.OF.xxxl)
    .padding(.top, CGFloat.OF.lg)
}
```

Spacing: outer `VStack` uses `.OF.lg` (larger gap between day groups);
inner uses `.OF.md` (existing card-to-card spacing within a day). The
`alignment: .leading` ensures the `OFSectionHeader` left-aligns inside the
horizontally-padded scroll content.

### `OpenFeelingsTests/HistoryDateGroupingTests.swift` (new)

```swift
import XCTest
@testable import OpenFeelings

@MainActor
final class HistoryDateGroupingTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func makeNow() -> Date {
        // Fixed date: Saturday, May 10, 2026 14:00 UTC.
        var c = DateComponents()
        c.year = 2026; c.month = 5; c.day = 10
        c.hour = 14; c.minute = 0
        c.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: c)!
    }

    private func log(daysAgo: Int, hour: Int = 12, now: Date) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let l = FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: nil,
            note: ""
        )
        let day = calendar.date(byAdding: .day, value: -daysAgo,
                                to: calendar.startOfDay(for: now))!
        l.createdAt = calendar.date(byAdding: .hour, value: hour, to: day)!
        return l
    }

    // MARK: - Bucketing

    func testEmptyLogsProducesEmptyGroups() {
        XCTAssertTrue(HistoryView.groupByDay([], now: makeNow(), calendar: calendar).isEmpty)
    }

    func testLogsOnTheSameDayBucketIntoOneGroup() {
        let now = makeNow()
        let logs = [log(daysAgo: 0, hour: 9, now: now),
                    log(daysAgo: 0, hour: 15, now: now)]
        let groups = HistoryView.groupByDay(logs, now: now, calendar: calendar)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.logs.count, 2)
    }

    func testLogsOnDifferentDaysProduceSeparateGroups() {
        let now = makeNow()
        let logs = [log(daysAgo: 0, now: now),
                    log(daysAgo: 1, now: now),
                    log(daysAgo: 2, now: now)]
        let groups = HistoryView.groupByDay(logs, now: now, calendar: calendar)
        XCTAssertEqual(groups.count, 3)
    }

    func testGroupsAreSortedDescendingByDay() {
        let now = makeNow()
        // Input deliberately out of order to verify defensive sort.
        let logs = [log(daysAgo: 3, now: now),
                    log(daysAgo: 1, now: now),
                    log(daysAgo: 5, now: now)]
        let groups = HistoryView.groupByDay(logs, now: now, calendar: calendar)
        XCTAssertEqual(groups.map(\.day),
                       groups.map(\.day).sorted(by: >),
                       "Groups should be in descending day order")
    }

    func testLogsWithinAGroupRemainCreatedAtDescending() {
        let now = makeNow()
        let logs = [log(daysAgo: 0, hour: 9, now: now),
                    log(daysAgo: 0, hour: 18, now: now)]
        let groups = HistoryView.groupByDay(logs, now: now, calendar: calendar)
        XCTAssertEqual(groups.first?.logs.first?.createdAt,
                       logs.max(by: { $0.createdAt < $1.createdAt })?.createdAt,
                       "Most-recent log should be first within its day group")
    }

    // MARK: - Labels

    func testTodayBucketHasTodayLabel() {
        let now = makeNow()
        let groups = HistoryView.groupByDay([log(daysAgo: 0, now: now)],
                                            now: now, calendar: calendar)
        XCTAssertEqual(groups.first?.label, "Today")
    }

    func testYesterdayBucketHasYesterdayLabel() {
        let now = makeNow()
        let groups = HistoryView.groupByDay([log(daysAgo: 1, now: now)],
                                            now: now, calendar: calendar)
        XCTAssertEqual(groups.first?.label, "Yesterday")
    }

    func testOlderBucketHasFormattedDateLabel() {
        let now = makeNow()
        let groups = HistoryView.groupByDay([log(daysAgo: 3, now: now)],
                                            now: now, calendar: calendar)
        guard let label = groups.first?.label else {
            return XCTFail("Expected a group")
        }
        // Locale-dependent, so just assert it isn't Today/Yesterday and
        // contains a digit. That's enough to catch a "fell through to
        // empty string" regression.
        XCTAssertNotEqual(label, "Today")
        XCTAssertNotEqual(label, "Yesterday")
        XCTAssertTrue(label.contains(where: { $0.isNumber }),
                      "Older-day labels should include a day number")
    }
}
```

`Calendar(identifier: .gregorian)` ensures the test is locale-agnostic
for the bucketing math even though label formatting still uses the user's
locale.

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

Expected: BUILD SUCCEEDED + 210 + 8 new = 218 passing tests.

### Manual verification on iPad (A16) iOS 26.0.1

With at least 5 saved check-ins spanning at least 3 different days:

1. Open History. Cards group under day headers. The first header is
   "Today" (if today has a card) or "Yesterday" or the abbreviated date.
2. Within a day, the most-recent card appears first.
3. Apply a drill-down filter from Insights (e.g. tap "Happy" on By core).
   History opens filtered, and the day-group headers reflect *only* the
   days with matching logs.
4. Swipe-to-delete still works on a card inside a group. The deleted
   card disappears; if it was the day's only entry, the group header
   disappears too.
5. VoiceOver — section headers read as "Today, heading", "Yesterday,
   heading", etc. before each group's cards.

## Edge cases

- **DST transition.** `calendar.startOfDay(for:)` handles DST correctly;
  no special-casing required.
- **Empty after filter.** Existing `content`'s empty-state branch handles
  zero logs — no group headers render.
- **Single log all-time.** One group with one card, label "Today" or older
  depending on `createdAt`.
- **Very old logs spanning years.** The label format
  (`weekday().month().day()`) doesn't include year. If a user has logs
  from 2024 and 2025, both showing as "Mon, May 6" without a year would
  be slightly ambiguous — acceptable for v1, can revisit if it bites.

## Implementation order

1. Add `DayGroup` struct and `groupByDay(_:now:calendar:)` /
   `labelFor(day:today:yesterday:)` helpers in the existing
   `extension HistoryView` at the bottom of `HistoryView.swift`.
2. Add the test file. Run — all should pass.
3. Replace the flat `ForEach(logs)` with the grouped rendering in `content`.
   Preserve `.swipeActions(...)` and `.accessibilityAction(...)` on the
   inner card ForEach.
4. Build green. Run tests. Manual sim verify per checklist above.
5. Single feature commit.

## Out of scope

- Section header AX summary (e.g. "Today, 2 check-ins"). Could be a
  follow-up — useful, but not required.
- Sticky/pinned headers.
- Collapsible groups.
- Date pickers / calendar view.
- Configurable date format (defer to locale).
- Year display on multi-year-spanning logs.
