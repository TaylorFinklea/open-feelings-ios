# Challenge a past journal entry — design

**Date**: 2026-06-03
**Status**: Approved (design); pending implementation plan
**Related**: `2026-05-18-cbt-thought-records-design.md` (introduced thought records + `linkedLogID`)

## Problem

Thought records can already be started *from* a check-in: the `LogCard` share
menu's "Examine this thought" opens the wizard pre-filled via
`ThoughtRecordDraft.from(log:)`. But the reverse motion doesn't exist — when a
user is in the **Thoughts** tab in a reflective frame of mind and wants to
reach back to a past journal entry and challenge what they actually *wrote*,
there's no path. The blank wizard starts from scratch with no way to pull in a
prior entry.

Additionally, even the existing log→record hand-off only seeds *situation* +
*intensity-before*; it never brings the journal **note** text (the actual
thoughts) into the record.

## Goal

From the Thoughts tab, let the user start a thought record by **picking a past
journal entry** and have the wizard pre-fill the **automatic thought** from
that entry's note, while keeping the original note visible as read-only
reference.

## Decisions (from brainstorming)

- **Entry point**: Thoughts-initiated (not a new journal-side button).
- **Surface shape**: an optional **Step 0** *inside* the wizard — "Challenge a
  past entry, or start blank?" — shown when the user taps the existing
  "Start a record" / `+` actions. One front door; the chooser is skippable.
- **Pre-fill**: pull the entry's `note` → `automaticThought`, **and** keep the
  original note visible as read-only reference. (situation + intensity-before
  pre-fill as today.)
- **Picker scope**: only journal entries that **have a written note**, newest
  first. Simple scrollable list, **no search**.
- The original `FeelingLog` is never modified.

## Non-goals (explicitly out of scope)

- No reverse "all thought records for this entry" view.
- No cascade-delete or orphan-cleanup changes.
- No new persisted fields on `ThoughtRecord` or `FeelingLog` — reuse the
  existing `ThoughtRecord.linkedLogID: UUID?`.
- No change to the existing journal-side "Examine this thought" behavior.

## Components

### 1. Source chooser (Step 0)

A new first screen for the **brand-new** wizard flow only:

- Two choices: **"Challenge a past entry"** and **"Start blank."**
- "Start blank" proceeds to the existing Situation step with an empty draft
  (today's behavior).
- "Challenge a past entry" pushes the journal picker (component 2).

**Critical gating**: `ThoughtRecordFlowView` is shared by three callers —
blank-new, edit (`from(record:)` + `existingRecord`), and the journal
"Examine this thought" (`from(log:)`). The chooser must appear **only** for
the blank-new flow. The edit and examine flows must bypass it and start at
their current entry step.

- *Codebase-derived*: gate this by mirroring the existing init-parameter
  pattern on `ThoughtRecordFlowView` (it already takes `existingRecord` to vary
  behavior). Add an analogous flag/parameter that the two `showingWizard = true`
  entry points in `ThoughtRecordsArea` set, and that the edit/examine callers
  leave at its non-chooser default. Read `ThoughtRecordFlowView.swift` and
  `ThoughtRecordsArea.swift` and follow how `existingRecord` threads through.

### 2. Journal entry picker

A new focused list view (presented within the wizard's `NavigationStack`):

- Query `FeelingLog` where the note is non-empty, sorted by `createdAt`
  descending. *Codebase-derived*: mirror the `@Query` + sort usage already in
  `ThoughtRecordsArea` / `HistoryView`; for the note-non-empty predicate, read
  how `FeelingLog.note` is used and filter accordingly (in-query predicate or
  post-filter — implementer's choice; a post-filter on the sorted array is
  acceptable given expected volumes).
- Each row: emotion title, date, intensity dots, and a one-line note preview.
  *Codebase-derived*: reuse the visual cues from `LogCard` but do **not** embed
  the full `LogCard` (its edit/delete/share/Day-One machinery is out of scope).
  A lightweight purpose-built row is preferred.
- Empty state when no noted entries exist: e.g. "Journal entries with notes
  will show up here to challenge."
- Selecting a row builds the pre-filled draft (component 3) and advances into
  the wizard at the Situation step.

### 3. Pre-fill factory

Add a **new** factory on `ThoughtRecordDraft`, separate from `from(log:)`, so
the existing "Examine this thought" path is untouched:

- New factory (e.g. `challenging(log:)`) sets everything `from(log:)` does
  (`linkedLogID`, `situation` = `"<pathTitle · time>"`, `intensityBefore`)
  **plus** `automaticThought = log.note`.
- *Spec-derived invariant*: `from(log:)` must remain behaviorally identical
  (no `automaticThought` pre-fill) — verified by its existing tests, if any,
  and by the unchanged "Examine this thought" flow.

### 4. Read-only source-note reference

The original note must be visible as read-only reference on the **Automatic
Thought** step and echoed on the **Confirm** step.

- *Codebase-derived*: resolve the source note for display via the
  `linkedLogID` lookup pattern already used in `ThoughtRecordDetail` (its
  `linkedLog` computed property), **or** carry the note on the draft for
  display. Either is fine, but do **not** persist a reference-only copy onto
  `ThoughtRecord`. Read `ThoughtRecordDetail.swift`, `AutomaticThoughtStepView.swift`,
  and `ConfirmThoughtRecordView.swift` before choosing.
- The reference block should be visually distinct from the editable
  `automaticThought` field so it's clear which text is being challenged vs.
  which is the original.

## Data flow

```
Thoughts tab "Start a record"/+ (chooser-enabled)
  → ThoughtRecordFlowView (chooser flag on)
      → Step 0 chooser
          ├─ "Start blank" → Situation step (empty draft)   [today's flow]
          └─ "Challenge a past entry" → Journal picker
                 → select FeelingLog (note non-empty)
                 → ThoughtRecordDraft.challenging(log:)      [note → automaticThought]
                 → Situation step → … → Confirm → save
```

`linkedLogID` is set on the saved `ThoughtRecord`, so the existing
`ThoughtRecordDetail` "From check-in" footer already lights up for these
records (no extra work).

## Testing

- **Unit**: `ThoughtRecordDraft.challenging(log:)` sets `automaticThought` to
  `log.note`, sets `linkedLogID`, `situation`, `intensityBefore`; and
  `from(log:)` is unchanged (no `automaticThought`).
- **Picker filter**: a `FeelingLog` with empty note is excluded; one with a
  note is included and ordered newest-first.
- **Flow gating** (where testable / via existing UI-test patterns): the edit
  flow and "Examine this thought" flow do not show the chooser; the Thoughts-tab
  new flow does.
- Follow the existing thought-record test conventions from the
  `2026-05-18-cbt-thought-records` work.

## Acceptance

- Thoughts tab → "Start a record" → choose "Challenge a past entry" → pick a
  noted journal entry → wizard opens with that entry's note as the editable
  automatic thought and the original note shown read-only → complete and save →
  record persists with `linkedLogID` and shows the "From check-in" footer.
- "Start blank" still works exactly as before.
- "Examine this thought" from a check-in still works exactly as before
  (no note pre-fill).
- Build + tests pass.
