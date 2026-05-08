# Check In Wizard Redesign — Design

**Date:** 2026-05-08

**Goal:** Replace the current Check In wizard, which still feels overwhelming after the stepped rewrite, with a calm one-question-per-step flow that respects the bandwidth of a stressed user.

## Context

Build 7 (currently in TestFlight) ships a 3-step wizard with a Body First setting that determines whether body chips or the emotion picker comes first. Despite the wizard structure, each step still piles content onto a single screen — Body First step 1 stacks three chip cards (Body, Context, Triggers/Coping). That is exactly the wall of options a stressed user cannot navigate.

The user's framing: "imagine you're stressed, do you want to be presented with 3 questions that have 15 options? We need to completely rethink the UX/IA on this wizard and make it flow."

This redesign moves from "stepped containers for a pile of options" to "calm sequence of single-question screens, with progressive disclosure for power-user depth."

## Decisions (from brainstorm)

| # | Question | Decision |
|---|----------|----------|
| 1 | Overall flow shape | Calm wizard, one true question per step |
| 2 | Body First setting | Keep; on = adds an extra "Where in your body?" step at start |
| 3 | Everywhere / Nowhere body states | Italic dashed chips inline at the front of the chip row |
| 4 | Body view (chips vs silhouette) | Settings preference; default Chips, Silhouette is opt-in |
| 5 | Body → emotion hint placement | No hint on body step; suggested cores light up on Step 2 |
| 6 | Body → emotion personalization | Defaults + implicit learning + explicit override + soft nudge |
| 7 | Wizard step list | Adaptive; configurable in Settings → Check In flow |
| 8 | Picker mode toggle (Wizard/Wheel) | Keep pill segment at top of picker step |

## Architecture

The wizard is a sequence of single-question screens with shared chrome (progress bar, badge of choices made so far, Continue/Back/Skip nav). Each step exposes one question. The step list is computed by a pure value type, `CheckInFlowEngine`, from the user's settings (Body First on/off, list of promoted dimensions). Anything not promoted to a step stays accessible via a "+ More detail" disclosure on the final Reflect step.

### Default step order

**With Body First on (default for new users):**
1. Where in your body? (skippable)
2. How are you feeling? (required)
3. How strong? (skippable)
4. Anything to remember? (skippable)

**With Body First off:**
1. How are you feeling? (required)
2. How strong? (skippable)
3. Anything to remember? (skippable)

A user who promotes e.g. Sensations and Context to steps gets:
1. Where in your body?
2. Sensations
3. How are you feeling?
4. Context
5. How strong?
6. Anything to remember?

### Cross-cutting elements

- **Progress bar** — N capsules where N is the runtime step count for this user.
- **Selected feeling badge** — small core swatch + secondary name. Appears on every step after the feeling has been selected.
- **Body→emotion suggestion** — body picks (if any) influence Step 2's picker: suggested cores are full-opacity with a tiny dot, others rendered at reduced opacity but still tappable.
- **Personalization layer** — defaults map → implicit learning → explicit Settings override; soft nudges surface only when the app spots a strong personal pattern.

## Step Specifications

### Step: "Where in your body?" (Body First on only)

- Body view: chips (default) or silhouette (Settings opt-in).
- Chip row starts with two italic dashed chips: **Everywhere** (maps to existing `BodyRegion.wholeBody`) and **Nowhere** (new region representing somatic absence / numbness).
- Selecting Everywhere or Nowhere is mutually exclusive with each other and with all other regions; selecting any other chip clears Everywhere/Nowhere.
- Sensations live one disclosure deep: tap a region → an "+ Add sensation" affordance appears beneath the selected regions (or Sensations is its own step if the user has promoted it).
- Skip and Continue both pinned at bottom.
- New `BodyRegion.nowhere` enum case.

### Step: "How are you feeling?" (required)

- Same picker as today (Wizard or Wheel). The pill segment toggle stays at the top of the picker card.
- Body→emotion suggestion: cores not in the suggested set are rendered at 40% opacity with a tiny dot below suggested cores; all cores remain tappable.
- Suggestion logic: compute `suggestedCores` from the user's current body region selections, narrowing as more regions are picked (intersection logic; see Body → Emotion Mapping below).
- Personalization nudge appears only on this step, only when `LearnedBodyMap.dominantSecondary(for: region)` returns a non-nil value AND no `UserBodyMap` override exists for that region. Copy interpolates the actual count and total from the learned map: "You've picked *{secondary}* *{count}* of *{total}* times for *{region}*. Save as your default?" Two actions: "Not now" / "Save."
- Once a feeling is selected, the badge in the header shows it.

### Step: "How strong?" (skippable, Strength promoted by default)

- 5-dot intensity scale. Tap a dot to set; tap the same dot again to clear.
- Caption beneath the dots: "Just noticing · Strong" labels left/right.
- No toggle, no slider.
- Skip and Continue both pinned at bottom.

### Step: "Anything to remember?" (final, skippable)

- Selected feeling badge at top, plus intensity if set ("Cheerful · 3").
- Journal text editor (existing `TextEditor` styling).
- "+ More detail" disclosure expands to:
  - Sensations — visible only if regions were selected on the Body step (otherwise sensations have nothing to anchor to). Hidden entirely if Sensations is already promoted to its own step.
  - Context (places + people) — hidden if Context is its own step.
  - Triggers — hidden if Triggers is its own step.
  - Coping — hidden if Coping is its own step.
  - Mood scale (energy + valence) — hidden if Mood is its own step.
- Each item inside More detail is its own toggle-titled accordion that defaults collapsed.
- Save button pinned at bottom.

### Optional steps (only when promoted in Settings)

- **Sensations** — chips for tight, warm, cool, etc. Skippable. Visible only when at least one body region was picked on the body step (otherwise auto-skipped).
- **Context** — places + people chips. Skippable.
- **Triggers** — what brought it on. Skippable.
- **Coping** — what helped. Skippable.
- **Mood scale** — energy + valence sliders. Skippable.

Each promoted step has the same skeleton: title, sub-caption, content card, Skip + Continue.

## Body → Emotion Mapping

### Default mapping (curated, ships with app)

```
head      → Fearful, Disgusted, Angry
throat    → Sad, Fearful
chest     → Angry, Happy, Fearful
stomach   → Fearful, Disgusted, Sad
gut       → Fearful, Disgusted
shoulders → Angry, Sad, Fearful
back      → Angry, Sad
hands     → Angry, Fearful, Happy
legs      → Fearful, Angry, Happy
wholeBody → (no narrowing — all 5 cores)
nowhere   → Sad
```

These are starting heuristics inspired by mainstream somatic-emotion literature (Damasio, body maps). Marked as such in `BodyEmotionMap.swift` with a comment that a clinical review pass is on the roadmap.

### Narrowing logic

Given the user's selected regions, the suggestion set is the **intersection** of each region's mapping, as long as that intersection has at least one core. If the intersection is empty, fall back to the **union** (so the user always sees some suggestion).

Examples:
- Chest only → {Angry, Happy, Fearful}
- Chest + Hands → {Angry, Happy, Fearful} ∩ {Angry, Fearful, Happy} = {Angry, Happy, Fearful}
- Stomach + Legs → {Fearful, Disgusted, Sad} ∩ {Fearful, Angry, Happy} = {Fearful}
- Chest + Throat → {Angry, Happy, Fearful} ∩ {Sad, Fearful} = {Fearful}
- Throat + Legs → {Sad, Fearful} ∩ {Fearful, Angry, Happy} = {Fearful}

**Special cases:**
- **Everywhere** (`wholeBody`) → no narrowing. The mapping returns all 5 cores, so no dimming on Step 2.
- **Nowhere** → soft highlight of Sad, but **no dimming** of others. Nowhere often signals shutdown / numbness, which has therapeutic significance, but is not deterministic — someone may feel "nothing" while objectively happy or angry. We highlight Sad gently and leave the rest of the picker at full opacity.

For v1, the mapping table is keyed by `BodyRegion` only — no consideration for region-specific modifiers like "fists vs open hands." That nuance is deferred (see Out of Scope).

### Personalization layer

Three mechanisms, in priority order:

1. **Explicit override** (highest). User picks region → cores in Settings → Body map. Stored in `UserBodyMap`, a SwiftData `@Model` for CloudKit sync.
2. **Learned mapping** (medium). When `count[region][secondary] / count[region][total] >= 0.6` AND `count[region][total] >= 5`, the learned secondary becomes the default secondary highlight when that region is picked.
3. **Curated default** (lowest). Ships in `BodyEmotionMap.swift`.

The soft nudge surfaces on Step 2 when the learned criterion is met and no override exists. Accepting writes an explicit override, equivalent to the user editing it in Settings.

A "Learn from history" toggle lives in Settings → Body map. Default on. Off = stick to defaults + explicit overrides only (learned mappings are ignored).

## Settings Additions

### Settings → Check In flow (new screen)

Single screen with these sections:

- **Picker style** — Wizard / Wheel. Backed by existing `checkInMode`.
- **Body First** — On / Off. Backed by existing `checkInBodyFirst`. Defaults on for new installs.
- **Body view** — Chips / Silhouette. New `checkInBodyView`. Defaults to Chips.
- **Steps** — list of dimensions with on/off toggles for promoting to first-class steps:
  - Where in your body — read-only on/off; tracks `checkInBodyFirst`.
  - Sensations — default off.
  - Feeling — read-only "Required."
  - Strength — default on.
  - Context — default off.
  - Triggers — default off.
  - Coping — default off.
  - Mood scale — default off.
  - Reflect — read-only "Always last."

The promoted-step toggles persist as a single CSV in `checkInPromotedSteps` AppStorage (default `"strength"`).

### Settings → Body map (new screen)

- **Learn from history** toggle (`checkInLearnFromHistory`, default on).
- One row per `BodyRegion` (excluding `nowhere`):
  - Region name on the left.
  - Effective cores on the right (override > learned > default), as small core-tag chips. Override-marked rows display a `★` glyph.
  - Edit affordance opens a multi-select chip picker for the 5 cores; Save writes an override into `UserBodyMap`.
- **Reset to defaults** button at the bottom — clears all `UserBodyMap` entries.

## Data Model Changes

### `BodyRegion` enum (existing)

Add `case nowhere` after `wholeBody`. `displayName` map updated.

### `BodyEmotionMap` (new, static)

```swift
enum BodyEmotionMap {
    /// Curated defaults table (the table from "Default mapping" above).
    static func defaultCores(for region: BodyRegion) -> [String]

    /// Resolves the effective suggested cores for a set of regions, applying
    /// override > learned > default precedence and intersect-then-union narrowing.
    static func suggestedCores(
        for regions: Set<BodyRegion>,
        overrides: UserBodyMap?,
        learned: LearnedBodyMap?
    ) -> Set<String>
}
```

### `UserBodyMap` (new, persisted)

SwiftData `@Model` for CloudKit sync.

```swift
@Model
final class UserBodyMap {
    var entries: [UserBodyMapEntry] = []
    init() {}
}

struct UserBodyMapEntry: Codable, Hashable {
    let regionRaw: String      // BodyRegion.rawValue
    let coreIDs: [String]      // 1+ EmotionCore.id values
}
```

One singleton record per user (matching the existing single-CloudKit-zone pattern).

### `LearnedBodyMap` (new, computed)

```swift
struct LearnedBodyMap {
    /// For each region, the count of times each secondary co-occurred with that region.
    let counts: [BodyRegion: [String: Int]]      // [region: [secondary: count]]
    let totals: [BodyRegion: Int]                // [region: total logs containing it]

    /// Returns the most-co-occurring secondary if pattern is strong (>=60% AND >=5 samples).
    func dominantSecondary(for region: BodyRegion) -> String?

    static func compute(from logs: [FeelingLog]) -> LearnedBodyMap
}
```

Computed on demand at the start of a check-in session, cached for the duration of that session. Not persisted.

### `FeelingLog`

No new fields. Existing fields cover everything needed.

### `AppStorage` keys

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `checkInBodyView` (new) | String | `"chips"` | "chips" or "silhouette" |
| `checkInPromotedSteps` (new) | String | `"strength"` | CSV of step keys |
| `checkInLearnFromHistory` (new) | Bool | `true` | Allow pattern-based suggestions |
| `checkInMode` (existing) | String | `"Wizard"` | Wizard or Wheel |
| `checkInBodyFirst` (existing) | Bool | `true` | Adds body step at start |

## Files Touched

### New
- `OpenFeelings/Views/CheckInWizard/CheckInFlowEngine.swift` — pure value type computing the step list.
- `OpenFeelings/Views/CheckInWizard/CheckInStepKind.swift` — enum (`body`, `feeling`, `strength`, `sensations`, `context`, `triggers`, `coping`, `mood`, `reflect`).
- `OpenFeelings/Views/CheckInWizard/Steps/BodyStep.swift`
- `OpenFeelings/Views/CheckInWizard/Steps/FeelingStep.swift`
- `OpenFeelings/Views/CheckInWizard/Steps/StrengthStep.swift`
- `OpenFeelings/Views/CheckInWizard/Steps/SensationsStep.swift`
- `OpenFeelings/Views/CheckInWizard/Steps/ContextStep.swift`
- `OpenFeelings/Views/CheckInWizard/Steps/TriggersStep.swift`
- `OpenFeelings/Views/CheckInWizard/Steps/CopingStep.swift`
- `OpenFeelings/Views/CheckInWizard/Steps/MoodStep.swift`
- `OpenFeelings/Views/CheckInWizard/Steps/ReflectStep.swift`
- `OpenFeelings/Views/CheckInWizard/Components/StepProgressBar.swift`
- `OpenFeelings/Views/CheckInWizard/Components/StepHeader.swift` (title, sub, badge)
- `OpenFeelings/Views/CheckInWizard/Components/StepNav.swift` (Back, Skip, Continue/Save)
- `OpenFeelings/Views/CheckInWizard/Components/SelectedFeelingBadge.swift`
- `OpenFeelings/Views/CheckInWizard/Components/BodySilhouetteView.swift`
- `OpenFeelings/Views/CheckInWizard/Components/MoreDetailDisclosure.swift`
- `OpenFeelings/Views/CheckInWizard/Components/PersonalizationNudge.swift`
- `OpenFeelings/Models/BodyEmotionMap.swift`
- `OpenFeelings/Models/UserBodyMap.swift`
- `OpenFeelings/Models/LearnedBodyMap.swift`
- `OpenFeelings/Views/Settings/CheckInFlowSettingsView.swift`
- `OpenFeelings/Views/Settings/BodyMapSettingsView.swift`

### Modified
- `OpenFeelings/Views/CheckInView.swift` — major rewrite as orchestrator. Uses `CheckInFlowEngine` to build the step list, dispatches each step to its kind-specific view.
- `OpenFeelings/Models/BodyTaxonomy.swift` — add `nowhere` case + `displayName`.
- `OpenFeelings/Views/SettingsView.swift` — add nav links to `CheckInFlowSettingsView` and `BodyMapSettingsView`. Remove the existing inline Body First / Picker mode toggles since they now live one screen deeper.
- `OpenFeelings/OpenFeelingsApp.swift` — register `UserBodyMap` in the SwiftData ModelContainer schema.
- `OpenFeelings.xcodeproj/project.pbxproj` — auto-regenerated by xcodegen.

### Untouched
- `FeelingLog.swift`
- `EmotionTaxonomy.swift`
- All Insights views and dataset
- Today, History, Intentions views
- LockGateView, RootView

## Tests

- **`CheckInFlowEngineTests`** — given `(bodyFirst, promotedSteps)`, produces expected step list. Covers all 32 combinations of the promoted-step toggle (5 dimensions × 2 each, plus 2 BF states; trim with parameterized tests).
- **`BodyEmotionMapTests`** — defaults, narrowing intersection, fallback to union when intersection empty, override + learned + default precedence, Everywhere and Nowhere edge cases.
- **`UserBodyMapTests`** — write override, read back, reset, Codable round-trip.
- **`LearnedBodyMapTests`** — pattern computation, threshold logic (≥6/8 with min 5 samples), correct precedence.
- **`BodyTaxonomyTests`** — `nowhere` round-trips through `parseList` / `encodeList`, displayName is correct.
- **Snapshot tests** — one per `CheckInStepKind`, verifying the step renders correctly on a 6.1" iPhone in light + dark.

## Out of Scope

- **Region-specific sensation modifiers** ("Chest + fists narrows tighter than Chest + open hands"). v1 maps purely by region.
- **Editing body→core map at the secondary level.** First pass is core-level only; secondary patterning is computed implicitly from the user's history.
- **Onboarding for the Body First setting.** Most users get the default; we don't introduce a tutorial.
- **In-flight check-in migration.** If a user has unsaved state when upgrading to the new wizard, draft state resets. Acceptable for an early-stage app.
- **Wheel-mode body→core highlighting.** Wheel users see the wheel as today; the body suggestion only modifies the Wizard picker. Wheel parity is a polish v2 if requested.
- **Localization of body→emotion mappings.** Assumes Western somatic-emotion conventions; not internationalized in v1.
- **Tappable silhouette zone accessibility (VoiceOver) polish.** v1 ships silhouette mode with basic VoiceOver labels per zone; deeper rotor-navigation polish is deferred.

## Open Questions

1. **Default mapping clinical review.** The table is speculative. A clinical review pass before shipping to general users is recommended (already on the broader roadmap).
2. **Reset to defaults prominence.** Default: a normal-weight button at the bottom of Settings → Body map. Could be hidden behind a destructive-action confirmation if risk grows.
3. **Silhouette back view.** v1 ships front-only; "Back" remains a chip below the silhouette. If users find this clunky, consider a small front/back toggle in v2.

## Verification

- **Manual flow walk-through:**
  - Default flow with Body First on: Where → Feeling → Strength → Reflect.
  - Body First off: Feeling → Strength → Reflect.
  - Promote Context and Triggers: Body → Feeling → Context → Triggers → Strength → Reflect.
- **Body suggestion narrowing:**
  - Pick Chest → confirm Step 2 highlights Angry, Happy, Fearful.
  - Add Hands → confirm same set (no narrowing for that combo).
  - Pick Stomach + Legs → confirm only Fearful highlighted.
  - Pick Everywhere → confirm no cores dimmed.
  - Pick Nowhere → confirm Sad lit up; others dimmed but tappable.
- **Personalization nudge:**
  - Save 6 check-ins with Chest + Anxious. On the 6th + later, confirm the soft nudge appears on Step 2 with "You've picked Anxious 6 of 8 times for Chest. Save as your default?"
  - Tap Save → confirm an override row appears in Settings → Body map with `★`.
  - Future check-ins where Chest is selected immediately default-highlight Anxious.
- **Settings → Body map:**
  - Edit Chest → multi-select chip modal opens. Pick Sad only. Save. Confirm Step 2 now highlights Sad when Chest is picked.
  - Reset to defaults → confirm all overrides cleared.
- **Tests:** `xcodebuild test` runs green; all new tests pass.
- **Build:** `xcodebuild -scheme OpenFeelings build` runs green.
