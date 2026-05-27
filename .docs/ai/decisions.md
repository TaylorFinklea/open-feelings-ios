# Decisions

> Architecture decision records. Append-only — one entry per decision.

<!-- Template for each entry:

## [YYYY-MM-DD] Decision Title

**Context**: What prompted this decision?
**Decision**: What was chosen?
**Alternatives considered**: What else was evaluated?
**Rationale**: Why this over the alternatives?
-->

## [2026-05-27] ThoughtRecord wizard: convert draft to `@Observable` class

**Context**: After the CloudKit Production schema deploy (see prior entry), the deferred `CD_ThoughtRecord` was blocked by an iOS 26 SwiftUI bug: the wizard's Confirm step rendered every draft field empty even after the user typed in each step. `ThoughtRecordFlowView` was the only wizard using `NavigationStack(path:)` + `.navigationDestination(for: Step.self)` over a value-type `@State var draft: ThoughtRecordDraft`. Both other multi-step wizards in the codebase (`CheckInView`, `SortFlowView`) use a single-root + switch pattern, and `SortFlowView` specifically uses an `@Observable` class for shared state.
**Decision**: Convert `ThoughtRecordDraft` from a value-type `struct: Equatable` to `@Observable final class`. Change all six step views from `@Binding var draft` to `@Bindable var draft`. Introduce a nested `struct Snapshot: Equatable` for the cancel-confirm dirty check, since two references to the same class instance can't meaningfully be compared with `==` after one of them has been mutated.
**Alternatives considered**: (a) Refactor the wizard from push-based navigation to a single-root + step switch (matching `CheckInView`). Larger diff; loses native push animations and back chevron. (b) Both: convert to class AND drop `navigationDestination`. Overkill — the class fix alone resolves the bug class.
**Rationale**: The class fix is the smallest diff that eliminates the bug class. It aligns with `SortSession` (the closest peer pattern) and is the iOS 17+ recommended idiom. Native push navigation has UX value and we keep it. Added `OpenFeelingsUITests/ThoughtRecordWizardUITests.swift` as regression coverage — the prior 33 unit tests covered the struct's logic but never exercised SwiftUI binding plumbing, which is why the bug shipped.

## [2026-05-23] Split CloudKit Production Schema Deploy — Defer `CD_ThoughtRecord`

**Context**: While populating the CloudKit Development schema in preparation for the first Production deploy after builds 21–30, the ThoughtRecord wizard was discovered to be unsaveable on iOS 26 (Confirm step shows all draft fields empty even after the user typed in every step). The wizard's required-field validation correctly greys Save, so no `CD_ThoughtRecord` records can ever be written from the device, leaving SwiftData unable to declare that record type to CloudKit. The CloudKit Production deploy was already mid-flight.
**Decision**: Deploy 7 of 8 record types now (FeelingLog, Intention, CustomBodyRegion, CustomValue, ValueSort, CommittedAction, UserBodyMap) with their 6 queryable indexes. Fix the wizard bug in a follow-up build (32), then run a second additive Production deploy to add `CD_ThoughtRecord` + its `CD_createdAt` index.
**Alternatives considered**: (a) Fix the wizard bug now and deploy all 8 types in one go. (b) Insert a `ThoughtRecord` via a one-shot test/script on the device to coerce SwiftData into declaring the type, then deploy all 8 at once.
**Rationale**: CloudKit Production schema is strictly additive — a second deploy adding one type and one index is a normal, safe operation. Option (a) blocks unblocking TestFlight sync for the seven types that *do* work, which is the higher-value outcome (sync is the M2 blocker). Option (b) declares a type to Production whose code path can't actually write it, which would leave a permanently-empty record type in production forever if the wizard fix were ever abandoned or scoped down.

## [2026-04-28] Use Original MIT Emotion Taxonomy

**Context**: The app needs a complete feelings wheel while remaining fully MIT licensed.
**Decision**: Use an original 8 x 4 x 3 taxonomy authored for this app rather than copying Junto, Willcox, or CC BY-SA wheel content.
**Alternatives considered**: Reusing Open Emotion Wheel under CC BY-SA, or matching familiar copyrighted wheel layouts.
**Rationale**: Original content keeps the whole repo MIT-compatible and avoids licensing ambiguity around wheel text and arrangement.

## [2026-04-28] Local-First SwiftData With Optional Apple Platform Integrations

**Context**: The app should store everything locally, sync through iCloud, and optionally tap Apple Health.
**Decision**: Use SwiftData with a private CloudKit database configuration for app logs, local notifications for reminders, LocalAuthentication for app lock, and write-only HealthKit State of Mind samples when explicitly enabled.
**Alternatives considered**: A custom CloudKit layer, Core Data, third-party sync, or reading broader Health data in v1.
**Rationale**: SwiftData/CloudKit matches the local-first iCloud requirement with minimal infrastructure, and write-only HealthKit limits privacy and review scope for v1.

## [2026-04-28] Use Open Emotion Wheel Taxonomy With Separate Content License

**Context**: The user wanted an attributed feelings wheel a therapist is more likely to accept than an app-authored taxonomy, and was open to a non-MIT content license if attribution is required.
**Decision**: Supersede the original MIT emotion taxonomy with an adapted Open Emotion Wheel v1.1 taxonomy by David Thorpe. Keep source code under MIT, and document the adapted taxonomy content under CC BY-SA 4.0 in `ATTRIBUTION.md`, `DATA-LICENSE.md`, and Settings.
**Alternatives considered**: Keeping the original app-authored MIT taxonomy, copying familiar copyrighted wheel layouts, or using Geneva Emotion Wheel materials with unclear/non-free distribution terms for this app.
**Rationale**: Open Emotion Wheel provides explicit attribution and reuse terms, includes therapist/counsellor use language, and avoids unlicensed copying of familiar wheel content.

## [2026-04-28] Disable CloudKit Store For Simulator Builds

**Context**: Unsigned simulator launches do not carry the CloudKit entitlement needed by SwiftData's CloudKit-backed configuration, causing simulator-only startup crashes.
**Decision**: Use an in-memory store for tests, a local SwiftData store for simulator builds, and the private CloudKit-backed store for device builds.
**Alternatives considered**: Requiring signed simulator builds, adding launch-only test hooks, or disabling CloudKit for all debug builds.
**Rationale**: This keeps simulator development reliable without changing the real device/App Store CloudKit behavior.

## [2026-04-29] Keep Wheel Interactions As A Viewport Transform

**Context**: The wheel needs pinch zoom, rotation, and panning without breaking sector selection.
**Decision**: Keep gesture state local to `EmotionWheelView`, apply it as a viewport transform, and invert that transform before running existing wheel hit-testing.
**Alternatives considered**: Mutating the taxonomy layout angles directly during rotation, or splitting the zoomed wheel into a separate detail view.
**Rationale**: A viewport transform keeps the emotion layout stable, preserves existing selection logic, and makes the coordinate math small enough to unit test.

## [2026-04-29] Use Original Clinically Informed Definition Text

**Context**: Selected emotions need descriptions that are credible for therapy-adjacent reflection without copying proprietary clinical dictionary entries.
**Decision**: Store original short educational summaries in `EmotionDefinitions.swift`, cite APA/NIH/NIMH/NIH Clinical Center references in docs and Settings, and show the selected definition in the check-in composer.
**Alternatives considered**: Copying verbatim definitions from clinical dictionaries, leaving definitions out of the app, or using unsourced generated descriptions.
**Rationale**: Original summaries avoid copyright/license issues while keeping the source basis visible. The explicit disclaimer keeps the feature scoped to reflection rather than diagnosis or treatment.

## [2026-04-30] Use ShapeStyle Wrapper (OFColor) Instead of UIColor.dynamicProvider for Warm-Calm Tokens

**Context**: SourceKit's per-file indexer was unable to resolve UIKit when indexing files in `OpenFeelings/Design/` in isolation, even though `xcodebuild` succeeded. Every file that imported UIKit or used `UIColor.dynamicProvider` showed false-positive "No such module 'UIKit'" diagnostics in the IDE.
**Decision**: Implement `OFColor` as a `ShapeStyle` that resolves at draw time via `EnvironmentValues.colorScheme`. Each token stores `lightHex`/`darkHex` strings and uses a self-contained hex parser so the file is SourceKit-indexable without cross-file dependencies.
**Alternatives considered**: `UIColor.dynamicProvider`, a `Color` extension with dark-mode overrides via `.init(uiColor:)`, or a static lookup table keyed on `ColorScheme`.
**Rationale**: Pure SwiftUI, zero UIKit dependency, IDE-clean. The `resolve(in:)` protocol method lets `OFColor` drop into any ShapeStyle context.
**Tradeoff**: `Color.OF.X` returns `OFColor`, not `Color`. The few places that need a literal `Color` (`.tint`, function parameters) must call `.color(for: scheme)` — a minor but explicit conversion.

## [2026-04-30] Save Flow Switches to Today and Surfaces a 2-Second Ribbon There

**Context**: The previous `CheckInView` showed a 2-second inline toast after saving. Product feedback: the check-in screen is a transient task; after saving the user should land on a calming "home" space.
**Decision**: `AppNavigation` gains a transient `savedRibbon` property (auto-cleared after 2 s). `save()` in `CheckInView` calls `navigation.ribbonAfterSave()` then animates `navigation.select(.today)`. `TodayView` renders the ribbon at the top via `safeAreaInset(edge: .top)` with a `.move(edge: .top).combined(with: .opacity)` transition, gated behind `accessibilityReduceMotion`.
**Alternatives considered**: Inline toast in `CheckInView`, a full-screen confirmation sheet, or no visual confirmation.
**Rationale**: Reinforces the "Today is home" mental model and gives users a calm landing space after a check-in. The ribbon is brief and non-blocking.
**Tradeoff**: Slightly more state on `AppNavigation`; coordination spans two views (`CheckInView` writes, `TodayView` reads). The ribbon's reduce-motion path (no animation) means it appears/disappears instantly — acceptable.
