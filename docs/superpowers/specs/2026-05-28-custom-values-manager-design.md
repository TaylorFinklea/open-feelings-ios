# Custom values manager — design

**Status:** approved (2026-05-28)
**Part of:** the per-surface CRUD arc (see `decisions.md` 2026-05-28). This is sub-project **B** — manage (rename/delete) custom values. Other sub-projects (check-in full edit, value-sort delete, committed-action delete, intention edit/delete, custom-region rename) are separate specs.

## Why

`CustomValue` is the one user-created type with **no edit or delete** today — they can only be *created* during a value sort. Users need to rename a typo and remove values they no longer want.

## Decisions locked

| Decision | Choice |
|---|---|
| Architecture | Per-surface CRUD (not a unified console) |
| Placement | Sheet opened from the Values area on the Direction tab |
| Delete behavior | Just-delete; references in past sorts / committed actions render "(removed value)" |
| Rename | In-place via an alert with a pre-filled TextField |
| Creation | Unchanged — still happens inside the value sort; this surface is manage-only |

## Key existing behavior this relies on

- `ValueRef.displayName(for:customs:)` (`OpenFeelings/Models/ValueRef.swift:25`) **already** falls back to `"(removed value)"` when a `custom:<uuid>` ref has no matching `CustomValue`. So deleting a referenced value needs **no cascade** — past sorts and committed actions keep their slot and render the fallback string.
- All references use the UUID (`custom:<uuid>`), never the name, so **rename is safe** with zero ref updates — `CustomValue.swift` notes "Survives renames."

## Files

### Create
- `OpenFeelings/Views/Direction/Values/CustomValuesSheet.swift` — modal manager. `@Query(sort: \CustomValue.createdAt)` list; rename via alert; swipe-delete with confirmation; Done button; empty state. Holds two static helpers for testability:
  - `static func rename(_ value: CustomValue, to newName: String, in context: ModelContext)` — trims; no-op on empty/whitespace; saves.
  - `static func delete(_ value: CustomValue, in context: ModelContext)` — `context.delete` + save.
  (Mirrors `HistoryView.deleteLog` / `updateNote` static-helper precedent.)

### Modify
- `OpenFeelings/Views/Direction/Values/ValuesArea.swift` — add a "Manage custom values" affordance at the **bottom** of the populated Values section (below committed actions), shown only when `!customs.isEmpty`, opening `CustomValuesSheet` via `.sheet(isPresented:)`.

### Tests — `OpenFeelingsTests/CustomValuesManagerTests.swift` (~4, in-memory SwiftData)
1. `testRenameUpdatesNameTrimmed` — rename to "  Curiosity  " → name == "Curiosity".
2. `testRenameToEmptyIsNoOp` — rename to "   " → name unchanged.
3. `testDeleteRemovesValueFromStore` — delete → fetch count drops.
4. `testDeletedValueRefResolvesToRemovedValue` — a `ValueSort.rankedTop` holding the deleted value's `custom:<uuid>` ref resolves to "(removed value)" via `ValueRef.displayName`.

## Out of scope

- No cascade ref-stripping (just-delete chosen).
- No creating custom values outside the sort.
- No other data types (separate sub-projects).

## Build sequence

1. `CustomValuesSheet.swift` + `CustomValuesManagerTests.swift` (TDD on the two static helpers).
2. Wire the entry affordance + sheet into `ValuesArea`.
3. Build + full unit (404 → 408) + full UI (15, unaffected) + manual smoke.
4. Ship with the next build.
