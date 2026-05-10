# Intentions Reflection — Design

## Context

The Intentions surface (`OpenFeelings/Views/IntentionsView.swift`) already supports setting one intention per day and a reverse-chronological "Look back" list. Each past row shows the date, intention text, and a `felt: anxious, sad` subtitle derived from the same-day check-in cores via `IntentionDayFelt.topCoreNames(...)`.

What's missing is the second half of the roadmap line: **track completion**. Past intentions are read-only — there's no affordance to reflect on whether the intention landed.

This design adds a freeform reflection note per past day, edited inline. It does not introduce binary completion ("yes I did this / no I didn't"), streaks, or auto-derived completion from check-ins. Those would conflict with the calm, no-shame voice of the rest of the app.

## Goals

- Let the user write a short reflection on any past day's intention, inline.
- Persist the reflection alongside the intention (no separate model, no migration step).
- Make the affordance discoverable but quiet — a muted "Reflect on this day" button when empty, the reflection text shown plainly when filled.
- Keep today's intention editor unchanged.

## Non-goals

- Completion toggles or success scoring.
- Editing past intention *text* (only the reflection is editable on past days).
- Reflection on today's intention (today is for setting, not reflecting; you reflect tomorrow).
- Reminders or notifications for reflections.
- Reflection prompts beyond a single placeholder ("How did this land?").

## Architecture

### Data model

Add one field to the existing `@Model` class:

```swift
@Model
final class Intention {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""
    var reflection: String = ""   // NEW — empty until user reflects

    init(id: UUID = UUID(), date: Date = Date(), text: String, reflection: String = "") { ... }
}
```

SwiftData handles new optional-or-defaulted properties additively; existing rows on device will read back as `reflection: ""`. No `VersionedSchema` migration step is needed because the property has a default value. This matches the pattern used elsewhere in `FeelingLog`.

### View structure

`IntentionsView` already renders past intentions in a `lookBackSection`:

```
ForEach(pastIntentions) { intention in
    OFCard { lookBackRow(intention) }
}
```

We change `OFCard { lookBackRow(intention) }` to a tappable card that toggles an "expanded" set held in `IntentionsView` state:

```swift
@State private var expandedIDs: Set<UUID> = []
```

A row in expanded state additionally shows:

- A `TextField("How did this land?", text: ..., axis: .vertical)` with `lineLimit(2...6)`, styled like the today editor's TextField.
- A row with status text + Save / Saved button mirroring today's editor.
- The user can tap the date area or anywhere outside the TextField on the card to collapse.

A row in collapsed state shows:

- If `reflection.isEmpty` → a muted "Reflect on this day" button (`OFButton(.secondary)`) below the existing content.
- If `reflection` is non-empty → the reflection text shown plainly under a small "Reflection" caption, with a tappable affordance ("Edit") to expand.

### Save semantics

Mirror today's editor: a `hasUnsavedChanges` computed property compares the local draft to `intention.reflection`, the Save button is enabled only when dirty, and tapping Save mutates `intention.reflection` directly (the `@Model` is a class — mutation triggers SwiftData persistence on `modelContext.save()`).

Each expanded row owns its own draft via a small per-row state container (`@State private var drafts: [UUID: String]` on the parent, or a dedicated subview). We'll use a dedicated subview (`PastIntentionRow`) so each row's `@State` is naturally scoped — simpler than a dictionary on the parent and avoids stale-draft bugs when expanding/collapsing.

### Per-row subview signature

```swift
private struct PastIntentionRow: View {
    let intention: Intention
    let topCoreNames: [String]?            // resolved by parent
    let isExpanded: Bool
    let onToggleExpanded: () -> Void
    let onSave: (String) -> Void
}
```

The parent passes `topCoreNames` because the lookup needs the full `logs` query, which already lives on `IntentionsView`. Keeping the row pure-presentational makes it easy to preview and test.

## UX details

- **Expand animation:** matched-geometry isn't necessary — a default `.animation(.easeInOut(duration: 0.18), value: isExpanded)` on the row's content, gated behind `accessibilityReduceMotion` to drop to no animation, matches the rest of the app.
- **Empty reflection placeholder:** "How did this land?" — singular, calm, no judgement. Not "How did you do?" (implies grade) or "Did you keep your intention?" (binary).
- **Saved state:** mirrors the today editor's three-state status text — "Not yet reflected" / "Unsaved changes" / "Saved".
- **Whitespace handling:** trim whitespace on save. An all-whitespace draft saves as `""` (clears the reflection). Same trim semantics as `saveTodayIntention()`.
- **Accessibility:** card is a button (`.accessibilityAddTraits(.isButton)`); when expanded, the TextField is a separate element with its own label.

## Edge cases

- **Future-dated intentions?** Not possible — the model upserts to start-of-today only via the today editor. No need to handle "reflect on a future day".
- **Empty intention text with reflection?** Possible if the user clears the today text after writing a reflection. Render the reflection as-is — the row is keyed by `Intention`, not `Intention.text`. The parent's `pastIntentions` filter is unchanged.
- **Today's row in look-back?** `pastIntentions` already excludes today. Today's intention has no reflection editor — by design, you reflect tomorrow.
- **Deleting an intention?** Out of scope. Tracked separately if it becomes a need.
- **iCloud sync conflict on reflection field?** SwiftData + CloudKit handles last-writer-wins per field. Acceptable; the reflection is a single text field, not structured.

## Testing

The reflection field has minimal logic — most of the work is UI. The pure-logic surface that warrants a test is `IntentionDayFelt`, which is unchanged. New tests:

- **Schema test:** create an `Intention` with no reflection, save, reload — `reflection == ""`.
- **Mutation test:** set `reflection`, save, reload — value persists.
- **Trim test:** a tiny pure helper `Intention.normalizedReflection(_:)` (`String -> String`) trims whitespace consistently. Test: `"   foo  \n"` → `"foo"`, `"   "` → `""`. The view calls this before assignment.

UI tests (XCUITest) for expand/collapse + reflection are deferred — the existing UI test infrastructure isn't wired (per the roadmap backlog item on accessibilityIdentifiers for iOS 26 tab bar).

## Files affected

**Modified:**
- `OpenFeelings/Models/Intention.swift` — add `reflection` property, default `""`, init param.
- `OpenFeelings/Views/IntentionsView.swift` — add `expandedIDs` state; replace inline `lookBackRow` with `PastIntentionRow` subview; add reflection editor + save flow.

**New:**
- (none — `PastIntentionRow` lives inside `IntentionsView.swift` since it's tightly coupled to the look-back list)

**Tests:**
- `OpenFeelingsTests/IntentionTests.swift` (new file, ~40 lines): schema-default, mutation-persist, trim-helper.

**Untouched:**
- `OpenFeelings/Models/IntentionDayFelt.swift` — the felt-cores logic is reused as-is.
- All other models/views.

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

Expected: BUILD SUCCEEDED + 163 + ~3 = ~166 passing tests.

**Manual on simulator with seeded intentions over several days + check-ins on those days:**

1. Today editor unchanged. Set today's intention, save — works as before.
2. Past-day card — collapsed: shows date, intention, `felt: ...` subtitle, "Reflect on this day" muted button.
3. Tap card or "Reflect" button → row expands with TextField focused, Save disabled until typed.
4. Type a reflection → Save enables, status reads "Unsaved changes".
5. Save → status reads "Saved", button still says "Saved" but disabled. Card stays expanded.
6. Tap card date area → collapses; reflection text now shows under "Reflection" caption with "Edit" affordance.
7. Tap "Edit" → re-expands with prior text in the TextField, Save disabled until edited.
8. Background the app, relaunch — reflection persists.
9. Reduce Motion on → expand/collapse is instant, no animation.
10. VoiceOver — collapsed card reads as a button, expanded TextField reads as a text field with the placeholder label.
11. Dynamic Type @ AX5 — TextField wraps, Save button still tappable.

## Out of scope

- Editing past intention *text* itself.
- Streaks, completion percentages, "you've reflected on N days".
- Reminders to reflect.
- Reflection prompts beyond the single placeholder.
- Auto-suggesting a reflection from same-day check-in patterns.
- Sharing / exporting reflections (would naturally fold into the deferred therapy-bridge export).
