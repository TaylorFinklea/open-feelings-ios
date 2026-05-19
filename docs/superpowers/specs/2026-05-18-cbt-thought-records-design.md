# Thought Records — Design Spec

**Date:** 2026-05-18
**Author:** Taylor Finklea (via brainstorming)
**Status:** Approved for implementation planning

## Summary

A CBT-style **thought record** feature for Open Feelings, modeled on David
Burns's "Feeling Good" five-step (with intensity-before/after split into two
steps for clarity, totaling six). Lives on the **Direction tab** below
Intentions and Values. Standalone-first; optional entry point from any
check-in's share menu. Curated 8-chip catalog of "thinking patterns" replaces
the more clinical "cognitive distortions" terminology while preserving Burns's
"name the pattern" step. UI named "Thought records" (clinical-but-accurate).

## Why

Open Feelings already supports naming a feeling, tracking it over time, and
acting on values. The piece missing is **examining the thought behind a hard
feeling and reframing it.** Industry-standard CBT thought records are the
distinctive tool for this. None of the existing surfaces — note field, triggers,
coping, intention reflection, committed-action reflection — provide the
structured *thought → balanced thought → re-rated emotion* flow.

This feature gives users a private, on-device place to practice that
structure without app-prescribed advice or scoring. Tone stays consistent
with Open Feelings: calm, non-clinical, not pathologizing.

## Scope (in / out)

**In:**
- One new SwiftData `@Model`: `ThoughtRecord`
- One enum taxonomy: `ThinkingPattern` (8 curated cases)
- A six-step wizard flow (`ThoughtRecordFlowView`) using the same
  `NavigationStack` step pattern as `SortFlowView`
- A new Direction-tab area (`ThoughtRecordsArea`) with empty state, "Start a
  record" CTA, and a recent-records list when populated
- A read-only detail view (`ThoughtRecordDetail`) with "Edit" that re-enters
  the wizard pre-filled, swipe-to-delete in the Direction tab list
- Optional entry point from check-in `LogCard` share menu ("Examine this
  thought") which pre-fills `situation` and `intensityBefore` from the
  source `FeelingLog`
- Unit tests covering the model (`ThoughtRecord`), the taxonomy
  (`ThinkingPattern` integrity), the wizard's required-field gating logic,
  and the pre-fill from a linked `FeelingLog`

**Out (deferred to a follow-up):**
- Watch-side support
- Insights charts (patterns over time, intensity-shift average)
- Export of thought records to therapy PDF
- Bulk operations / search
- Reminders to do a thought record
- Sharing individual records to Journal / Day One / Notes

## Data model

### `ThoughtRecord` @Model

```swift
@Model
final class ThoughtRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    // Step 1 — optional situation context
    var situation: String = ""

    // Step 2 — the noticed thought (required to save)
    var automaticThought: String = ""

    // Step 3 — intensity 1...5 before reframe (required to save)
    var intensityBefore: Int?

    // Step 4 — comma-joined ThinkingPattern.rawValue list, optional
    var patternsRaw: String = ""

    // Step 5 — balanced/alternative thought (required to save)
    var balancedThought: String = ""

    // Step 6 — intensity 1...5 after reframe (required to save)
    var intensityAfter: Int?

    // Optional foreign key to a FeelingLog that anchored this record.
    // Stored as UUID, no SwiftData relationship — matches CommittedAction's
    // valueRef pattern.
    var linkedLogID: UUID?

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         situation: String = "",
         automaticThought: String = "",
         intensityBefore: Int? = nil,
         patterns: [ThinkingPattern] = [],
         balancedThought: String = "",
         intensityAfter: Int? = nil,
         linkedLogID: UUID? = nil)
}

extension ThoughtRecord {
    var patterns: [ThinkingPattern] {
        get { ThinkingPattern.parseList(patternsRaw) }
        set { patternsRaw = ThinkingPattern.encodeList(newValue) }
    }

    /// Computed: did the reframe shift the feeling? Positive = lower
    /// intensity after; zero = no change; negative = worse. Nil when either
    /// intensity field is missing.
    var intensityDelta: Int? {
        guard let before = intensityBefore, let after = intensityAfter else { return nil }
        return before - after
    }

    /// True iff all four required fields are populated. Drives Save enablement
    /// on the wizard's confirm step.
    var isSaveable: Bool {
        !automaticThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !balancedThought.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && intensityBefore != nil
            && intensityAfter != nil
    }
}
```

**CloudKit compatibility:** every field has a default or is Optional, no
`@Attribute(.unique)`, no SwiftData relationships. Matches the pattern that
made the seven existing models CloudKit-clean. Adds one new record type
(`CD_ThoughtRecord`) + one queryable index (`CD_createdAt`) to the CloudKit
schema. Requires a Production schema re-deploy at release time — same step
the existing runbook covers.

### `ThinkingPattern` taxonomy

```swift
enum ThinkingPattern: String, CaseIterable, Codable, Sendable, Identifiable {
    case blackAndWhite, mindReading, worstCase, allMyFault
    case shouldStorm, filterTheGood, fortuneTelling, alwaysNever

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blackAndWhite:  "Black-and-white"
        case .mindReading:    "Mind-reading"
        case .worstCase:      "Worst-case"
        case .allMyFault:     "All my fault"
        case .shouldStorm:    "Should-storm"
        case .filterTheGood:  "Filter the good out"
        case .fortuneTelling: "Fortune-telling"
        case .alwaysNever:    "Always / never"
        }
    }

    var description: String {
        switch self {
        case .blackAndWhite:  "Seeing things in just two extremes, no middle."
        case .mindReading:    "Assuming someone's thoughts without checking."
        case .worstCase:      "Skipping to the worst outcome you can picture."
        case .allMyFault:     "Taking responsibility for something outside your control."
        case .shouldStorm:    "Pile-up of \"I should…\" / \"I must…\" rules."
        case .filterTheGood:  "Noticing only what went wrong, missing what went right."
        case .fortuneTelling: "Predicting a bad future as if it's already true."
        case .alwaysNever:    "Stretching one event into a permanent pattern."
        }
    }

    static func parseList(_ raw: String) -> [ThinkingPattern] {
        raw.split(separator: ",")
           .compactMap { ThinkingPattern(rawValue: String($0)) }
    }

    static func encodeList(_ list: [ThinkingPattern]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}
```

**Rationale for the 8-chip curation** — Burns's "Feeling Good" enumerates 10
distortions. The mapping:

| Burns name | Our name | Note |
|---|---|---|
| All-or-nothing thinking | Black-and-white | renamed |
| Overgeneralization | Always / never | renamed |
| Mental filter | Filter the good out | folded with discount-positive |
| Discounting the positive | (folded into Filter the good out) | |
| Jumping to conclusions — Mind reading | Mind-reading | split for usefulness |
| Jumping to conclusions — Fortune telling | Fortune-telling | split for usefulness |
| Magnification / Catastrophizing | Worst-case | renamed |
| Emotional reasoning | (dropped) | overlapping; rarely actionable |
| Should statements | Should-storm | renamed |
| Labeling | (folded into Black-and-white) | |
| Personalization and blame | All my fault | renamed |

Eight chips fit a single screen without scrolling on standard iPhone widths.
Soft naming aligns with the app's anti-pathologizing tone.

## UI / IA

### Direction tab placement

`DirectionView` keeps its existing top-down stack and adds a third section
below `ValuesArea`:

```
DirectionView
├── IntentionsContent
├── ValuesArea
└── ThoughtRecordsArea     ← new
```

### `ThoughtRecordsArea`

**Empty state** — pattern matches `ValuesArea`'s empty card:
- Headline: "Thought records"
- Subhead: "Examine a thought that's been stuck."
- Primary button: **Start a record** — opens `ThoughtRecordFlowView` as a
  modal sheet.

**Populated state**:
- Section header `THOUGHT RECORDS` + `+` icon button (top right)
- List of records sorted by `createdAt` descending, each row showing:
  - Date in `Wed May 14` format
  - First ~60 chars of `automaticThought`, ellipsized
  - Optional small badge of `intensityDelta` (`−2`, `0`, `+1`)
- Tapping a row pushes `ThoughtRecordDetail`
- Swipe-to-delete with confirmation alert, mirroring `History`'s pattern
  introduced in build 16

### `ThoughtRecordFlowView` — the six-step wizard

Modal sheet hosting a `NavigationStack` driven by a `ThoughtRecordDraft`
struct (mirrors `SortSession`'s in-memory progress model). Each step is one
file under `OpenFeelings/Views/Direction/Thoughts/Steps/`:

| Step | Type | View | Required? | Continue gate |
|---|---|---|---|---|
| 1 | Situation | `SituationStepView` | optional | always enabled |
| 2 | Automatic thought | `AutomaticThoughtStepView` | yes | non-empty trim |
| 3 | Intensity (before) | `IntensityBeforeStepView` | yes | value chosen |
| 4 | Thinking patterns | `PatternsStepView` | optional | always enabled |
| 5 | Balanced thought | `BalancedThoughtStepView` | yes | non-empty trim |
| 6 | Intensity (after) | `IntensityAfterStepView` | yes | value chosen |
| 7 | Confirm | `ConfirmThoughtRecordView` | — | `draft.isSaveable` |

Confirm screen shows the full record read-only. Save button bottom-right;
Back-edit each field via inline pencil icons.

Intensity pickers reuse the existing 1–5 dot component used in the check-in
wizard (`IntensityChips`). Pattern chips multi-select. Long-press a chip
reveals its description; tap toggles selection.

### `ThoughtRecordDetail`

Read-only view of all six fields with:
- Header: `automaticThought` displayed as a quote
- Section: situation (if non-empty)
- Section: patterns (chips, non-interactive)
- Section: balanced thought
- Section: intensity shift — visualized as two dot rows + a delta arrow
- Footer: linked check-in row (if `linkedLogID` resolves) — taps push the
  matching `LogCard`
- Toolbar: pencil-edit (re-enters the wizard pre-filled from this record)
- Toolbar: trash with confirmation

### Check-in entry point

`LogCard.shareMenu` (existing menu) gets one new item:

```
…
Apple Journal
Day One
Notes
Examine this thought    ← new
```

Tapping presents `ThoughtRecordFlowView` modally with:
- `linkedLogID` = source log's id
- `situation` pre-filled: `"<pathTitle> · <time formatted h:mm a>"`
- `intensityBefore` pre-filled from the source log's `intensity` if set
- All other fields empty

The pre-fills are mutable — the user can edit any field. Saving the record
creates a new `ThoughtRecord` row; the source `FeelingLog` is unchanged.

## Behavior + edge cases

- **Wizard cancel** — confirmation alert if any field is dirty.
- **Partial-save defense** — only the Save button on the confirm step writes
  to SwiftData; the wizard otherwise mutates an in-memory `ThoughtRecordDraft`
  struct. No half-records are persisted.
- **Edit vs. new** — when the wizard is entered from `ThoughtRecordDetail`'s
  pencil button, the `ThoughtRecordDraft` carries the source record's `id`.
  Save on the confirm step updates the existing record in place (matches the
  history-edit-note pattern from build 16). When the wizard is entered from
  the empty-state, the `+` button, or the LogCard share menu, the draft has
  a fresh `id` and Save inserts a new record.
- **Linked-log deleted later** — `ThoughtRecordDetail` checks if
  `linkedLogID` resolves; if not, the footer is hidden silently (no
  "deleted" indicator — same approach as `CommittedActionRow` with dropped
  values).
- **Patterns enum drift** — `ThinkingPattern.parseList` uses
  `compactMap(ThinkingPattern.init(rawValue:))`, so a record that has a
  pattern raw value not in the current enum (e.g., after a future case
  removal) silently drops the unknown value. Matches `BodyRegion` parsing.
- **CloudKit conflict resolution** — last-write-wins. SwiftData's default.
  Acceptable for a record edited rarely on a single device.

## Testing

Unit tests in `OpenFeelingsTests/`:

- `ThinkingPatternTests` — taxonomy integrity (every case has non-empty
  displayName + description; encodeList/parseList round-trips; unknown raw
  values are dropped).
- `ThoughtRecordTests` — `isSaveable` truth table (each of the four required
  fields missing fails; all-present passes; whitespace-only treated as
  empty); `intensityDelta` returns nil when either intensity is missing;
  positive/negative/zero deltas.
- `ThoughtRecordDraftTests` — wizard advance gating: each step's Continue
  enablement matches the table above; the draft → `ThoughtRecord`
  finalization preserves every field; pre-fill from a `FeelingLog` populates
  `situation` and `intensityBefore` correctly.
- `ThoughtRecordsAreaPersistenceTests` — newest-first sort; swipe-delete
  removes the row; linked-log resolution + missing-link fallback.

Aim for ~20 new unit tests. No new UI tests — the existing UI smoke pattern
(stable text labels) covers the wizard incidentally; we'll add a
`DirectionUITests.testThoughtRecordEmptyStateExposesStartButton` smoke once
the area lands.

## File plan (preview — exact list goes in the writing-plans output)

**New files:**
- `OpenFeelings/Models/ThoughtRecord.swift`
- `OpenFeelings/Models/ThinkingPattern.swift`
- `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordsArea.swift`
- `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDetail.swift`
- `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordFlowView.swift`
- `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDraft.swift`
- `OpenFeelings/Views/Direction/Thoughts/Steps/SituationStepView.swift`
- `OpenFeelings/Views/Direction/Thoughts/Steps/AutomaticThoughtStepView.swift`
- `OpenFeelings/Views/Direction/Thoughts/Steps/IntensityBeforeStepView.swift`
- `OpenFeelings/Views/Direction/Thoughts/Steps/PatternsStepView.swift`
- `OpenFeelings/Views/Direction/Thoughts/Steps/BalancedThoughtStepView.swift`
- `OpenFeelings/Views/Direction/Thoughts/Steps/IntensityAfterStepView.swift`
- `OpenFeelings/Views/Direction/Thoughts/Steps/ConfirmThoughtRecordView.swift`
- `OpenFeelingsTests/ThoughtRecordTests.swift`
- `OpenFeelingsTests/ThinkingPatternTests.swift`
- `OpenFeelingsTests/ThoughtRecordDraftTests.swift`
- `OpenFeelingsTests/ThoughtRecordsAreaPersistenceTests.swift`

**Modified:**
- `OpenFeelings/OpenFeelingsApp.swift` — add `ThoughtRecord.self` to
  `Schema(...)`
- `OpenFeelings/Views/Direction/DirectionView.swift` — append
  `ThoughtRecordsArea()`
- `OpenFeelings/Views/HistoryView.swift` — `LogCard.shareMenu` gains the
  "Examine this thought" item; carries the linked-log fields into the new
  flow
- `OpenFeelings/Views/TodayView.swift` — same `LogCard` change propagates
- `docs/release/cloudkit-production-deployment.md` — document
  `CD_ThoughtRecord` as the 8th record type and its queryable index

## Open questions (deferred to plan)

- Whether the chip long-press → description belongs in a sheet or a popover.
  Implementation-detail, won't affect data model.
- The exact wording of "Balanced thought" prompt — Burns uses "Rational
  response" but that's needlessly combative. Final copy in plan.
- Whether the intensity-shift visualization in detail view is a bar pair or
  an arrow between two dot rows. Implementation-detail.
