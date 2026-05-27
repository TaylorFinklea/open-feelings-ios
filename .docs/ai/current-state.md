# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-05-27

Shipped build 33 with the value-sort Tinder-style redesign + sort history. Built per `docs/superpowers/specs/2026-05-27-value-sort-tinder-redesign-design.md` and the matching plan; brainstormed via the harness-deck dashboard.

- **Bucket step**: replaced the 3-button `BucketStepView` with `SwipeBucketStepView` — peeking-stack card view, drag gesture, 30%-of-width commit threshold, ±12° tilt, green/red color wash, `IMPORTANT`/`NOT FOR ME` stamp overlay past threshold, medium-impact haptic on commit, reduce-motion fallback (no fly-off animation), VoiceOver custom actions `Mark important` / `Mark not for me` for users who can't drag. Right swipe → `.veryImportant`; left → `.notForMe`. The `.important` middle bucket enum case stays for backward-compat with old `ValueSort` rows but new code never writes it.
- **Sort history**: new `PastSortsSheet` (modal list of every `ValueSort` newest-first, each row with date + ranked top 5 + delta strip vs prior sort), new `SortComparisonView` (side-by-side prior vs new ranked top after a re-sort save), new `SortDelta` value type (added / removed / moved) that powers both. ValuesArea exposes a `Past sorts` button next to `Re-sort` when ≥1 prior sort exists; the auto-compare modal sequences via sheet-then-sheet after Save.
- **Tests**: 13 new unit tests for `SortDelta` (398 total, +13), 3 new UI tests in `ValueSortRedesignUITests` (15 total, +3 — plus the `testSortFlowOpensBucketStep` rename → `testSortFlowOpensSwipeStep` and a swipe-based update to `testBucketAdvancesProgressAndUndoRestoresIt`).
- **No schema changes** — `ValueSort` SwiftData model + `CD_ValueSort` CloudKit schema unchanged. No follow-up CloudKit deploy needed.

### Prior multi-session arc (builds 28–32)

CloudKit Production schema redeploy across sessions 2026-05-23 → 2026-05-27. M2 sync blocker resolved on TestFlight build 31 with **no code changes**:

- **Schema deploy**: Promoted Development → Production via the CloudKit Console runbook (`docs/release/cloudkit-production-deployment.md`). Diff was strictly additive: 6 new record types (`CD_CommittedAction`, `CD_CustomBodyRegion`, `CD_CustomValue`, `CD_Intention`, `CD_UserBodyMap`, `CD_ValueSort`), 9 new fields on `CD_FeelingLog` (`CD_intensity`, `CD_triggersRaw`, `CD_copingRaw`, `CD_moodEnergy`, `CD_moodValence`, `CD_contextPeopleRaw`, `CD_contextPlacesRaw`, `CD_customBodyRegionIDsRaw`, `CD_captureSource`), 0 deletions, 0 type changes. SwiftData on iOS 26 auto-provisioned QUERYABLE/SEARCHABLE/SORTABLE on every field at write time, so the manual index step in the runbook is no-op now.
- **Production schema was even staler than the runbook claimed**: prior production had only `CD_FeelingLog` (with the original 13 fields, no intensity!) + `Users`. Every check-in's intensity, mood scale, triggers, coping, and context had been silent-failing to sync on TestFlight installs for many builds.
- **`CD_ThoughtRecord` deferred** to a follow-up additive deploy. See `decisions.md` 2026-05-23 entry. Blocked by an iOS 26 SwiftUI bug discovered while populating the Development schema (next item).
- **ThoughtRecord wizard bug discovered and fixed (2026-05-27)**: Confirm step was rendering every draft field empty even after the user typed in every step, because `ThoughtRecordFlowView` was the only wizard using `NavigationStack(path:)` + `.navigationDestination(for: Step.self)` with a value-type `@State var draft` — a combination iOS 26's SwiftUI runtime silently breaks. Converted `ThoughtRecordDraft` from `struct` to `@Observable final class` (matching `SortSession`'s pattern), step views from `@Binding` to `@Bindable`, and added a frozen `ThoughtRecordDraft.Snapshot` for the cancel-confirm dirty check. Added `OpenFeelingsUITests/ThoughtRecordWizardUITests.swift` — a full wizard happy-path end-to-end test. **Why this slipped through**: the 33 existing unit tests covered the struct's logic but never exercised the SwiftUI binding plumbing. Decisions log entry at `decisions.md` 2026-05-27.
- **Two-device sync verification passed** on 2026-05-27. Forward sync (A→B), reverse sync (B→A), and offline-queue-and-replay all worked within ~60s per record. Settings → Privacy → iCloud sync row went from `exclamationmark.icloud` to green `checkmark.icloud`.

### Prior multi-session arc (builds 28–31)

- **Local backup + restore (build 31)**: New `BackupService` writes every

- **Local backup + restore (build 31)**: New `BackupService` writes every
  SwiftData `@Model` (FeelingLog, Intention, UserBodyMap,
  CustomBodyRegion, CustomValue, ValueSort, CommittedAction,
  ThoughtRecord) into a single JSON envelope via flat per-model Codable
  mirrors. Import is merge-only with per-type dedup: UUID id for most
  types, start-of-day date for Intention, singleton-skip for UserBodyMap.
  Schema-versioned envelope; imports refuse higher versions with a clear
  error. UI: new Settings "Backup" section between Privacy and Reminders
  with Export + Import rows, confirmation alert listing per-type counts,
  summary alert after with "Imported N new, skipped M already-present"
  breakdown. 9 new unit tests. **Purpose: defensive checkpoint before the
  CloudKit Production schema redeploy** — user can export the phone's
  state, do the deploy, and restore if anything goes sideways.

### Prior multi-session arc (builds 28–30)

- **CBT Thought Records (build 30)**: New `@Model` `ThoughtRecord` + 8-case
  `ThinkingPattern` enum + value-type `ThoughtRecordDraft`. Burns-style
  6-step wizard (situation → automatic thought → intensity-before →
  thinking patterns → balanced thought → intensity-after) plus confirm
  step. Wizard hosts via `NavigationStack` path routing, cancel-confirm
  alert with `Equatable` dirty-check, edit re-enters wizard with
  `existingRecord` pre-fill. New Direction tab area
  (`ThoughtRecordsArea`) below Intentions + Values, with empty hero and
  swipe-delete. `ThoughtRecordDetail` shows intensity-shift visual +
  linked-log footer. `LogCard` share menu (HistoryView) gains "Examine
  this thought" which pre-fills situation + intensity-before from the
  source `FeelingLog`. 33 new unit tests. Design + plan committed at
  `docs/superpowers/specs/2026-05-18-cbt-thought-records-design.md` and
  `docs/superpowers/plans/2026-05-18-cbt-thought-records.md`.
- **Stop-at-any-level on iOS check-in (build 30)**: Matched the watch
  app's existing UX. `EmotionSelection.isComplete` relaxed to always
  true (core is non-optional). `FeelingLog.emotionTitle` falls through
  to coreName so core-only entries (from watch or new iOS path) don't
  render blank headlines. `WizardCheckInView` gains "Just <Core>" /
  "Just <Secondary>" affordances above each drill grid plus a
  confirmation card when taken. 7 new tests.
- **CloudKit sync error surface (build 29)**: New `CloudSyncMonitor`
  @Observable @MainActor that watches
  `NSPersistentCloudKitContainer.eventChangedNotification`. Settings →
  Privacy gains an "iCloud sync" row with `checkmark.icloud` /
  `exclamationmark.icloud` glyph and a real status line. Build 29
  refined the row to extract `CKError.partialFailure`'s per-record
  sub-errors so users see "Did not find record type: CD_ValueSort"
  instead of "The operation couldn't be completed". 17 unit tests
  cover the apply() state machine + describe() error mapping.
- **Watch glyph (build 28)**: `FeelingLog.captureSource == "watch"`
  entries now show an `applewatch` SF symbol on Today + History rows
  with "From Apple Watch" VoiceOver label. 2 new AX tests.
- **watchOS unit test target (build 28)**: New `OpenFeelingsWatchTests`
  bundle with 16 unit tests over `CheckInWizardState` and
  `WatchSettingsStore`. Run with the `OpenFeelingsWatch` scheme on a
  watchOS sim — note that the original "Open Feelings Watch" sim
  rotted; created "OF Watch Test" (Apple-Watch-Series-11-42mm).
  watchOS XCUITest is too unreliable on Xcode 16 to use; unit
  coverage of the @Observable state classes is the durable path.
- **Direction tab UI tests (build 28)**: 5 new XCUITests covering
  section headers, sort affordance, bucket step opens, bucket advance
  + Undo round-trip, Cancel dismisses. Defensive against persistent
  simulator data.
- **Privacy policy reconciliation**: Three artifacts (repo-root
  PRIVACY.md, web/src/routes/privacy/+page.svelte, in-app
  PrivacyPolicyView) now share the same May 16, 2026 copy. Adds
  disclosure for value sorts, committed actions, custom regions/values,
  Apple Watch, triggers/coping/mood, full export menu, therapy PDF,
  journal handoff. Drops app-lock language since the feature is
  flag-gated off.
- **CloudKit production runbook refresh**: All eight current @Model
  types documented in `docs/release/cloudkit-production-deployment.md`
  with their queryable indexes. Top-of-file warning flags the silent
  sync failure on existing TestFlight installs until production
  schema is redeployed.

## Build Status

- `xcodegen generate` succeeded.
- Full iOS unit test suite: **398 passing** (was 385; +13 for `SortDeltaTests`).
- Full iOS UI test suite: **15 passing** (was 12; +3 for `ValueSortRedesignUITests`).
- watchOS unit test suite: **16 passing** (on "OF Watch Test" sim).
- Build 31 archive + export + upload to TestFlight: `** EXPORT SUCCEEDED **`.

## Blockers

- **Follow-up CloudKit schema redeploy — add `CD_ThoughtRecord`.** Build 32 shipped the wizard fix; once that's installed on a real device and a thought record is saved, refresh the CloudKit Console Development schema, add `CD_createdAt` Queryable index on `CD_ThoughtRecord`, and Deploy Schema Changes. Additive — should be a 1-type + 1-index diff.
- Manual VoiceOver / AX5 / Reduce-Motion / Reduce-Transparency / Liquid
  Glass simulator walkthroughs still pending (Daisy).
- App Store / device distribution still needs the production CloudKit
  schema deploy + two-device sync validation. Reproducible via the
  in-app sync row once the schema is up.
- The in-app definitions are educational and clinically informed but
  have not been reviewed by a licensed clinician.
- **iOS 26 Liquid Glass tab bar AX quirk**: selected tab cells don't
  expose `accessibilityIdentifier` to XCUITest until the user
  interacts with the bar. Cold-launch UI test was refactored to check
  for the time-of-day greeting static text instead of tab.today. Other
  UI tests are unaffected (they tap tabs which populates the AX tree).
