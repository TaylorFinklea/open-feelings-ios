# Check-in full edit — design

**Status:** approved (2026-05-28)
**Part of:** the per-surface CRUD arc (see `decisions.md` 2026-05-28). This is sub-project **A** — the last and largest piece. B–F shipped in builds prior/38.

## Why

Today a saved check-in (`FeelingLog`) can only be **deleted** or have its **note** edited; emotion/intensity/body/triggers/coping/mood are locked. This was the deliberate "moment, not journal" stance. The user wants to fully edit a past check-in — fix a misclassified emotion, add body/triggers they skipped, adjust intensity. This spec **reverses** that stance for everything *except the timestamp*.

## Decisions locked

| Decision | Choice |
|---|---|
| Editor architecture | Dedicated `CheckInEditView` reusing the wizard's step views + `StepNav` + `CheckInFlowEngine` + `CheckInDraft`. `CheckInView` (the Check In tab root) is left untouched. |
| Presentation | Push onto History's nav stack (value-based `NavigationLink`), not a sheet. |
| Watch entries | Fully editable on iPhone. `captureSource` stays `"watch"` (read-only field). |
| Note-only edit | **Removed.** Note becomes one field of full edit. `NoteEditorSheet` deleted. |
| `createdAt` | **Immutable.** Editing changes *what* was recorded, not *when*. |
| HealthKit | Edit does **not** re-trigger sync; `healthSyncStatus` preserved as-is. |

## Why a dedicated editor, not reusing `CheckInView`

The edit flow is a *simpler sibling* of new-entry, not a clone: no body→emotion nudge, no learning-based suggestions, no save-bounce ribbon, no tab navigation to Today, no `ensureUserBodyMapExists`, and a save that mutates an existing log instead of inserting. Threading an edit mode through `CheckInView` would overload the most-used screen and risk the daily flow; refactoring it into a shared inner view is a larger regression risk. A dedicated `CheckInEditView` reuses the expensive, shared pieces (the 9 step views, `StepNav`, `CheckInFlowEngine`, `CheckInDraft`) and matches the codebase's separate-orchestrator-per-flow precedent (`SortFlowView`, `ThoughtRecordFlowView`). The only duplication is a ~25-line step-dispatch `switch`, which legitimately differs (no nudge args).

## Draft round-trip — `CheckInDraft` additions

Mirrors `ThoughtRecordDraft.from(record:)` / `apply(to:)`.

### `static func from(log: FeelingLog) -> CheckInDraft`
- `selection = EmotionTaxonomy.selection(coreID: log.coreID, secondaryID: log.secondaryID.isEmpty ? nil : log.secondaryID, specificID: log.specificID.isEmpty ? nil : log.specificID)`
- `note = log.note`
- `includeIntensity = log.intensity != nil`; `intensity = Double(log.intensity ?? 3)`
- `includeMoodScale = log.moodEnergy != nil || log.moodValence != nil`; `moodEnergy = log.moodEnergy ?? 0`; `moodValence = log.moodValence ?? 0`
- `bodyRegions = Set(log.bodyRegions)`; `customBodyRegionIDs = Set(log.customBodyRegionIDs)`
- `bodySensations = Set(log.bodySensations)`; `contextPlaces = Set(log.contextPlaces)`; `contextPeople = Set(log.contextPeople)`
- `triggers = Set(log.triggers)`; `coping = Set(log.coping)`

### `func apply(to log: FeelingLog)`
- emotion path: `log.coreID/coreName` from `selection.core`; `secondaryID/secondaryName` from `selection.secondary` (empty strings if nil); `specificID/specificName` from `selection.specific` (empty if nil)
- `log.intensity = includeIntensity ? Int(intensity.rounded()) : nil`
- `log.note = note.trimmingCharacters(in: .whitespacesAndNewlines)`
- the six Set fields → `Enum.allCases.filter { set.contains($0) }` (matches `CheckInView.save()` exactly)
- `log.customBodyRegionIDs = Array(customBodyRegionIDs)`
- `log.moodEnergy = includeMoodScale ? moodEnergy : nil`; `log.moodValence = includeMoodScale ? moodValence : nil`
- **Does NOT touch** `id`, `createdAt`, `healthSyncStatus`, `captureSource`.

These two methods carry the round-trip; they're pure and fully unit-testable.

## `CheckInEditView`

A push-destination view:
- `@Bindable`/`let log: FeelingLog`, `@Environment(\.modelContext)`, `@Environment(\.dismiss)`.
- `@State private var draft: CheckInDraft` initialized from `.from(log:)` (in `init`, like `ThoughtRecordFlowView`'s draft init).
- `@State private var stepIndex = 0`.
- `stepList = CheckInFlowEngine.steps(bodyFirst:promotedSteps:)` from the same `@AppStorage` settings `CheckInView` reads, so edit matches the user's configured flow.
- `stepContent` `switch` dispatching to the same step views with `$draft`. `FeelingStep` is passed empty `suggestedCoreIDs` and `nil` nudge (edit has no learning surface).
- Header shows the log's `createdAt` (read-only) so the user knows which moment they're editing; if `captureSource == "watch"`, show the "From Apple Watch" badge (read-only).
- `StepNav` with back/skip/advance. Final step's advance = **Save**: `draft.apply(to: log); try? context.save(); dismiss()`.
- Title "Edit check-in"; `navigationTitle`. Accessibility identifier `checkin-edit.save` on the final Save control; `checkin-edit.view` on the root.

## History wiring

In `HistoryView` / `LogCard`:
- **Entry point** = an explicit "Edit" affordance, *not* wrapping the whole card in a `NavigationLink` (the card already contains the share `Menu`, so a card-wide link would fight the menu's taps). Concretely: the `LogCard` share menu's current "Edit note" item becomes **"Edit"**; tapping it sets `@State private var editTarget: FeelingLog?` on `HistoryView`, and `.navigationDestination(item: $editTarget) { CheckInEditView(log: $0) }` performs the push. (`FeelingLog` is `@Model`, hence `Identifiable`/`Hashable`, so it's a valid nav item.)
- **Remove** the note-only edit: `LogCard`'s `onEditNote` callback/param, `HistoryView`'s `editingLog` state + `NoteEditorSheet` sheet, the `HistoryView.updateNote` static helper, and delete `NoteEditorSheet.swift`.
- Keep swipe-to-delete and the "Examine this thought" share-menu entry unchanged.
- Add `.accessibilityAction(named: "Edit")` on the card for VoiceOver, mirroring the existing "Delete" action; carry the existing `accessibilityIdentifier` convention onto the Edit control.

## Edge cases (from exploration)

- **Stop-at-any-level**: core-only and core+secondary logs reconstruct correctly because `EmotionTaxonomy.selection` returns nil for empty secondary/specific IDs. `apply(to:)` writes empty strings back when the selection lacks those levels.
- **Clearing intensity/mood**: toggling `includeIntensity`/`includeMoodScale` off must set the log fields to `nil` (the ternary handles it).
- **Custom region deleted after the log was made**: `from(log:)` carries the orphan UUID into the draft; the body step renders only existing custom regions, so an orphan silently drops on next save — acceptable (matches the benign-orphan posture established in CRUD-F).
- **Orphaned emotion path** (taxonomy id no longer exists): `EmotionTaxonomy.selection` returns nil → the edit view opens on the Feeling step with no selection; `canSave` already guards against saving without a complete selection. Acceptable.
- **CloudKit**: all fields are `@Model`; `context.save()` syncs edits automatically. No special handling.
- **Discard**: backing out (nav pop) discards — only the final Save calls `apply(to:)`. Matches the new-entry wizard (nothing persists until Save).

## Testing

### Unit — `OpenFeelingsTests/CheckInDraftEditTests.swift` (~12, no SwiftData container needed for most; in-memory where a real `FeelingLog` is mutated)
1. `from(log:)` round-trips a fully-populated log (every field).
2. `from(log:)` core-only log → selection has nil secondary/specific.
3. `from(log:)` core+secondary log → nil specific.
4. `from(log:)` with `intensity == nil` → `includeIntensity == false`.
5. `from(log:)` with mood present → `includeMoodScale == true`, values match.
6. `apply(to:)` writes every field back (full round-trip equality through `from` → `apply` → re-`from`).
7. `apply(to:)` clears intensity when `includeIntensity` toggled off.
8. `apply(to:)` clears mood when `includeMoodScale` toggled off.
9. `apply(to:)` preserves `id`, `createdAt`, `healthSyncStatus`, `captureSource`.
10. `apply(to:)` trims the note.
11. `apply(to:)` downgrades a 3-level path to core-only (clears secondary/specific IDs+names).
12. `apply(to:)` upgrades core-only to a 3-level path.

### UI — extend `OpenFeelingsUITests` (1 test, happy path)
- From History, tap a check-in → `checkin-edit.view` appears → advance to the final step → `checkin-edit.save` → assert return to History. (Defensive against persistent-sim data, like the other UI tests.)

### Adjust
- `HistoryNoteUpdateTests.swift` tested `HistoryView.updateNote`, which is removed. Replace its coverage with the note path through `apply(to:)` (covered by the `from`/`apply` round-trip tests), and delete the now-invalid file.

## Out of scope
- Editing `createdAt` (the timestamp is the moment).
- Re-syncing edited entries to HealthKit.
- A cancel-confirm dirty-check (pop discards, matching new-entry).
- Bulk edit.

## Build sequence
1. `CheckInDraft.from(log:)` + `apply(to:)` + `CheckInDraftEditTests` (TDD).
2. `CheckInEditView` reusing the step views.
3. Wire into `HistoryView` (card→push, `navigationDestination(for: FeelingLog.self)`); remove note-only edit + `NoteEditorSheet`; delete `HistoryNoteUpdateTests`.
4. UI happy-path test.
5. Build + full unit + full UI + manual smoke.
6. Ship with the next build.
