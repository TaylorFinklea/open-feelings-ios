# Value sort — Tinder-style redesign + history surface

**Status:** approved (2026-05-27)
**Ships in:** build 33
**Related:** `2026-05-15-values-direction-tab-design.md` (the original Values area design)

## Why

The current bucket step in `SortFlowView` asks the user to tap one of three buttons per card (`Very important`, `Important`, `Not for me`). The user finds this UX unpleasant and wants a left/right swipe instead. They also want to see past sorts so they can observe how their values shift over time after a re-sort.

## Brainstorming decisions

Captured live in `~/.harness/reports/open-feelings-ios/2026-05-27-value-sort-redesign/` (harness-deck dashboard).

| Question | Answer |
|---|---|
| Post-swipe flow | Keep finalists + rank steps. Swipe replaces only the bucket UI. |
| Card stack feel | Peeking stack — 1–2 cards visible behind the active card. |
| Drag feedback | Tinder-style — tilt + color wash + `IMPORTANT` / `NOT FOR ME` stamp overlay past threshold. |
| Undo | Keep the existing Undo button. No new gesture. |
| History placement | Both: a `PastSortsSheet` accessed from a `Past sorts` button on the Values area, **and** a `SortComparisonView` auto-shown after Save. Same delta data model powers both. |

## What changes

Two new surfaces, one rewritten step view, one new value type, one tweak to the Values area on the Direction tab. No schema changes. No CloudKit deploy.

### Files to create

- **`OpenFeelings/Views/Direction/Values/Sort/SwipeBucketStepView.swift`** — replaces the role of the current `BucketStepView`. Peeking-stack card view with drag gesture, tilt, color wash, and stamp overlay past commit threshold. Right swipe calls `session.bucket(ref, into: .veryImportant)`. Left swipe calls `session.bucket(ref, into: .notForMe)`. Keeps the existing `Undo` button affordance (`session.undoLastBucket()`).
- **`OpenFeelings/Views/Direction/Values/History/SortDelta.swift`** — pure value type. `static func compute(prior: [String]?, current: [String]) -> SortDelta` returns `{ added: [String], removed: [String], moved: [(ref: String, from: Int, to: Int)] }`. Display-side resolves refs to names through the existing `ValueTaxonomy` / `CustomValue` lookups.
- **`OpenFeelings/Views/Direction/Values/History/PastSortsSheet.swift`** — modal `@Query`-driven list of `ValueSort` rows newest-first. Each row shows date + ranked top 5 names + delta strip vs the immediately-prior sort. Tap row → full detail (all buckets + full ranked list). Read-only — no delete affordance in this scope (a re-sort just appends a new row; old sorts stay for history).
- **`OpenFeelings/Views/Direction/Values/History/SortComparisonView.swift`** — side-by-side prior vs new ranked-top-5 with deltas inline. `+ Curiosity` in green for adds, `Work` struck-through in muted red for removals, `Health 2→5` chips for reorders. Buttons: `Done`, `View all past sorts`.

### Files to modify

- **`OpenFeelings/Views/Direction/Values/Sort/SortFlowView.swift`** — swap `BucketStepView` reference for `SwipeBucketStepView`. When the user taps Save on `ConfirmSortView`, `session.finalize(into:)` runs, the sort flow's `.sheet` dismisses, **and** a `@State` flag on `ValuesArea` flips true so a second `.sheet` (the auto-compare modal) presents `SortComparisonView` on the next render. The sheet-then-sheet sequence avoids modal stacking.
- **`OpenFeelings/Views/Direction/Values/ValuesArea.swift`** — add `Past sorts` button next to the existing `Re-sort` affordance when ≥1 prior `ValueSort` exists. Wire the post-save auto-compare modal presentation.

### Files to delete

- **`OpenFeelings/Views/Direction/Values/Sort/BucketStepView.swift`** — replaced entirely. The `SortBucket` enum case `.important` stays for backward compatibility with old `ValueSort` rows whose `bucketAssignmentsRaw` contains `.important` assignments.

## Data + model

No SwiftData schema changes. The existing `ValueSort` `@Model` is sufficient: `createdAt`, `bucketAssignments: [String: SortBucket]`, `rankedTop: [String]`.

The new behavior in `SwipeBucketStepView` only writes `.veryImportant` and `.notForMe` to `assignments`. The `.important` middle bucket is never produced by new code. Old rows that contain `.important` continue to render fine in `PastSortsSheet` — the list view doesn't distinguish between bucket types at all; the distinction only appears in the per-row detail page.

No CloudKit schema changes either — the `CD_ValueSort` record type and its fields are unchanged. The Production schema deployed 2026-05-24 already covers everything.

## Swipe mechanics — specifics

- **Threshold**: 30% of card width to trigger commit. Below threshold on release, card snaps back.
- **Tilt**: max ±12° at the threshold.
- **Color wash**: linear-gradient overlay at threshold opacity. Right → green `OF.accent`-shifted. Left → muted red.
- **Stamp overlay**: `IMPORTANT` (green) or `NOT FOR ME` (red), rotated 15°, fades in starting at 50% of threshold, fully opaque at threshold.
- **Commit animation**: card flies off-screen in swipe direction (~0.25s spring); next card in the peeking stack scales up to front position.
- **Haptic**: `.medium` `UIImpactFeedbackGenerator` on commit. None during drag.
- **Reduce-motion**: under `accessibilityReduceMotion`, card simply fades out (no fly-off animation); peeking stack still updates.
- **VoiceOver**: card exposes accessibility actions `Mark important` and `Mark not for me` so users who cannot perform drag gestures can still bucket via the rotor.
- **Undo**: existing Undo button stays in the toolbar / header (calls `session.undoLastBucket()`).

## SortDelta — computation rules

Comparing the current sort's `rankedTop` to the immediately-prior sort's `rankedTop`:

- **Added**: refs in `current` not in `prior` → green strip.
- **Removed**: refs in `prior` not in `current` → struck-through red strip.
- **Moved**: refs in both with different index → `Name from→to` chip.
- **Unchanged**: refs in both at same index → not in the delta strip (would be noise).

If `prior` is `nil` (the user's first sort), `added` = all of `current`, `removed` = `[]`, `moved` = `[]`. The display side decides whether to render the delta strip at all when there's no prior sort.

The full set of bucket assignments is *not* part of `SortDelta` — only ranked-top changes are user-facing in the history. Bucket-only changes (e.g., "Work moved from notForMe to veryImportant but didn't make ranked top") are invisible by design.

`SortDelta.moved` is sorted by `to` ascending; `added` is sorted by `current` index ascending; `removed` is sorted by `prior` index ascending.

## Tests

### New unit tests — `OpenFeelingsTests/SortDeltaTests.swift` (~12 tests)

1. `testEmptyPriorTreatsAllCurrentAsAdded`
2. `testIdenticalPriorAndCurrentReturnsEmptyDelta`
3. `testSingleAdded`
4. `testSingleRemoved`
5. `testSingleMovedRecordsFromAndToIndices`
6. `testMixedAddRemoveMoveInOneDiff`
7. `testReorderingWithinSameSetProducesOnlyMoved`
8. `testPriorLargerThanCurrent`
9. `testCurrentLargerThanPrior`
10. `testCustomValueRefsRoundTripThroughDelta`
11. `testAddedSortedByCurrentIndex`
12. `testRemovedSortedByPriorIndex`

### New UI tests — `OpenFeelingsUITests/ValueSortRedesignUITests.swift` (~3 tests)

1. `testSwipeSortHappyPathReachesAutoCompareModal` — opens sort flow, swipes a few cards right, advances through finalists + rank + save. Asserts the auto-compare modal appears.
2. `testAutoCompareModalDismissesOnDone` — taps Done → modal closes → Direction tab visible.
3. `testPastSortsSheetListsExistingEntries` — tap `Past sorts` button → sheet opens → at least one entry visible.

UI tests will use accessibility identifiers, not gesture coordinates, where possible — `XCUIElement.swipeLeft()` / `swipeRight()` on the card element is fine for testing the gesture itself, but per-step assertions target `accessibilityIdentifier`s.

### Existing tests to adjust

- `DirectionUITests.testSortFlowOpensBucketStep` asserts on the `Very important` button which won't exist. Replace with assertion on the new swipe card's accessibility identifier (`value-sort.card`).
- All `SortSession`-touching unit tests should still pass unchanged — the model layer didn't change.

## Build sequence

Order so each step compiles cleanly and tests pass:

1. **Add `SortDelta` + unit tests** (red → green). Safe in isolation.
2. **Add `PastSortsSheet`** (uses `SortDelta`). Modify `ValuesArea` to expose the `Past sorts` button. Defer wiring the auto-compare until the swipe step lands.
3. **Add `SwipeBucketStepView`**. Wire into `SortFlowView` replacing `BucketStepView`. Adjust the `DirectionUITests` assertion. Delete `BucketStepView.swift`.
4. **Add `SortComparisonView`**. Wire post-save presentation in `SortFlowView` / `ValuesArea`.
5. **Add the new UI tests.**
6. **Run full test suite + `xcodegen` + manual smoke**.

Ship as **build 33**. No CloudKit deploy required.

## Out of scope

- Changing the `SortBucket` enum (`.important` case stays for backward compatibility).
- Changing the finalists or rank steps in any way.
- Changing the `ValueSort` SwiftData model or `CD_ValueSort` CloudKit schema.
- Animations or onboarding hints for first-time swipe users (revisit after dogfooding build 33).
- Tweaking the curated value taxonomy.
- Deleting individual `ValueSort` rows from history (build 34 candidate if list ever feels cluttered).

## Open questions resolved during brainstorm

None outstanding. See the harness-deck report's brainstorming history for the path taken.
