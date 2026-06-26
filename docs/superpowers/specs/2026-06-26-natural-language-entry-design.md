# Natural-Language Check-In Entry — Design

**Date**: 2026-06-26
**Branch**: `feat/natural-language-entry` (off `main`)
**Status**: Design — awaiting review before plan
**Revision**: v2 — folds in a three-lens adversarial review (consistency / feasibility / completeness) verified against the codebase. Material corrections from v1 are flagged inline with **[review]**.

## Problem

Saving a check-in means working through a long form: emotion path (core → secondary → specific), optional intensity, a free-text note, body regions + custom regions, body sensations, context (places/people), triggers, coping, and a mood energy/valence scale. Even the person who built it finds it heavy. We want a path where the user can **say or type how they feel in plain language** and get a structured check-in with minimal friction — without breaking the app's "no servers, no third-party SDKs, data stays on device + private iCloud" mission.

## Goals

- Turn one natural-language utterance (typed or dictated) into a saved `FeelingLog`.
- Two surfaces: an **in-app quick-entry** screen (reviewable) and **Siri / App Shortcut** (frictionless, save + spoken read-back).
- Fill **core fields only**: emotion path + intensity (1–5) + note. Everything else stays empty and editable later in the normal check-in flow.
- Never silently mis-tag: when the emotion is uncertain, **stop at the broadest confident level** and keep the full utterance as the note.
- Stay fully on-device. Phase 1 ships a deterministic engine on every device; Phase 2 layers Apple's on-device model behind the same seam.

## Non-Goals

- Parsing body / sensations / context / triggers / coping / mood from language (out of scope for v1 — core fields only).
- Any cloud / network call, third-party SDK, or custom audio-recording UI (dictation is the system keyboard's, not ours).
- Changing the existing wizard or wheel check-in flows (beyond the behavior-preserving `save()` extraction below).
- Watch-side natural-language entry.

## Architecture

One pure, testable seam underlies both surfaces:

```
utterance: String ─▶ FeelingParser ─▶ ParsedFeeling ─▶ CheckInDraft ─▶ FeelingLogService.persist ─▶ (caller-owned health sync)
                     (via Provider)                                     (sync insert+save, returns log)
```

### Phasing seam: `FeelingParser`

A protocol with a single async method (async so the Phase 2 model conforms without changing call sites):

```
protocol FeelingParser {
    func parse(_ text: String) async -> ParsedFeeling
}
```

Two implementations, same protocol:

- **`KeywordFeelingParser`** — Phase 1. Deterministic, ships first, and is the *permanent fallback* + the *test contract oracle*. Implements `parse` synchronously (the body never awaits — Swift allows this with zero friction). **[review]** Declare it `nonisolated` (not `@MainActor`) — a pure `String → struct` type — so `await parser.parse(...)` is callable from any context with no actor hop.
- **`FoundationModelsFeelingParser`** — Phase 2. Wraps Apple's on-device `SystemLanguageModel`. On any unavailability / error / low confidence it **delegates to `KeywordFeelingParser`**, so the user never sees an AI error.

**[review] Composition point — `FeelingParserProvider`.** The parser must reach *both* a SwiftUI view and an AppIntent that has no SwiftUI environment, so injection cannot be `@Environment`. Define a plain, non-SwiftUI factory both surfaces call:

```
enum FeelingParserProvider {
    static func current() -> any FeelingParser   // Phase 1: KeywordFeelingParser(); Phase 2: FM-or-fallback
}
```

`QuickEntryView` and `LogFeelingIntent.perform()` both call `FeelingParserProvider.current()`. The AppIntent must **not** rely on `@Environment`.

### `ParsedFeeling`

A pure value type carrying the result **plus its own confidence**, so each surface can branch on it:

```
struct ParsedFeeling: Equatable {
    var core: EmotionCore?            // best confident core (may be nil)
    var secondary: EmotionSecondary?  // only when confident
    var specific: EmotionSpecific?    // only when confident
    var intensity: Int?               // 1...5, only when stated
    var note: String                  // usable note text (cleaned utterance)
    var confidence: Confidence        // .high / .low / .none
    var rawUtterance: String          // always preserved verbatim — never lose the user's words

    enum Confidence { case high, low, none }

    func toDraft() -> CheckInDraft     // maps into the existing wizard value type
}
```

`toDraft()` reuses the type the wizard already speaks:
- `core/secondary/specific` → `EmotionSelection(core:secondary:specific:)` → `draft.selection`.
- `intensity` → `draft.includeIntensity = (intensity != nil)`, `draft.intensity = Double(intensity ?? 3)`.
- `note` → `draft.note`.

The parser **never** touches SwiftData, SwiftUI, Siri, or FM APIs — it is `String → struct`, trivially unit-testable. The Phase 1 test suite becomes the conformance suite the Phase 2 parser must also pass.

## Shared persistence: extract `FeelingLogService`

**Finding:** the only new-entry save path today is `CheckInView.save()` (`CheckInView.swift:234–270`), inlined in the view, mixing three concerns: (1) build + insert + first-save the `FeelingLog`; (2) a **detached** HealthKit sync that re-saves `healthSyncStatus` later; (3) UI-only effects (`navigation.ribbonAfterSave()`, `navigation.select(.today)`, draft reset). An AppIntent has no `AppNavigation`, and the detached-task timing matters (below).

**Decision:** extract concern (1) into a reusable, UI-free, **synchronous-return** helper. Concern (2) — the health sync — becomes a separate step **the caller owns**, because its timing must differ per surface. Concern (3) stays at each call site.

```
enum FeelingLogService {
    /// Builds, inserts, and first-saves a brand-new FeelingLog from a draft.
    /// Returns immediately with healthSyncStatus == .pending (or .notRequested).
    /// Pure persistence — no navigation, no health await, no view state.
    @MainActor
    static func persist(
        draft: CheckInDraft,
        captureSource: String,
        modelContext: ModelContext,
        healthEnabled: Bool
    ) -> FeelingLog?      // nil only if draft has no complete selection (defensive)

    /// Awaitable health sync + second save. Caller decides when to run it.
    @MainActor
    static func syncHealth(_ log: FeelingLog, healthService: HealthService, healthEnabled: Bool, modelContext: ModelContext) async
}
```

**[review] Behavior-preservation requirements (these were wrong in v1):**
- The `FeelingLog` construction block to move is **`CheckInView.swift:238–256`** — the constructor **plus** `log.customBodyRegionIDs = Array(draft.customBodyRegionIDs)` at line 254 (which lives *outside* the constructor because the init has no slot for raw custom-region IDs) **plus** insert + first `save()`. Moving only 238–251 would silently drop custom body regions from *every* wizard save. The behavior-preservation test **must** assert a draft carrying `customBodyRegionIDs` round-trips onto the saved log.
- **[review]** Thread `captureSource` through the **existing** `FeelingLog(…, captureSource:)` init parameter (`FeelingLog.swift:66`), not a post-construction mutation.
- **[review] Health-sync timing — preserve it exactly:**
  - **`CheckInView.save()`** is refactored to: `persist(…, captureSource: "phone", …)` → existing ribbon / tab-switch / reset → then fire its **existing detached `Task { await FeelingLogService.syncHealth(…) }`**. UI advances immediately; health finishes in the background exactly as today. This is the pure-extraction guarantee.
  - **`QuickEntryView`** mirrors `CheckInView` (detached health task; ribbon + Today).
  - **`LogFeelingIntent`** calls `persist(…, captureSource: "siri", …)` then **`await syncHealth(…)` inline before returning its dialog** — a Siri intent process can be torn down right after `perform()` returns, so a detached task may never complete. Awaiting inline is the only way Siri entries reliably health-sync. No navigation.

### The shared `ModelContainer` (the one genuinely hard wiring task)

**[review] Critical correction.** v1 said "find how the app builds its container and mirror it" — that is *dangerous*. `OpenFeelingsApp` holds the container in `@State private var modelContainer` (`OpenFeelingsApp.swift:6`), built **lazily inside the WindowGroup `.task`** (`:44–48`) by `private static func makeModelContainer()` (`:57–134`), which constructs a **real CloudKit private-DB container** (`cloudKitDatabase: .private(...)`, `:112–116`) and branches across screenshot / XCTest / simulator / cloud configs. Calling `makeModelContainer()` again from the intent yields a **second container over the same store/CloudKit zone in one process** — unsupported, a corruption/conflict risk — and when a Shortcut fires while the app is **not foregrounded**, the `.task` may never have run at all.

**Required refactor (do this first, prove it early):**
- Hoist container ownership to a **single process-level, lazily-initialized shared instance** (e.g. a cached holder `OpenFeelingsModelContainer.shared`) that preserves the existing screenshot/test/simulator/cloud branching. There must be exactly **one** instance.
- The app scene consumes that shared instance (instead of its own `@State` factory call); `LogFeelingIntent.perform()` reads the **same** instance, triggering creation on demand for the backgrounded-Siri case.
- **Explicitly forbid** constructing a second container anywhere.
- Precedent to read, not copy wholesale: **`WatchSyncService`** is the existing "save a `FeelingLog` from outside a view" path (reads `UserDefaults healthEnabled`, builds `FeelingLog(captureSource: "watch")`) — but it receives its container via scene `attach(modelContainer:)`, so it only partially solves the not-running case. The shared-instance hoist is what closes the gap.
- **`HealthService` is the easy part:** it is `@MainActor @Observable` and effectively stateless on the save path (queries `HKHealthStore` fresh in `save()`), so the AppIntent can just instantiate its own `HealthService()` — no shared accessor needed.

## Surface 1 — In-app quick entry

- **Entry point.** Add `showingQuickEntry: Bool` to `AppNavigation` (mirrors `showingSettings`, `AppNavigation.swift:70–74`). Add a button in the Today header (`TodayView.swift` header section), action `navigation.showingQuickEntry = true`. Present via `.sheet(isPresented: $navigation.showingQuickEntry)` in `RootView` (mirrors the Settings sheet, `RootView.swift:54–56`), wrapping the new view in a `NavigationStack`.
- **`QuickEntryView`** — two states:
  1. **Capture.** A `TextEditor` styled like `ReflectStep.swift:38–45` (the system keyboard supplies the dictation mic automatically — no Speech framework). "Continue" runs `await FeelingParserProvider.current().parse(text)` inside a `Task {}`.
  2. **Review.** A compact screen showing the three core fields, all editable inline:
     - **Emotion** — **[review]** the parsed selection shown as a pill; "Change" presents the existing **`FeelingStep`** (verified standalone-reusable: it binds only to `@Binding var draft: CheckInDraft` + `@Environment(\.colorScheme)`/`@AppStorage`; its extra params `suggestedCoreIDs/nudge/onSaveOverride/onDismissNudge` take `[]`/`nil`/no-ops). Note `FeelingStep` brings its own Wizard/Wheel mode segment + `EmotionDefinitionCard` — that is acceptable; we present it as-is rather than building a bespoke picker.
     - **Intensity** — **[review]** there is **no** standalone dots component today (the dots are private helpers inside `StrengthStep`, wrapped in its caption row + card chrome). Phase 1 **extracts an `IntensityDots(draft:)` subview** from `StrengthStep` and reuses it in *both* `StrengthStep` and the Review screen (so the wizard is unchanged and the dots are shared).
     - **Note** — a `TextEditor` pre-filled with `ParsedFeeling.note`.
     - **Save** → `persist(…, captureSource: "phone", …)` → detached health task → ribbon + Today.
- **Low-confidence here is trivial:** in-app *always* shows Review, so `.low` / `.none` just lands the user on Review with the emotion pre-selected at the best core (or empty) and the note filled. Never blocked, never silently mis-tagged.
- In-app quick entries save with `captureSource = "phone"` — by save time they are indistinguishable from a normal entry, so they need no special glyph. (Open question 3 below if we want to mark them.)

## Surface 2 — Siri / App Shortcut

- One in-process `AppIntent` (`LogFeelingIntent`) with a single natural-language `String` parameter, plus an `AppShortcutsProvider` exposing a phrase like *"Log a feeling in Open Feelings."* No SiriKit, no extension, no entitlement / Info.plist changes (verified: iOS 26 target, zero existing intents). New file under `OpenFeelings/AppIntents/`; both types auto-discovered at launch. **[review]** AppShortcuts string localization is **not** required for this single-locale app (phrases use `\(.applicationName)`); deferred.
- **Flow:** phrase → `await FeelingParserProvider.current().parse(text)` → resolve shared container + a fresh `HealthService` → branch on `confidence`:
  - **`.high`** → `persist(captureSource: "siri")` → `await syncHealth` → `IntentDialog` read-back.
  - **`.low`** → still saves at the best confident **core** + note → `await syncHealth` → read-back noting it's approximate.
  - **`.none` (no core resolvable at all)** → **does not fabricate an emotion.** A `FeelingLog` requires a real core, so the intent declines and saves nothing.
- **[review] Read-back wording — resolve consistently to the *node title*** (`EmotionSelection.title`), never the user's vernacular word, so the same input can't be announced two ways:
  - `.high` (a specific resolved): *"Logged: Nervous, intensity 4. Open the app to add more."*
  - `.low` (only a core): *"Saved your note under Fear — open the app to pin down the feeling."*
  - `.none`: *"I couldn't tell how you're feeling, so I didn't save it. Open Open Feelings to jot it down."* → **Open question 1.**
- **[review] `persist` nil contract:** for `.high`/`.low` a core is always present, so `draft.selection` is complete and `persist` returns non-nil. `nil` is a purely defensive guard; if it ever occurs on a `.high`/`.low` branch, Siri reuses the `.none` decline dialog and in-app stays on Review. (So nil-handling is *not* the `.none` path — `.none` never calls `persist`.)
- Siri entries save with `captureSource = "siri"` and render a glyph + VoiceOver label on Today / History.

## `captureSource = "siri"` — glyph + AX

Mirror the `"watch"` rendering at every site (one `else if` each — only one source renders at a time):

- `TodayView.swift:151–157` (row glyph) and `:266–268` (AX label helper)
- `HistoryView.swift:316–322` (LogCard glyph) and `:367–369` (LogCard AX helper)
- `CheckInEditView.swift:87–91` (edit header)
- Tests: add a `"siri"` case alongside `"watch"` in `HistoryViewAXTests.swift:32–40` and `TodayViewAXTests.swift:38–42`.

Proposed glyph `"mic.fill"`, label "Siri" / AX "from Siri" — **final glyph is a polish choice** (Open question 2).

## Taxonomy resolution (parser ↔ emotion tree)

The keyword parser resolves words to taxonomy nodes and builds an `EmotionSelection`. Findings about `EmotionTaxonomy.swift`:

- **Counts:** ~5 cores / 25 secondaries / 50 specifics (implementer: confirm exact counts against the file). **All node names are globally unique** across the tree.
- **[review] "Globally unique" ≠ "always high confidence."** Uniqueness guarantees *which* node a given name maps to (no collisions); it says nothing about how confidently a *vernacular* word maps to a node. The two are orthogonal — see the confidence rule below.
- **Existing helper:** `EmotionTaxonomy.selection(coreID:secondaryID:specificID:)` resolves an ID chain → `EmotionSelection?`. **No name lookup exists** — must add a case-insensitive name index + reverse path (specific → parent secondary → core).
- **Construction:** `EmotionSelection(core:secondary:specific:)` (synthesized memberwise init; `core` mandatory, others optional).

### Synonym table

- **[review] Original authored content only.** The table is **original** (MIT, same as source) — **do not import any third-party emotion lexicon** (NRC EmoLex, WordNet-Affect, LIWC, etc.), each of which carries its own license. Rationale: a hand-authored *word → our node-id* lookup is original authorship, not a reproduction of the CC BY-SA taxonomy's terms or arrangement, so it does not extend the ShareAlike obligation. **Confirm during review** — if you consider it a taxonomy adaptation, relabel it CC BY-SA and add it to `DATA-LICENSE.md` + the Settings "Changes from the source" footer. Give the file a license header either way.
- **[review] File placement — keep it off the watch target.** `EmotionTaxonomy.swift` is compiled into `OpenFeelingsWatch` (`project.yml:47`). Put the name index, synonym table, and parser in a **separate new file** that is **not** added to the watch target (the watch target lists files explicitly, so a new `Models`/`Services` file is excluded by default). Do not add them into `EmotionTaxonomy.swift`.
- **Size & shape:** ~150–200 entries. Each entry maps a phrase → a target node id **and carries a strength** `.strong | .weak`.
- **Invariant test:** every entry's target id resolves to a real node, **and** every entry has a strength tag.

### Keyword parser behavior

- **Resolution = deepest match wins.** A hit on a *specific* → use it; else *secondary*; else *core*; else nothing. This is exactly "stop at best core" and reuses the app's stop-at-any-level semantics (`EmotionSelection.isComplete == true` at core).
- **[review] Confidence rule (now concrete):**
  - An exact match on a **taxonomy node's own name** (any level) → that node, confidence **`.high`**.
  - A match via a **`.strong`** synonym entry → **`.high`**.
  - A match via a **`.weak`** synonym entry (broad/fuzzy, e.g. *"weird" → some core*) → **`.low`**.
  - No match anywhere → **`.none`**.
  - Confidence is the matched entry's tag; node-name hits are always `.high`. (So e.g. authoring *"anxious" → Fear* as `.strong` yields `.high`; *"off" → Sad* as `.weak` yields `.low`.)
- **Intensity scan:** `1`–`5`, `x/5`, `x out of 5`, plus a small word ladder (*a little → 2*, *really / very → 4*, *extremely → 5*). Absent → `nil`.
- **Note:** the cleaned utterance (strip a leading "I feel…"); `rawUtterance` always retained as the safety net.

## Privacy review (required Phase 1 task)

**[review]** The repo asserts the app accesses **no microphone** in four places (`PRIVACY.md:27`, `OpenFeelings/Views/PrivacyPolicyView.swift:47`, `web/src/routes/privacy/+page.svelte:44`, `docs/release/privacy-policy-draft.md:27`), and `docs/release/app-store-privacy-answers.md` says to re-verify on any new data surface. A Siri shortcut that invites users to **speak** their feelings + prominent dictation + a spoken read-back is a new voice surface beside that promise. Phase 1 must:
- Document that voice is processed by **Apple's Siri / keyboard dictation**, not the app — the app still calls no microphone/Speech API (the "no microphone" claim stays technically true).
- Update the four privacy surfaces' prose to pre-empt the apparent contradiction (e.g. a line on Siri/dictation being handled by the OS).
- Run the `app-store-privacy-answers.md` re-verification pass ("Data Not Collected" almost certainly still holds; the convention requires the explicit check).

## Error handling

- `FeelingParser.parse` **cannot throw**. Worst case is `confidence: .none`, `core: nil`, `note: rawUtterance`. No failure state loses the user's words.
- Phase 2 FM parser wraps every model call; any error / unavailability / timeout silently delegates to the keyword parser.
- `persist` returns `nil` only on an incomplete selection (defensive); see the Siri nil contract above.
- Dictation uses the system field — no permission or recording state we own.

## Testing

Repo convention is **XCTest** (no Swift Testing) with an in-memory `ModelContainer` via a `makeContext()` helper; UI tests use `accessibilityIdentifier`s and `launchArguments = ["-uiTestingMode", "1"]`.

- **`OpenFeelingsTests/FeelingParserTests.swift`** — the contract. Table-driven (one `func test…` per case, per repo style): happy path, vernacular synonyms (strong → `.high`, weak → `.low`), intensity forms, ambiguous → core-only, garbage → note-only + `.none`. Phase 2's FM parser must pass this same suite (tolerating an *equally valid* node choice) plus a fallback-delegation test.
- **Synonym-table invariant test** — every entry resolves to a real node **and** has a strength tag.
- **`FeelingLogService` behavior-preservation test** — persist a draft; assert one `FeelingLog` with the right `captureSource`; **assert a draft with `customBodyRegionIDs` round-trips** (guards the extraction); assert `healthSyncStatus == .pending` on return (sync hasn't run yet).
- **`OpenFeelingsTests/LogFeelingIntentTests.swift`** — `@MainActor`, **injectable** in-memory context: parse → `perform()` → fetch asserts a `FeelingLog` with `captureSource == "siri"`, correct selection/intensity/note; plus the `.none` decline path saves nothing. **[review]** The intent must accept an injectable container/context for this test while resolving the shared one in production.
- **[review] Named manual/integration check** (can't be a unit test): a Siri-saved entry appears on Today/History through the app's **real shared container** — this is the only thing that proves the shared-container hoist actually works end-to-end.
- **`OpenFeelingsUITests/QuickEntryUITests.swift`** — smoke: open quick entry → type a sentinel → Continue → Review pre-filled → Save → entry appears.
- **AX tests** — `"siri"` source cases in `HistoryViewAXTests` + `TodayViewAXTests`.

## Phasing / scope boundary

**Phase 1 (this feature's first build) — usable on every device:**
- `FeelingParser` protocol + `FeelingParserProvider` + `ParsedFeeling` + `KeywordFeelingParser` + synonym table + taxonomy name-resolution helpers (in a new, non-watch file).
- Shared-`ModelContainer` hoist (single instance, app + intent consume it).
- `FeelingLogService.persist` + `syncHealth` extraction (+ `CheckInView.save()` refactor) + `captureSource` threaded via init; `IntensityDots` subview extraction.
- `QuickEntryView` (capture + compact review) + `AppNavigation.showingQuickEntry` + Today entry point.
- `LogFeelingIntent` + `AppShortcutsProvider` + `captureSource = "siri"` glyph/AX.
- Privacy-review pass (4 surfaces + answers doc).
- Full test contract above.
- **[review]** Run `xcodegen generate` after adding files (no `project.yml` edits needed — the main target globs `OpenFeelings/`).

**Phase 2 (fast-follow build):**
- `FoundationModelsFeelingParser` behind the same protocol, availability-gated (`SystemLanguageModel` availability + Apple Intelligence enabled + capable hardware), keyword fallback. iOS 26 target already supports it — no deployment bump. Phase 2 code is intentionally **not prescribed here**; the implementer reads Apple's current `FoundationModels` API.

**Explicitly out of scope:** parsing body/sensations/context/triggers/coping/mood; custom voice-recording UI; any cloud path; an "Add more details → full wizard" hand-off from Review (a later follow-up).

## Open questions for review

1. **Siri `.none` (no core resolvable):** decline + ask to open the app (as specified), or instead **launch the app pre-filled** with the note so nothing is lost from a hands-free moment?
2. **Siri glyph:** `"mic.fill"` + "from Siri" acceptable, or a different SF Symbol?
3. **In-app quick-entry source:** keep in-app NL entries as `captureSource = "phone"` (no glyph, as specified), or mark them distinctly?
4. **Synonym-table license:** original MIT (as specified/recommended), or treat as a CC BY-SA taxonomy adaptation?
