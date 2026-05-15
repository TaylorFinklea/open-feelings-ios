# Values — Direction Tab Design

## Context

The therapist gave two complementary pieces of guidance:

1. Help users figure out **what they actually value** through a structured sort (an ACT-style value card sort), then keep those values visible.
2. Encourage users to take **committed actions** in the direction of those values, even — especially — when the action feels hard. His framing: "things you don't want to do but align to value; we avoid, so don't do it. Don't have purpose, so don't do it."

Open Feelings today has a daily `Intentions` tab (set today's intention + look back + reflect). Intentions are a different rhythm and a different abstraction from values: they're a one-day commitment, not a stable compass. This design adds a values surface alongside Intentions, sharing the same tab so we don't burn one of the five tab slots.

This is a single, well-scoped feature for one implementation plan. Sort flow + Values area + Committed actions are tightly coupled; the data models are mutually dependent; the IA change touches one tab. Shipping it as one slice is appropriate.

## Goals

- Let the user do a one-sitting value sort that produces a ranked top 5–10.
- Surface those values, persistently, in the renamed **Direction** tab.
- Let the user create **committed actions** — concrete things they intend to do — each tied to one value, each with an optional "what's hard about it" note and an optional post-completion reflection.
- Allow the user to re-sort later without losing prior committed actions.
- Keep the existing daily Intentions surface unchanged — same code, same behavior, just one area inside a renamed tab.
- Stay standalone: no cross-wiring with feeling logs in v1. Proven first; integrated later if it earns it.

## Non-goals

- No connection to check-ins, body regions, or Insights. Specifically: completing a committed action does **not** prompt a check-in.
- No values lens on existing charts.
- No notifications, reminders, or streaks around actions.
- No editing of a confirmed `ValueSort`'s rankings — to change rankings, you re-sort.
- No multi-day or resumable sort flow in v1: progress is held in memory; leaving the flow restarts it.
- No sharing or export of values/actions in this slice (would naturally fold into the existing therapy-bridge export feature later).
- No watchOS surface for values in v1.

## Locked design decisions (from brainstorming)

| # | Decision |
| --- | --- |
| 1 | **Rhythm:** hybrid — occasional re-sort, persistent active committed actions. |
| 2 | **Deck source:** curated taxonomy of ~50 values + user-added custom values. |
| 3 | **Action model:** committed actions are fully separate from daily Intentions. |
| 4 | **Tab placement:** rename **Intentions** tab → **Direction**, two areas inside: Intentions (unchanged) and Values. |
| 5 | **Action fields:** avoidance-aware, one-time — `title`, `valueRef`, `whatsHard`, `isDone`, `completedAt`, `reflection`. |
| 6 | **Sort output:** three buckets, then narrow to ranked top 5–10. |
| 7 | **Phase 1 interaction:** tap-to-bucket, one card at a time, with Undo. |
| 8 | **Phase 2 interaction:** two-step — pick ~10 finalists from the "Very important" pile, then drag to rank. |
| 9 | **Integration with feelings data:** standalone — no cross-wiring in v1. |

## Architecture

### Information architecture

`Direction` tab content is split into two sections inside `DirectionView`:

- **Intentions** — the existing `IntentionsView` content, lifted into a subview unchanged. Today's editor + look-back + reflection all stay identical.
- **Values** — empty-state prompt to sort, or (post-sort) the ranked list + committed-actions list + re-sort affordance.

The tab is renamed at the `AppTab` enum: `case intentions` → `case direction`, `title` → `"Direction"`, `systemImage` keeps `leaf` for now (icon choice is intentionally separate from the rename; can iterate later).

### Data models

**One static struct + three new SwiftData `@Model` types.** All `@Model` types ride the existing `NSPersistentCloudKitContainer` (private DB `iCloud.dev.finklea.openfeelings`), per the same pattern as `Intention` and `CustomBodyRegion`. New properties have default values so SwiftData lightweight migration applies.

#### `ValueTaxonomy` (static; shipped in code)

Mirrors `EmotionTaxonomy`'s shape. ~50 curated values adapted from an established ACT card sort (e.g. Bond / Hayes "Personal Values Card Sort"). Each entry has:

```swift
struct ValueDefinition: Hashable, Sendable {
    let id: String          // stable slug, e.g. "family", "honesty"
    let name: String        // "Family", "Honesty"
    let description: String // one-line plain-language description
}

enum ValueTaxonomy {
    static let all: [ValueDefinition]
    static func definition(id: String) -> ValueDefinition?
}
```

The taxonomy is **append-only**: once an id is shipped, it never changes meaning. Removing or renaming a curated value would orphan committed actions in the field. Adding new ids is fine; the new ones simply appear in the next sort.

#### `CustomValue` (`@Model`)

User-added values. Mirrors `CustomBodyRegion` exactly.

```swift
@Model
final class CustomValue {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, createdAt: Date = Date())
}
```

#### `ValueSort` (`@Model`)

One completed sort run. The **newest sort** by `createdAt` is the active sort; older ones are kept as read-only history.

```swift
@Model
final class ValueSort {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    /// JSON-encoded `[String: String]`: valueRef -> "veryImportant" | "important" | "notForMe".
    /// Stored as String for CloudKit safety, decoded on access.
    var bucketAssignmentsRaw: String = "{}"

    /// JSON-encoded `[String]`: ordered finalists, position 0 = #1 ranked.
    var rankedTopRaw: String = "[]"

    init(id: UUID = UUID(), createdAt: Date = Date(),
         bucketAssignments: [String: SortBucket] = [:],
         rankedTop: [String] = [])
}

enum SortBucket: String, Codable {
    case veryImportant, important, notForMe
}

extension ValueSort {
    var bucketAssignments: [String: SortBucket] { /* decode/encode bucketAssignmentsRaw */ }
    var rankedTop: [String] { /* decode/encode rankedTopRaw */ }
}
```

**Why string-keyed JSON instead of typed arrays of related `@Model`s?** CloudKit-backed SwiftData penalises chatty relationships; the bucket map and ranked list are read together or not at all; a single sort writes ~50 entries. One row per sort with two String blobs is simpler, matches `bodyRegionsRaw` precedent on `FeelingLog`, and avoids cascade-delete cliffs.

**Value reference format:** `"family"` for curated values (the `ValueDefinition.id`), `"custom:<uuid-string>"` for custom values. A small `ValueRef` helper resolves either form into a display name.

#### `CommittedAction` (`@Model`)

A concrete thing the user has committed to doing, tied to one value.

```swift
@Model
final class CommittedAction {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var title: String = ""
    var valueRef: String = ""        // "family" or "custom:<uuid>"
    var whatsHard: String = ""       // optional; empty if not provided
    var isDone: Bool = false
    var completedAt: Date?           // set when isDone flips true
    var reflection: String = ""      // optional; written after marking done

    init(id: UUID = UUID(), createdAt: Date = Date(),
         title: String, valueRef: String,
         whatsHard: String = "")
}
```

`CommittedAction` is intentionally **not** linked to `ValueSort` — actions persist across re-sorts. If a re-sort drops the value an action references, the action shows "(not in current values)" in its row rather than disappearing.

### View structure

#### New views

| Path | Purpose |
| --- | --- |
| `Views/Direction/DirectionView.swift` | Tab root; two scrolling sections (Intentions, Values). Renders existing `IntentionsContent` and new `ValuesArea`. |
| `Views/Direction/Intentions/IntentionsContent.swift` | Lifted body of today's `IntentionsView` — moved as-is, no logic change. |
| `Views/Direction/Values/ValuesArea.swift` | Empty-state or active-set list + re-sort + committed actions list. |
| `Views/Direction/Values/CommittedActionRow.swift` | Single row: title, value name, ☐/☑, dimmed when done. |
| `Views/Direction/Values/CommittedActionDetail.swift` | Detail view: title, value, "what's hard", Mark done button, post-done reflection editor. |
| `Views/Direction/Values/CommittedActionEditor.swift` | Sheet: create or edit a committed action — title, value picker (active ranked list + "any value"), whatsHard. |
| `Views/Direction/Values/Sort/SortFlowView.swift` | NavigationStack hosting the four-step sort. Owns `SortSession` (`@Observable` class). |
| `Views/Direction/Values/Sort/BucketStepView.swift` | Bucketing — one card at a time, three big buttons + Undo + "+ add your own value". |
| `Views/Direction/Values/Sort/FinalistsStepView.swift` | Pick finalists — Very important pile as chips; tap to toggle finalist; cap at 10. |
| `Views/Direction/Values/Sort/RankStepView.swift` | Rank — finalists in a `List` with `.onMove` to drag-reorder. |
| `Views/Direction/Values/Sort/ConfirmSortView.swift` | Confirm — preview ranked list, confirm → writes `ValueSort`, dismisses. |

#### Modified views

| Path | Change |
| --- | --- |
| `Design/AppNavigation.swift` | Rename `case intentions` → `case direction`; update `title`, `systemImage`. `AppTab` is in-memory only (`AppNavigation` is `@Observable`, not persisted), so the rename is purely compile-time. |
| `Views/RootView.swift` | Replace `IntentionsView()` mount with `DirectionView()`; update `accessibilityIdentifier` `"tab.intentions"` → `"tab.direction"`. |
| `OpenFeelingsApp.swift` | Update `Schema(...)` to `Schema([FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self, CustomValue.self, ValueSort.self, CommittedAction.self])`. |
| `Views/IntentionsView.swift` | Becomes the body of `IntentionsContent.swift`. The existing file is deleted after the move; nothing else imports it directly. |

### `SortSession` — owning the in-flight sort

`@Observable` class held in `@State` by `SortFlowView`. It is **not** a SwiftData model — it holds in-memory progress that is discarded on cancel and written to `ValueSort` only on confirm.

```swift
@MainActor
@Observable
final class SortSession {
    enum Phase { case bucketing, pickingFinalists, ranking, confirming }

    private(set) var phase: Phase = .bucketing
    private(set) var deck: [String]              // valueRefs to bucket; mutated as we go
    private(set) var index: Int = 0              // current card pointer into a snapshot order
    private(set) var assignments: [String: SortBucket] = [:]
    private(set) var finalists: [String] = []    // chosen from Very important
    private(set) var ranked: [String] = []       // ordered finalists

    init(curated: [ValueDefinition], custom: [CustomValue])

    func bucket(_ ref: String, into: SortBucket)
    func undoLastBucket()
    func addCustomValue(name: String, store: ModelContext) -> String   // returns new ref
    func advancePhase()
    func toggleFinalist(_ ref: String)            // cap at 10
    func reorderRanked(from: IndexSet, to: Int)
    func finalize(into context: ModelContext)     // writes ValueSort, no-op if invalid
}
```

The undo stack is single-step (last bucket assignment only) — enough to recover from a mis-tap, simple enough to not need its own UI.

### Sort flow — screen by screen

1. **Bucketing.** Big card centered on screen showing one value's name and one-line description. Three tappable buttons below — **Very important**, **Important**, **Not for me** — each in a clearly distinct visual weight (filled / outlined / muted). An **Undo** button reverses the last assignment. An **+ Add your own value** affordance opens a small sheet: TextField + Cancel/Add; on Add, creates a `CustomValue`, appends its ref to the remaining deck, returns to bucketing. Progress indicator shows `n of m`. No back-navigation between buckets; the deck is consumed in a fixed snapshot order.

2. **Pick finalists.** All values bucketed as "Very important" rendered as toggleable chips. Tap to add a check; tap again to remove. Cap at 10 finalists — when 10 are selected, additional taps shake/refuse with a brief note ("Pick up to 10"). Minimum 1 finalist to advance. Header shows `n / 10`. **If the "Very important" pile is empty** (the user bucketed nothing into it), this screen renders a fallback: "No values marked Very important — restart the sort to try again", with a single **Restart sort** button that resets `SortSession` to a fresh bucketing pass. No fallback to the "Important" pile in v1; this case is rare and the explicit restart is clearer than a silent demotion.

3. **Rank.** Finalists shown in a `List` with `.onMove`. Drag rows to reorder. Position 1 at the top. No filter, no editing of which values are in the list — that decision was made in the previous screen.

4. **Confirm.** Read-only preview of the ranked list. Tap **Confirm** → writes a new `ValueSort` with `bucketAssignments` from `SortSession.assignments` and `rankedTop` from `SortSession.ranked`. Dismiss back to the Values area, which now reads the new active sort.

Cancel from any step → discard `SortSession`, no write.

### Values area, after a sort exists

`ValuesArea` reads the **newest** `ValueSort` via `@Query(sort: \.createdAt, order: .reverse)` and takes the first. From it:

- A **YOUR VALUES** section: ranked list of `rankedTop[]`, rendered via `ValueRef.displayName(...)`, each row tappable to a small read-only definition sheet.
- A **Re-sort** button → presents `SortFlowView`.
- A **COMMITTED ACTIONS** section: `@Query(sort: \.createdAt, order: .reverse)` over `CommittedAction`, rendered as `CommittedActionRow`. Done actions remain in the list, dimmed.
- A **+** button → presents `CommittedActionEditor` for create.

Tapping a row navigates to `CommittedActionDetail`:

- Reads title, "Serves: \(valueName)", "What's hard about it" (if present).
- If `!isDone`: **Mark done** button → sets `isDone = true`, `completedAt = .now`. After done, reveals a **Reflection** TextField with placeholder "How did it go?".
- If `isDone`: completed-state header, "Done on \(date)", reflection editor inline.

Editor sheet (`CommittedActionEditor`) lets the user pick a value from: the active sort's `rankedTop` first (primary list), then a disclosure to "All your values" (full union of curated + custom; lets the user attach an action to any value, even one they bucketed out — by design, since the therapist's framing is exactly about acting on values you've been avoiding).

### Empty states

| State | UI |
| --- | --- |
| No `ValueSort` exists | Values area shows headline ("Your values, on your terms"), one-paragraph copy, primary button **Start the sort**. Committed actions section hidden. |
| Sort exists, no actions | YOUR VALUES list visible; COMMITTED ACTIONS section shows muted "No committed actions yet. Tap + to add one." |
| Action references a dropped value | Row renders as `"\(title) — (not in current values)"`, dimmed even if not done. Detail screen still works; valueRef text is preserved for posterity. |

### Re-sort behavior

Tapping **Re-sort** opens `SortFlowView` fresh. On confirm, a **new** `ValueSort` is appended. The active sort is always "newest by createdAt"; the older one is automatically demoted to history. There is no UI surface for browsing prior sorts in v1 (the data is preserved, just not exposed — a small "History" affordance could come later if useful). Committed actions are untouched.

## Edge cases

- **First-launch on a phone with no sort:** Values area renders empty state. The renamed Direction tab still shows the existing Intentions content above it.
- **CloudKit conflict on a `ValueSort` row:** SwiftData/CloudKit last-writer-wins per field. Both `bucketAssignmentsRaw` and `rankedTopRaw` are full snapshots, so any merge resolution still yields an internally-consistent sort. Acceptable.
- **A `CustomValue` is deleted after a sort references it:** The sort retains `"custom:<uuid>"` strings; `ValueRef.displayName(...)` falls back to `"(removed value)"`. Same fallback if the curated taxonomy ever orphaned an id (which it won't, by the append-only rule).
- **Re-sort interrupted mid-flow:** App backgrounded or sort dismissed → `SortSession` is discarded. No partial state survives; user starts fresh next time. v1 nicety, not a v1 bug.
- **The user adds the same custom value twice:** `CustomValue.name` is not unique; trimming happens at creation, but two equally-trimmed names produce two rows. v1: acceptable; the sort treats them as distinct values. Add dedupe later if it shows up in feedback.
- **iCloud sync of a `ValueSort` to a device that doesn't have the matching `CustomValue` yet:** `ValueRef.displayName(...)` shows `"(syncing…)"` if `custom:<uuid>` doesn't resolve; resolves on the next view appear after the `CustomValue` row arrives. CloudKit eventual consistency is the expected behavior here.
- **Reduce Motion:** drag-to-reorder in Phase 2b uses the system `EditMode` mechanism, which already honors Reduce Motion. No custom animation introduced.
- **Dynamic Type at AX5:** Phase 1 buttons stack vertically on narrow widths and at large Dynamic Type — already the default for `Button { … } label: { Label(...) }` patterns used elsewhere in the app. Verified manually during build.

## Testing

XCTest (project convention). New file: `OpenFeelingsTests/ValuesTests.swift`. Cover the pure-logic surface; UI tests are deferred.

| # | Test | What it pins |
| --- | --- | --- |
| 1 | `testValueSortJSONRoundTripPreservesBucketAndRanking` | bucketAssignmentsRaw / rankedTopRaw encode/decode losslessly, including mixed curated + custom refs. |
| 2 | `testValueRefDisplayNameResolvesCuratedAndCustom` | `ValueRef.displayName` handles `"family"`, `"custom:<uuid>"` (existing), and `"custom:<missing-uuid>"` (fallback string). |
| 3 | `testSortSessionAdvanceRefusesWhenBucketingIncomplete` | `advancePhase` is a no-op while the deck has unbucketed cards. |
| 4 | `testSortSessionFinalistsCappedAtTen` | `toggleFinalist` past 10 leaves finalists unchanged. |
| 5 | `testSortSessionUndoRevertsLastBucket` | last assignment removed, deck index decremented, no other state mutated. |
| 6 | `testSortSessionFinalizeWritesValueSortRow` | a finalized session produces exactly one `ValueSort` with matching contents. |
| 7 | `testNewestValueSortIsActive` | `@Query`-style "newest by createdAt" returns the just-written row when two exist. |
| 8 | `testCommittedActionLifecycleMarkDoneSetsCompletedAt` | marking done flips `isDone`, sets `completedAt`, leaves other fields untouched. |
| 9 | `testCommittedActionPersistsAcrossReSort` | after writing a second `ValueSort`, prior `CommittedAction` rows are still queryable, intact. |
| 10 | `testCommittedActionWithDroppedValueRefStillResolvesToFallback` | a re-sort that omits the action's value still leaves the row visible with the fallback display. |
| 11 | `testValueTaxonomyIntegrity` | `ValueTaxonomy.all` has no duplicate ids, all ids are lowercase ASCII slugs, all names/descriptions non-empty. |

Tests run in-memory (`ModelConfiguration(isStoredInMemoryOnly: true)`), matching the precedent in `LearnedBodyMapTests` and `CheckInDraftTests`.

## Files affected

**New (Swift):**
- `OpenFeelings/Models/ValueTaxonomy.swift`
- `OpenFeelings/Models/CustomValue.swift`
- `OpenFeelings/Models/ValueSort.swift` (includes `SortBucket`, JSON helpers)
- `OpenFeelings/Models/CommittedAction.swift`
- `OpenFeelings/Models/ValueRef.swift` (small helper enum + `displayName`)
- `OpenFeelings/Views/Direction/DirectionView.swift`
- `OpenFeelings/Views/Direction/Intentions/IntentionsContent.swift`
- `OpenFeelings/Views/Direction/Values/ValuesArea.swift`
- `OpenFeelings/Views/Direction/Values/CommittedActionRow.swift`
- `OpenFeelings/Views/Direction/Values/CommittedActionDetail.swift`
- `OpenFeelings/Views/Direction/Values/CommittedActionEditor.swift`
- `OpenFeelings/Views/Direction/Values/Sort/SortFlowView.swift` (hosts `SortSession`)
- `OpenFeelings/Views/Direction/Values/Sort/BucketStepView.swift`
- `OpenFeelings/Views/Direction/Values/Sort/FinalistsStepView.swift`
- `OpenFeelings/Views/Direction/Values/Sort/RankStepView.swift`
- `OpenFeelings/Views/Direction/Values/Sort/ConfirmSortView.swift`

**Modified:**
- `OpenFeelings/OpenFeelingsApp.swift` — extend `Schema(...)` to include the three new `@Model` types.
- `OpenFeelings/Design/AppNavigation.swift` — rename `intentions` → `direction`; update `title`/`systemImage`.
- `OpenFeelings/Views/RootView.swift` — mount `DirectionView()`; update `accessibilityIdentifier` to `"tab.direction"`.
- `project.yml` — no target changes; xcodegen picks up new files from existing source paths.

**Deleted:**
- `OpenFeelings/Views/IntentionsView.swift` — body lifted into `Direction/Intentions/IntentionsContent.swift`, file removed.

**New (tests):**
- `OpenFeelingsTests/ValuesTests.swift`

**Untouched:**
- All check-in, history, insights, settings, body-region, mood, taxonomy, and watch code.

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

Manual on simulator with a fresh container:

1. Open the app. Tab bar shows **Direction** (leaf icon), positioned where Intentions used to be. Intentions today-editor and look-back render unchanged inside it.
2. Below Intentions, Values area shows empty state with **Start the sort** button.
3. Tap **Start the sort** → bucketing screen, ~50 cards. Tap **Very important / Important / Not for me** through several cards. Verify Undo reverses the last assignment.
4. Tap **+ Add your own value**, enter "Curiosity", Add. Verify it appears in the remaining deck.
5. Finish bucketing → pick finalists screen. Tap chips to select 5–10. Try to add an 11th — verify cap.
6. Advance → rank screen. Drag rows to reorder. Advance → confirm screen. Tap **Confirm**.
7. Values area now shows YOUR VALUES ranked, plus a Re-sort button and an empty COMMITTED ACTIONS section.
8. Tap **+**, enter a title ("Call my brother"), pick a value, optionally enter "what's hard", Save. Row appears at the top.
9. Tap the row → detail. Tap **Mark done**. Verify reflection editor appears; type and save; relaunch app; reflection persists.
10. Tap **Re-sort**, complete a different sort. Verify YOUR VALUES updates to the newest ranking; the existing committed action still shows in COMMITTED ACTIONS with its previous value name.
11. iCloud sync test (two devices, same Apple ID): finish a sort on device A; on device B, verify YOUR VALUES syncs and committed actions appear.
12. Reduce Motion on → rank-step drag still works (system gesture).
13. Dynamic Type @ AX5 → bucket buttons stack vertically; long value names truncate gracefully in chips.

Expected automated result: BUILD SUCCEEDED + existing passing tests + 11 new tests passing.

## Out of scope

- Linking committed actions to feeling logs / Insights.
- Browsing prior `ValueSort`s as a history view.
- Editing a confirmed `ValueSort`'s rankings without a full re-sort.
- Multi-day or resumable sort flow.
- Notifications, reminders, streaks.
- Sharing or export of values/actions (would naturally roll into the existing therapy-bridge export later).
- watchOS surface for values.
- Custom value renaming or merging after creation.
