# Paper design polish — design

**Status:** approved (2026-05-29)
**Source:** two local design mockups (V1 "Paper", V2 "Dawn" — JSX prototypes, not committed). Lean Paper; the cool/calm editorial direction is kept, Dawn's warmth is rejected.

## Why

Two design explorations surfaced ideas worth adopting. After cross-referencing against the shipped app (much of Paper is already implemented — segmented control, paper palette, serif display, PaperCard, intensity dots, the Settings modal), six items are genuinely additive. The user picked each below.

## Adopt (6 pieces)

### 1. Direction — Intentions↔Values segmented toggle  *(M, reworks build 37)*
Replace the single stacked scroll (`IntentionsContent` then `ValuesArea`) with a top segmented control that swaps between an **Intentions** view and a **Values** view. Reuse the **existing** segmented-control style (the one in `InsightsView.periodPicker` / `FeelingStep` mode picker: `accentSoft` container, white surface + 0.06 shadow active state) — do **not** build a new one. `DirectionView` holds the selected segment in `@State`; each segment renders the existing `IntentionsContent` / `ValuesArea` unchanged. The Direction tab title stays "Direction". This reworks the build-37 layout but the two sub-areas are untouched internally.
- Files: `OpenFeelings/Views/Direction/DirectionView.swift` (add segment state + control); `IntentionsContent` / `ValuesArea` unchanged.

### 2. Check-in Wizard — one emotion per row  *(M)*
In **Wizard mode only** (Wheel mode untouched — it's the segmented sibling), replace the adaptive 2-column `LazyVGrid` with a full-width vertical stack: one row per option, leading core-colored dot + serif emotion name, tap to drill (core → secondary → specific). Keep the existing "Just \<Core\>" stop-at-any-level pill and the `emotion.<name>` accessibility identifiers (the UI tests depend on them). Use a cool tint (`Color.OF.accentSoft` or the core's wash) behind rows — never Dawn's warm gradient.
- Files: `OpenFeelings/Views/WizardCheckInView.swift` (the `LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))])` and its `emotionGrid` builder).
- Risk: 25 secondaries / 125 specifics now scroll where the grid didn't. Verify drill levels don't feel cramped; keep rows ≥44pt. Re-run the wizard UI tests + the History→edit UI test (CheckInEditView reuses these step views).

### 3. Insights — rename `All` → `Year` (365-day window)  *(S)*
Change `InsightsPeriod.all` to a `.year` semantics: a rolling 365-day cutoff instead of all-time. Control reads **Week / Month / Year** (three segments, matching Paper). The picker control is already built — only the enum case + its date cutoff + label change.
- Files: `OpenFeelings/Models/InsightsDataset.swift` (`enum InsightsPeriod`, the cutoff in `build`); `OpenFeelings/Views/InsightsView.swift` (`periodPicker` label). Update `InsightsDatasetTests` for the renamed case + 365-day window.

### 4. Serif — tighten the existing system serif  *(S)*
Keep `Font.system(design: .serif)` (New York). Tune tracking/weight on display/title tokens for the tighter editorial feel. **No font bundling, no Fraunces dependency.** Do **not** switch button/tab/caption text to serif — the serif-display + sans-metadata split is intentional and matches Paper's own rule.
- Files: `OpenFeelings/Design/DesignTokens.swift` (`Font.OF.display`/`title`; add `.tracking` via a view-modifier or token where applied). Keep changes conservative.

### 5. Intentions — restyle only (no new pills)  *(S–M)*
Adopt Paper's **wash-tinted today-intention card** + **compact past-intentions list** styling. Keep the existing inferred "felt: \<cores\>" line (`IntentionDayFelt`) and the free-text "How did this land?" reflection. **Do not** add Hard/OK/Yes self-rating pills (no new data field). Pure restyle.
- Files: `OpenFeelings/Views/Direction/Intentions/IntentionsContent.swift` (`todayEditor`, `lookBackSection`/`PastIntentionRow`).

### 6. Visual polish (3 sub-items)  *(S each)*
- **6a. Strength circles** — graduated sizes (e.g. 28→48pt) where the selected circle fills with the **selected emotion's core color** + a soft wash halo ring (not flat terracotta). Keep toggle-to-clear, the "Just noticing"↔"Strong" labels, and ≥44pt hit targets; halo respects reduce-motion/transparency. Thread the core color from `draft.selection`. Files: `OpenFeelings/Views/CheckInWizard/Steps/StrengthStep.swift`.
- **6b. Clinical-note card tinted by core** — `EmotionDefinitionCard` takes the selected core's wash background + hairline core-mid border + all-caps "\<Feeling\> — clinical note" caption + serif-italic body. Use the per-core tokens the wheel already uses (`EmotionColorPalette`/`EmotionColor`). Preserve the audited WCAG AA contrast. Files: `OpenFeelings/Views/EmotionDefinitionCard.swift` + call site in `FeelingStep.swift`.
- **6c. Committed-action checkbox** — clearer done-state: rounded checkbox filling with a **cool** accent + white check when done, text strikethrough ~0.55 opacity. Files: the committed-action row under `OpenFeelings/Views/Direction/Values/` (locate the row view; likely `CommittedActionRow`).

## Skip (explicit)
- Dawn's warm palette/gradients/terracotta — the app's cool editorial direction is the opposite.
- Dawn's removals: dropping the clinical-note card, the thought-record situation field, or the richer Insights charts — all deliberately-built features.
- Re-skinning Settings as a draggable bottom-sheet with a scrim — the shipped modal gear (build 37) is what the user liked; keep it.
- Rebuilding the segmented control — already exists and matches Paper.
- Bundling Fraunces / a webfont stack — system serif stays.
- Onboarding hero — net-new surface; tracked as a separate roadmap item, not part of this polish pass.

## Testing
- Mostly view restyles (no logic change) → covered by build + the existing UI suite. Re-run wizard + History→edit UI tests after #2 (shared step views).
- #3 Insights: update `InsightsDatasetTests` for the `.year` rename + 365-day cutoff (real logic change — unit test it).
- #1 Direction toggle: add a small UI test (segment switches content) if the segment exposes an identifier; otherwise rely on build + manual smoke.
- No new SwiftData/CloudKit schema (intentions restyle adds no field).

## Build sequence
1. #3 Insights `.all`→`.year` + tests (isolated, smallest logic change).
2. #4 serif tightening (token tweak).
3. #6a/6b/6c visual polish (independent view edits).
4. #2 wizard one-per-row (touches shared step views — verify UI tests).
5. #1 Direction segmented toggle (reworks build-37 layout; UI test for the toggle).
6. #5 Intentions restyle.
7. Full unit + UI + adversarial review workflow + manual smoke. Ship as build 40.

## Out of scope
- New data fields (intention self-rating pills).
- Onboarding.
- Any Dawn color/tone.
- Custom font bundling.
