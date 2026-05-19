# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-05-19

Multi-session arc: builds 28, 29, 30 to TestFlight. Major changes:

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
- Full iOS unit test suite: **376 passing** (343 → 376, +33 for thought
  records + stop-at-any-level + CloudKit sync error mapping).
- Full iOS UI test suite: **11 passing**.
- watchOS unit test suite: **16 passing** (on "OF Watch Test" sim).
- Build 30 archive + export + upload to TestFlight: `** EXPORT SUCCEEDED **`.

## Blockers

- **CloudKit Production schema needs redeploy.** Builds 21–30 added six
  new `@Model` types and new fields on `FeelingLog`. Existing TestFlight
  installs (including on iPad) silent-fail to mirror these to iCloud
  with `CKError.partialFailure`. The "iCloud sync" row in Settings →
  Privacy on build 30 will surface the real cause (e.g., "Did not find
  record type: CD_ThoughtRecord") instead of the useless top-level
  error. Walkthrough is in `docs/release/cloudkit-production-deployment.md`.
- Manual on-device verification of the Thought records wizard pending
  (Task 14's step 2 manual smoke).
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
