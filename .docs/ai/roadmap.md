# Roadmap

> Durable goals and milestones. Updated when scope changes, not every session.

## Vision

Open Feelings is a free, local-first iOS app for private emotion check-ins using an attributed complete feelings wheel and a calmer guided wizard. Source code remains MIT licensed; the adapted emotion taxonomy is separately attributed and licensed.

## Now / Next / Later

<!-- Active items. Trim as completed; no claim markers — first agent to pick it up writes it. -->

### Now
- [x] Build the initial iOS app scaffold with wizard and wheel check-in flows.
- [x] Add local persistence, iCloud/CloudKit configuration, reminders, Face ID app lock, export, and optional Apple Health writing.
- [x] Replace the original taxonomy with an attributed Open Emotion Wheel v1.1 adaptation and color-coded wheel/wizard UI.
- [x] Add wheel pinch zoom, rotation, zoomed panning, and reset interactions.
- [x] Add clinically informed educational definitions for selected emotions.
- [x] Redesign: 5-tab IA scaffold, warm-calm design tokens, new components, Today/History/Settings re-skin, save-bounce ribbon, WCAG AA contrast audit + fixes, reduce-motion gating.
- [x] Direction tab — Intentions area + Values area (50-item curated deck + customs, bucket/finalist/rank sort flow, ranked-top persistence, CommittedAction lifecycle). Shipped in build 27.
- [x] Custom body regions — user-defined regions wired through check-in UI, learning pipeline (`LearnedBodyMap.customCounts/Totals`), and `BodyEmotionMap.suggestedCores(...)`. Shipped in build 27.
- [x] Apple Watch check-in target — drill picker with stop-at-any-level + body flow, NavigationStack with carried drill value, settings synced from iOS. Shipped across builds 21–26.
- [ ] Review the definition copy with the therapist or another licensed clinician before release.
- [ ] Configure production CloudKit schema and App Store distribution settings.
- [ ] Manual VoiceOver / AX5 / Reduce-Motion / Reduce-Transparency / Liquid Glass simulator walkthroughs (Daisy).
- [ ] Manual end-to-end verification of Direction tab + sort flow + committed actions on the TestFlight build (Task 13 of the Values plan).

### Next
- [x] App icon (light/dark/tinted 1024×1024 set already in place).
- [x] Launch branding (LaunchBackground color set with light + dark variants).
- [x] App Store privacy policy copy — `docs/PRIVACY.md` is canonical; `PrivacyPolicyView` in Settings → Privacy renders it in-app.
- [ ] Host `docs/PRIVACY.md` somewhere stable (GitHub Pages, project site, gist) and paste the URL into App Store Connect → App Privacy. The in-app effective date must match the hosted copy.
- [ ] Manually validate iCloud sync between two signed-in devices.
- [x] Review the Open Emotion Wheel attribution/license presentation before release.
- [ ] Add UI tests for the watch check-in flow, the Direction tab (Intentions + Values sort), and the export entry points.
- [x] Insights surface — functional (charts, trends, week/month views).
- [x] Therapy-bridge export (structured PDF / shareable summary for therapist sessions).
- [x] Richer check-in fields — data + UI (body, custom body regions, triggers/coping, mood scale).
- [x] Intentions surface — functional (set daily intentions, track completion). Lives on the Direction tab.

### Later
- [ ] Consider richer reflection prompts and Apple Health read/import support after v1 privacy review.
- [ ] Watch complication / standalone watch features (independent watch app, historical reads on watch).

## Milestones

### M1: Usable Local-First Check-In App
- [x] Attributed Open Emotion Wheel v1.1 taxonomy adaptation
- [x] Wheel and wizard input
- [x] Interactive wheel viewport gestures
- [x] Definition text for selected emotions
- [x] Local logs, export, reminders, app lock, and optional Apple Health writing

### M2: Release Readiness
- [ ] Signing, CloudKit production schema, privacy policy, app icon, manual sync QA

## Backlog

> Self-contained items any agent can execute. Each entry should include scope, file paths, acceptance criteria, verification steps, and a prose tier hint ("Haiku candidate", "Sonnet — multi-file", "needs Opus to scope").

<!-- Format example:
### Add foo to bar
**Scope**: …
**Files**: `path/to/file.ts:42`
**Acceptance**: …
**Verify**: `npm test -- foo`
**Tier hint**: Sonnet — touches 2 files, no design decisions
-->

<!-- Done 2026-05-09 — UI test target landed with `tab.<name>` identifiers on each tab Label and 4 passing smoke tests (cold-launch, tab-switch, wizard renders, Settings rows). Wizard "happy path through Save enabled" remains a v2 nice-to-have. -->

### VoiceOver labels for Today, History cards, and Wizard mode picker
<!-- Done 2026-05-10 — Today check-in cards/week summary, History LogCard content, and Wizard/Wheel mode picker now have cohesive VoiceOver labels/state. Added 7 unit tests for AX label helpers; full app + UI test suite passes. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-ax-labels-today-history-wizard-design.md`](../../docs/superpowers/specs/2026-05-10-ax-labels-today-history-wizard-design.md)
**Scope**: One coordinated AX pass adding `.accessibilityElement(children: .combine)` + `.accessibilityLabel(...)` to Today's check-in cards and week summary, History's per-card `LogCard`, and the Wizard/Wheel segmented picker in `FeelingStep`. ~10–15 small modifier additions plus a few unit tests for the static label helpers.
**Tier hint**: Haiku — pure pattern-matching against the convention already established in InsightsView's chart-level labels.

### Drill-down v2 — extend Insights tap-to-filter to By core, Body, Day-of-week
<!-- Done 2026-05-10 — By core, Body, and By day-of-week charts now drill into filtered History via new HistoryFilter cases. Added production filter helper coverage and display-label tests; full app + UI test suite passes. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-drill-down-v2-design.md`](../../docs/superpowers/specs/2026-05-10-drill-down-v2-design.md)
**Scope**: Three new `HistoryFilter` cases (`.coreID`, `.bodyRegion`, `.weekday`), corresponding predicates in `HistoryView`, and `chartOverlay { proxy in }` tap handlers on the three target charts mirroring the Top Feelings recipe. Adds ~8 unit tests for the new filter cases.
**Tier hint**: Sonnet — multi-file but pattern fully established by build 15's drill-down work.

### History — swipe-to-delete a check-in
<!-- Done 2026-05-10 — History cards now expose destructive swipe actions and VoiceOver delete actions behind the specified confirmation alert. Added in-memory SwiftData tests for delete persistence and idempotency; full app + UI test suite passes. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-history-swipe-to-delete-design.md`](../../docs/superpowers/specs/2026-05-10-history-swipe-to-delete-design.md)
**Scope**: Standard SwiftUI `.swipeActions` + confirmation alert on each `LogCard`, plus an `.accessibilityAction(named: "Delete")` for VoiceOver users. Refactor delete into a static helper `HistoryView.deleteLog(_:in:)` for testability; two unit tests using an in-memory ModelContainer.
**Tier hint**: Haiku/Sonnet — well-bounded SwiftUI mechanics, ~50 net lines.

### Unit tests for Insights chart summary strings
<!-- Done 2026-05-10 — Extracted chart-level VoiceOver summaries into `InsightsSummary` and added 15 unit tests covering empty, singular/plural, top-entry, intensity, body, and mood scatter cases. Full app + UI test suite passes. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-insights-summary-tests-design.md`](../../docs/superpowers/specs/2026-05-10-insights-summary-tests-design.md)
**Scope**: Backfill missing coverage on the chart-level `.accessibilityLabel(...)` summaries shipped in build 15. Extract the 5 inline `private var ...Summary: String` computed properties into a top-level `enum InsightsSummary { static func ... }`, swap the call sites, and add ~16 unit tests covering empty data, pluralization, and the busiest/most-felt/top-N selection logic. No UI or model change.
**Tier hint**: Haiku — tests-only deliverable with a mechanical refactor.

### Unit tests for TherapyReportPDFService page composition
<!-- Done 2026-05-10 — Replaced `makePages(for:)` with value-typed `TherapyReportPage` manifests plus renderer mapping. Added 13 UIKit-free page-composition tests; full app + UI test suite passes. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-therapy-report-page-composition-tests-design.md`](../../docs/superpowers/specs/2026-05-10-therapy-report-page-composition-tests-design.md)
**Scope**: Extract the private `makePages(for:) -> [AnyView]` page-builder into a pure value-typed `static func pages(for:) -> [TherapyReportPage]` + a small `view(for:report:)` renderer mapping. Add ~12 tests for the page-list shape across all three detail levels, with and without intentions, including the 5-per-page pagination math. No UIKit at test time.
**Tier hint**: Sonnet — tests-only deliverable plus the makePages refactor.

### History — group cards by date
<!-- Done 2026-05-10 — History now groups filtered logs under `OFSectionHeader` day buckets. Added `HistoryView.groupByDay(_:now:calendar:)` and 8 tests for bucketing, ordering, and labels; full app + UI test suite passes. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-history-date-grouping-design.md`](../../docs/superpowers/specs/2026-05-10-history-date-grouping-design.md)
**Scope**: Insert `OFSectionHeader`s between History cards so logs group under day-of-week headers ("Today", "Yesterday", "Thu, May 8"). Extract a static `groupByDay(_:now:calendar:)` helper and add ~8 tests for bucketing, sort order, and label resolution. Filter banner and swipe-to-delete already work alongside this — no regressions expected.
**Tier hint**: Sonnet — small UX feature + tested helper, ~80 net lines including tests.

### AXChartDescriptor for Top Feelings and By Core charts
<!-- Done 2026-05-10 — Top Feelings and By Core charts now expose AXChartDescriptorRepresentable chart details through a shared categorical bar descriptor builder. Added 7 descriptor-shape tests, including the SDK-safe empty-data placeholder case. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-ax-chart-descriptor-design.md`](../../docs/superpowers/specs/2026-05-10-ax-chart-descriptor-design.md)
**Scope**: Implement `AXChartDescriptorRepresentable` on the two highest-value Insights charts so VoiceOver's rotor exposes a "Chart Details" navigation item. Shared `barCategorical(title:items:)` builder + small per-chart wrappers. ~6 unit tests for descriptor shape (title, series count, data-point ordering). Other charts deferred.
**Tier hint**: Sonnet — Apple-specific AX API, structure is mostly mechanical once the API pattern is grasped.

### Wizard chip accessibility identifiers + smoke UI test
<!-- Done 2026-05-10 — Wizard chips now derive stable `chip.*` accessibility identifiers, the Body "Everywhere" control exposes the same identifier pattern and selected trait, and a UI smoke test verifies tapping a chip selects it. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-wizard-chip-identifiers-design.md`](../../docs/superpowers/specs/2026-05-10-wizard-chip-identifiers-design.md)
**Scope**: `OFChip` auto-derives an `.accessibilityIdentifier` from its label ("Chest" → `chip.chest`). Every chip in the wizard becomes XCUITest-targetable for future test coverage. Adds 6 unit tests for the identifier transform plus a UI smoke test that taps the Body Everywhere chip and asserts `.isSelected`.
**Tier hint**: Haiku — one-file change, predictable text transform, simple tests.

### History — edit the note on a saved check-in
<!-- Done 2026-05-10 — History cards now expose an inline Edit note affordance and VoiceOver action, presenting a reusable note editor sheet. Added in-memory SwiftData tests for note update, trim, clear, and idempotent missing-log behavior. -->
**Spec**: [`docs/superpowers/specs/2026-05-10-history-edit-note-design.md`](../../docs/superpowers/specs/2026-05-10-history-edit-note-design.md)
**Scope**: Add an "Edit note" swipe action and VoiceOver action on each History card. Tap → modal sheet with a TextEditor pre-filled with the current note; Save persists via `HistoryView.updateNote(_:to:in:)`. Note-only — emotion/intensity stay read-only by design (the moment, not the journal). 4 unit tests with an in-memory ModelContainer.
**Tier hint**: Sonnet — small feature, established sheet-binding pattern, schema unchanged.


- Emotion taxonomy content is adapted from Open Emotion Wheel v1.1 and must preserve Open Emotion Wheel attribution and CC BY-SA 4.0 licensing.
- Emotion definitions are original educational summaries with reference-source documentation; they must not be presented as diagnosis or treatment advice.
- No ads, analytics, accounts, servers, or third-party SDKs.
- Data remains on device and in the user's private iCloud database.
- Target latest SDK/iOS 26 for v1.
