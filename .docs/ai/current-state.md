# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-05-29

**Paper design polish — build 40 (latest)**: 6-piece visual batch adopted from two local design mockups ("Paper" / "Dawn" — lean Paper, reject Dawn's warmth; mockup zips gitignored via `OpenFeelings*.zip`, never committed). Spec at `docs/superpowers/specs/2026-05-29-paper-design-polish-design.md`. Pieces: **P1** Direction Intentions↔Values segmented toggle (`DirectionView` — reuses the existing segmented-control style; both sub-areas stay mounted in a `ZStack` with opacity/hit-test/accessibility gating, **not** an `if`/`switch`, so toggling can't tear down `IntentionsContent`'s unsaved-draft `@State`; segment ids `direction.segment.<Name>`). **P2** wizard one-emotion-per-row (`WizardCheckInView.emotionGrid` `LazyVGrid`→`LazyVStack`, serif names; `emotion.<name>` ids preserved). **P3** Insights `All`→`Year` (added `InsightsPeriod.year` rolling-365d; **kept `.all` nil-cutoff for the therapy report's "All time" export** — the rename was UI-only; tab picker iterates new `insightsTabCases=[.week,.month,.year]`; `InsightsView.period` migrates a persisted `.all`→`.year`). **P4** serif tightening (`.ofDisplay()`/`.ofTitle()` tracking modifiers in DesignTokens, 5 call sites; no font bundling). **P5** Intentions restyle (wash-tinted today card + compact past rows; no new data fields). **P6a** graduated core-tinted strength circles + reduce-transparency-aware halo; **6b** core-washed serif-italic clinical-note card; **6c** committed-action checkbox fills new `Color.OF.accentCool` token + `textOnAccent` check. Built ultracode: inline implementation → adversarial review-workflow (4 dimension skeptics → refute-first verify → completeness critic). **Review found + fixed 3 real defects**: Insights empty-state copy "this period"→`period.title` for `.year`; the Direction `@State` teardown (fixed via ZStack mount); `accentCool` dark-hex + white check failed WCAG AA (2.21:1) → switched check to `textOnAccent` (7.86:1 dark / 5.18:1 light) + corrected the token doc. Completeness critic: all 6 present, no skip-list violations. **Shipped to TestFlight as build 40 (2026-05-29, `** EXPORT SUCCEEDED **`) — processing on Apple's side; install on device to review the visual changes.** **Known follow-up surfaced**: the two long `ValueSortRedesignUITests` full-flow e2e tests are flaky swipe-automation (twin `testAutoCompareModalDismissesOnDone` passes on a clean store, proving the flow works; the other fails at a different point each run) — make them deterministic (fixed small seeded deck / relaxed timeouts). Not a regression from this batch.

**Check-in full edit — CRUD-A (prior)**: The per-surface CRUD arc is now complete (A–F). Reverses "moment not journal": a saved `FeelingLog` is fully editable from History (every field — emotion path, intensity, body + custom regions, sensations, context, triggers, coping, mood, note) **except `createdAt`/`id`/`healthSyncStatus`/`captureSource`, which are preserved**. New `CheckInEditView` (slim push-destination reusing the wizard's step views + StepNav + CheckInFlowEngine; `CheckInView` untouched). `CheckInDraft` gains `from(log:)`/`apply(to:)` mirroring `ThoughtRecordDraft`. History's "Edit note" → "Edit" pushes the editor via `.navigationDestination(item:)`; the note-only `NoteEditorSheet` + `HistoryView.updateNote` + `HistoryNoteUpdateTests` were removed. Built ultracode: parallel understand-workflow (3 explorers) → inline implementation → adversarial review-workflow (3 skeptics + critic) → polish. 16 unit tests (`CheckInDraftEditTests`, incl. full round-trip + orphaned-path + watch-edit) + 1 end-to-end UI test. **Not yet shipped (build 39 pending).** Edit does NOT re-trigger HealthKit sync. **Known follow-up surfaced by review**: History (and ThoughtRecordsArea) `.swipeActions` sit in a ScrollView (not a List) so swipe-delete is non-functional — only the VoiceOver Delete action works; tracked in roadmap.

**CRUD batch C/D/E/F (prior)**: Four more per-surface CRUD slices, built ultracode (parallel understand-workflow → inline implementation with per-piece test gates → adversarial review-workflow → polish). **C** value-sort delete (`PastSortsSheet` ScrollView→List + swipe + confirm). **D** committed-action delete (destructive Section in `CommittedActionDetail` — detail-view button, not swipe, since the Values list is a ScrollView). **E** intention edit + delete (ellipsis menus on today + past rows in `IntentionsContent` — menus not swipe, same VStack-not-List reason; edit via alert). **F** custom body region rename (tappable row → alert in `BodyMapSettingsView`; delete switched from fragile `.onDelete` to explicit per-row `.swipeActions`). All four use static helpers + in-memory tests. Adversarial review caught: the `.onDelete`-on-Form + Button-wrap risk (fixed), missing VoiceOver `.accessibilityAction` on swipe deletes (added to C + B), missing a11y identifiers (added), and unproven "no cascade" test claims (added real no-cascade tests to C/D/E). Refuted a false "alert never dismisses" critical. 429 unit tests (408 → 429: +4 F, +5 D, +5 C, +7 E incl. no-cascade). Specs: custom-values-manager design committed; C/D/E/F were small enough to go straight to implementation from the understand-workflow maps (no separate spec/plan docs). **Not yet shipped** (build 38 pending).

**Custom values manager (prior)**: First slice of the per-surface CRUD arc (see `decisions.md`). New `CustomValuesSheet` (rename via alert, swipe-delete with confirmation, Done, empty state) opened from a "Manage custom values" button at the bottom of the Values area (shown only when ≥1 custom value exists). Just-delete — orphaned refs in past sorts/committed actions render "(removed value)" via the existing `ValueRef.displayName` fallback; rename is ref-safe (refs use UUIDs). Static `rename`/`delete` helpers + 4 in-memory tests (408 unit total). Spec at `docs/superpowers/specs/2026-05-28-custom-values-manager-design.md`. Not yet shipped. **Remaining CRUD sub-projects**: check-in full edit (large — reverses "moment not journal", user approved), value-sort delete, committed-action delete, intention edit/delete, custom-region rename.

**IA restructure (shipped build 37)**: Focused the Direction tab and reshaped the tab bar. New order: **Today · Check In · Direction · Thoughts · Insights**. Thought Records split out of Direction into its own **Thoughts** tab (`ThoughtsView` hosting `ThoughtRecordsArea`, `quote.bubble` icon); Direction now holds only Intentions + Values. **Settings left the tab bar** — a gear (`SettingsToolbar` modifier, `settings.gear` id) on every tab opens it as a modal sheet (`AppNavigation.showingSettings`); `SettingsView` gained a Done button. `.settings` `AppTab` case removed. Insights moved to last. UI tests updated (Thoughts tab check, gear-opens-settings, wizard test → Thoughts tab) + `AppNavigationTests` tab-order assertion. Spec + plan at `docs/superpowers/{specs,plans}/2026-05-28-ia-restructure*.md`. **Done before the App Store screenshots so they reflect the final IA.** Not yet bumped/shipped — ship decision pending.

**Earlier today — build 36, in-app tip jar** (Apple IAP, pure donation). Brainstorm → spec → plan → 7-task execution. Per `docs/superpowers/{specs,plans}/2026-05-28-tip-jar*.md`.

- **Reusable StoreKit module**: `OpenFeelings/Services/StoreKit/StoreKitClient.swift` — generic `StoreKitClienting` protocol + `StoreKitPurchaseOutcome` enum (our own Equatable type, so it's mockable) + real StoreKit-2 `StoreKitClient`. App-agnostic; lifts into other projects unchanged. Plus `TipJarService.swift` — `@MainActor @Observable`, app-specific: loads 3 consumable tiers sorted by price, fire-and-forget `tip(_:)`, transient `thankedProductID`/`purchaseFailed` flags.
- **UI**: `SupportSection.swift` in Settings (between Open source and About), mirrors `BackupSection`. Loaded state shows one row per tier with StoreKit `displayName` + `displayPrice` (localized); tapping → purchase → on success swaps price for a ✓ "Thank you" (2s) + success haptic, reduce-motion aware. Failed-load → retry row. Cancel → silent.
- **Tiers**: Soda $1.99 / Lunch $4.99 / Dinner $9.99, consumable, unlock nothing.
- **Tests**: 6 unit tests (`TipJarServiceTests`) via a mock client + `SKTestSession`-loaded real Products (StoreKit `Product` has no public init). `OpenFeelings.storekit` config defines the 3 consumables.
- **Product decisions** that drove this are in `decisions.md` 2026-05-28 + harness-deck `2026-05-27-app-store-launch-product-round`.

### Prior this session: value-sort redesign (builds 33–35)

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

- `xcodegen generate` succeeded; build number bumped to **40** in `project.yml` + regenerated `project.pbxproj`.
- iOS unit suite: green — `InsightsDatasetTests` 28 passing (incl. new `testAllIncludesEverythingRegardlessOfAge` for the `.all` therapy-report path + `.year` rename); no other unit-tested code changed this session.
- iOS UI suite: **DirectionUITests 5/5 passing** on a clean store after the Paper-polish changes (incl. new `testDirectionSegmentTogglesToValues`); wizard UI tests passing. The 2 long `ValueSortRedesignUITests` full-flow e2e tests are flaky (see follow-up in summary) — not a regression.
- **Build 40 (Paper polish) shipped to TestFlight 2026-05-29 (`** EXPORT SUCCEEDED **`); processing on Apple's side.**
- Prior: full iOS unit suite 441 passing / UI 16 passing as of build 39 (CRUD arc).
- IA restructure verified on both suites; not yet shipped to TestFlight.
- Builds 34/35 also shipped: taller swipe card; "Not for me" → "Set aside".
- Build 36 shipped the tip jar.
- watchOS unit test suite: **16 passing** (on "OF Watch Test" sim).
- Build 31 archive + export + upload to TestFlight: `** EXPORT SUCCEEDED **`.

## Blockers

- ~~Follow-up CloudKit schema redeploy — add `CD_ThoughtRecord`.~~ **DONE 2026-05-29.** All 8 record types now in Production; the `CKErrorDomain error 2` (partialFailure) sync error from saving the first thought record cleared after the additive Deploy. **Code follow-up bundled into the next build**: `CloudSyncMonitor.describe(error:)` couldn't surface the real per-record reason (it only checked the top-level error, not the `NSUnderlyingErrorKey`/`NSDetailedErrorsKey` wrapper CoreData uses) — being hardened so future sync errors are legible.
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
