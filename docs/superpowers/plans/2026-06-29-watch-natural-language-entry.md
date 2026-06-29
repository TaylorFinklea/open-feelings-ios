# Watch Natural-Language Entry — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add natural-language check-in entry to the Apple Watch — in-app dictation and a watch Siri Shortcut — by reusing the iOS `KeywordFeelingParser` on watchOS.

**Architecture:** Split `ParsedFeeling.toDraft()` (iOS-only) so the parser is Foundation-only, add the four `NaturalLanguage` files to the watch target, map `ParsedFeeling` → the watch's `CheckInWizardState`, and feed the existing confirm/picker + `WatchCheckInPayload` send path. A watch `AppIntent` sends via a hoisted shared `WatchSessionClient`.

**Tech Stack:** Swift 6, SwiftUI, WatchConnectivity, AppIntents (all first-party). watchOS 26 target. XCTest. xcodegen.

**Spec:** `docs/superpowers/specs/2026-06-29-watch-natural-language-entry-design.md` — read it first.

## Global Constraints

- **Branch** `feat/watch-natural-language-entry`, stacked on `feat/natural-language-entry` (which carries the iOS parser). Already created; the spec is committed.
- **No third-party SDKs / network** — first-party only. No new `captureSource` (watch entries stay `"watch"`).
- **The watch target lists sources explicitly** (`project.yml`), so the 4 NaturalLanguage files need individual entries; new files under `OpenFeelingsWatch/` are auto-globbed (`path: OpenFeelingsWatch`). Run **`xcodegen generate`** after any new file or `project.yml` change.
- **Test framework: XCTest** (`@MainActor final class … : XCTestCase`, no Swift Testing). **No watchOS XCUITest.**
- **Simulators:** iOS regression tests on `iPhone 16` (id `BDF51260-184B-4311-B564-A5C2645847BD`). Watch tests/build need a **watchOS simulator** — find one with `xcrun simctl list devices available | grep -i watch` and use `-destination 'platform=watchOS Simulator,name=<that sim>'` with `-scheme OpenFeelingsWatch`. (The docs mention an "OF Watch Test" / Apple-Watch-Series-11 sim; if absent, any available watch sim works.)
- **Staging:** after `xcodegen generate`, stage with `git add OpenFeelings OpenFeelingsWatch OpenFeelingsTests OpenFeelingsWatchTests docs OpenFeelings.xcodeproj project.yml`.
- **Emotion cores:** Happy, Sad, Angry, Fearful, Disgusted. "Anxious" is a secondary under Fearful; "Nervous" a specific under "Threatened".
- Commit after every task.

---

## Task 1: Split `ParsedFeeling.toDraft()` into an iOS-only file

Makes `ParsedFeeling` Foundation-only so it compiles for watchOS, without changing iOS behavior.

**Files:**
- Modify: `OpenFeelings/NaturalLanguage/ParsedFeeling.swift` (remove `toDraft()`)
- Create: `OpenFeelings/Views/CheckInWizard/ParsedFeeling+Draft.swift` (iOS-only — under `Views/`, which the watch target does not glob)
- Test: existing `OpenFeelingsTests/ParsedFeelingTests.swift` (must stay green — this is a behavior-preserving move)

**Interfaces:**
- Produces: `ParsedFeeling` struct stays Foundation-only; `ParsedFeeling.toDraft() -> CheckInDraft` moves to the iOS extension, unchanged.

- [ ] **Step 1: Move the method.** In `OpenFeelings/NaturalLanguage/ParsedFeeling.swift`, delete the `toDraft()` method (currently lines ~19-29) so the file ends after `rawUtterance`. The struct becomes:

```swift
// OpenFeelings/NaturalLanguage/ParsedFeeling.swift
import Foundation

/// The result of parsing one natural-language utterance into a (possibly
/// partial) feeling. Pure value type — no SwiftData / SwiftUI / Siri / FM.
/// `core == nil` means nothing in the taxonomy matched; `rawUtterance` is
/// always preserved so the user's words are never lost. Shared iOS + watchOS.
struct ParsedFeeling: Equatable {
    enum Confidence { case high, low, none }

    var core: EmotionCore?
    var secondary: EmotionSecondary?
    var specific: EmotionSpecific?
    var intensity: Int?
    var note: String
    var confidence: Confidence
    var rawUtterance: String
}
```

- [ ] **Step 2: Create the iOS-only extension** with the exact method that was removed:

```swift
// OpenFeelings/Views/CheckInWizard/ParsedFeeling+Draft.swift
import Foundation

extension ParsedFeeling {
    /// Map into the existing wizard draft (iOS) so both surfaces reuse the same
    /// persistence + review UI. Leaves `selection` nil when no core resolved.
    /// iOS-only: CheckInDraft lives in the iOS Views layer.
    func toDraft() -> CheckInDraft {
        var draft = CheckInDraft()
        if let core {
            draft.selection = EmotionSelection(core: core, secondary: secondary, specific: specific)
        }
        draft.note = note
        draft.includeIntensity = intensity != nil
        draft.intensity = Double(intensity ?? 3)
        return draft
    }
}
```

- [ ] **Step 3: Regenerate + run the iOS tests that exercise `toDraft`**

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/ParsedFeelingTests 2>&1 | tail -15`
Expected: PASS (3 tests) — the move is behavior-preserving. Also confirm the app builds: `xcodebuild build -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3` → `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add OpenFeelings/NaturalLanguage/ParsedFeeling.swift OpenFeelings/Views/CheckInWizard/ParsedFeeling+Draft.swift OpenFeelings.xcodeproj project.yml
git commit -m "Split ParsedFeeling.toDraft into an iOS-only extension"
```

---

## Task 2: Add the parser to the watch target

**Files:**
- Modify: `project.yml` (OpenFeelingsWatch target `sources:`, currently lines ~44-48)

**Interfaces:**
- Produces: `ParsedFeeling`, `FeelingParser`/`KeywordFeelingParser`/`FeelingParserProvider`, `FeelingSynonyms`, `EmotionTaxonomy.node(named:)`/`allNodeNames` all available in `OpenFeelingsWatch`.

- [ ] **Step 1: Add the four files** to the OpenFeelingsWatch target sources (after the existing `OpenFeelings/Models/BodyTaxonomy.swift` line). The watch list is explicit; do **not** add the `NaturalLanguage/` directory (it contains the iOS-only `PendingQuickEntryStore.swift`):

```yaml
    sources:
      - path: OpenFeelingsWatch
      - path: OpenFeelings/Shared
      - path: OpenFeelings/Models/EmotionTaxonomy.swift
      - path: OpenFeelings/Models/BodyTaxonomy.swift
      - path: OpenFeelings/NaturalLanguage/ParsedFeeling.swift
      - path: OpenFeelings/NaturalLanguage/FeelingParser.swift
      - path: OpenFeelings/NaturalLanguage/FeelingSynonyms.swift
      - path: OpenFeelings/NaturalLanguage/EmotionTaxonomy+Lookup.swift
```

- [ ] **Step 2: Regenerate + build the watch scheme** (this is the verification — it proves the parser compiles for watchOS)

Run: `xcodegen generate && xcodebuild build -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' 2>&1 | tail -4`
Expected: `** BUILD SUCCEEDED **`. (Find `<watch sim>` via `xcrun simctl list devices available | grep -i watch`.) If it fails with a missing-symbol error, a file has a hidden iOS dependency — re-check against Task-1's split (only `toDraft` was iOS-only).

- [ ] **Step 3: Commit**

```bash
git add project.yml OpenFeelings.xcodeproj
git commit -m "Add NaturalLanguage parser files to the watch target"
```

---

## Task 3: `ParsedFeeling` → `CheckInWizardState` mapper

**Files:**
- Create: `OpenFeelingsWatch/Services/CheckInWizardState+ParsedFeeling.swift`
- Test: `OpenFeelingsWatchTests/CheckInWizardStateMapperTests.swift`

**Interfaces:**
- Consumes: `ParsedFeeling` (now in the watch target), `CheckInWizardState` (`core/secondary/specific: Emotion…?`, `intensity: Int = 3`, `note: String`).
- Produces: `CheckInWizardState.apply(_ parsed: ParsedFeeling)`.

- [ ] **Step 1: Write the failing test**

```swift
// OpenFeelingsWatchTests/CheckInWizardStateMapperTests.swift
import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class CheckInWizardStateMapperTests: XCTestCase {
    private var fearful: EmotionCore { EmotionTaxonomy.cores.first { $0.name == "Fearful" }! }
    private var anxious: EmotionSecondary { fearful.secondaries.first { $0.name == "Anxious" }! }

    func testApplyCoreOnlyWithNote() {
        let state = CheckInWizardState()
        state.apply(ParsedFeeling(core: fearful, secondary: nil, specific: nil,
                                  intensity: nil, note: "work is a lot",
                                  confidence: .low, rawUtterance: "work is a lot"))
        XCTAssertEqual(state.core?.name, "Fearful")
        XCTAssertNil(state.secondary)
        XCTAssertEqual(state.note, "work is a lot")
        XCTAssertEqual(state.intensity, 3)   // nil parsed intensity → watch neutral default
    }

    func testApplyThreadsSecondaryAndIntensity() {
        let state = CheckInWizardState()
        state.apply(ParsedFeeling(core: fearful, secondary: anxious, specific: nil,
                                  intensity: 4, note: "before the demo",
                                  confidence: .high, rawUtterance: "anxious 4/5"))
        XCTAssertEqual(state.secondary?.name, "Anxious")
        XCTAssertEqual(state.intensity, 4)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' -only-testing:OpenFeelingsWatchTests/CheckInWizardStateMapperTests 2>&1 | tail -15`
Expected: FAIL — "value of type 'CheckInWizardState' has no member 'apply'".

- [ ] **Step 3: Write the mapper**

```swift
// OpenFeelingsWatch/Services/CheckInWizardState+ParsedFeeling.swift
import Foundation

extension CheckInWizardState {
    /// Seed the watch wizard from a parsed utterance. Body fields are left
    /// untouched (NL doesn't parse them). Intensity defaults to the watch
    /// neutral 3 when the utterance stated none — the watch always records an
    /// intensity (see the routing: a high-confidence parse with no intensity is
    /// routed through the IntensityPicker so the user sets it intentionally).
    /// Callers MUST `reset()` before `apply` (the wizard is a shared instance).
    func apply(_ parsed: ParsedFeeling) {
        core = parsed.core
        secondary = parsed.secondary
        specific = parsed.specific
        intensity = parsed.intensity ?? 3
        note = parsed.note
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' -only-testing:OpenFeelingsWatchTests/CheckInWizardStateMapperTests 2>&1 | tail -15`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add OpenFeelingsWatch/Services/CheckInWizardState+ParsedFeeling.swift OpenFeelingsWatchTests/CheckInWizardStateMapperTests.swift OpenFeelings.xcodeproj project.yml
git commit -m "Add ParsedFeeling -> CheckInWizardState mapper (watch)"
```

---

## Task 4: Parser-on-watch smoke test

Proves the parser links and runs in the watch target (beyond just compiling).

**Files:**
- Test: `OpenFeelingsWatchTests/FeelingParserWatchSmokeTests.swift`

- [ ] **Step 1: Write the test**

```swift
// OpenFeelingsWatchTests/FeelingParserWatchSmokeTests.swift
import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class FeelingParserWatchSmokeTests: XCTestCase {
    func testParserResolvesOnWatch() async {
        let parsed = await FeelingParserProvider.current().parse("really anxious about the demo")
        XCTAssertEqual(parsed.core?.name, "Fearful")
        XCTAssertEqual(parsed.secondary?.name, "Anxious")
        XCTAssertEqual(parsed.intensity, 4)   // "really" → 4
        XCTAssertEqual(parsed.confidence, .high)
    }
}
```

- [ ] **Step 2: Run** (it should pass immediately — the parser already works, this confirms watch linkage)

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' -only-testing:OpenFeelingsWatchTests/FeelingParserWatchSmokeTests 2>&1 | tail -15`
Expected: PASS (1 test). (If it fails to compile, Task 2's target add didn't take — re-run xcodegen.)

- [ ] **Step 3: Commit**

```bash
git add OpenFeelingsWatchTests/FeelingParserWatchSmokeTests.swift OpenFeelings.xcodeproj project.yml
git commit -m "Add parser-on-watch smoke test"
```

---

## Task 5: Hoist `WatchSessionClient` to a shared instance

So the Siri intent shares the app's one `WCSession` delegate + durable queue (avoids a competing second delegate).

**Files:**
- Modify: `OpenFeelingsWatch/Services/WatchSessionClient.swift` (add `static let shared`)
- Modify: `OpenFeelingsWatch/OpenFeelingsWatchApp.swift:9-12` (consume `.shared`)

**Interfaces:**
- Produces: `WatchSessionClient.shared` (one process-wide instance).

- [ ] **Step 1: Add the shared instance.** In `WatchSessionClient.swift`, immediately after the class declaration line `final class WatchSessionClient: NSObject {` (line 9), add:

```swift
    /// One process-wide client. The app and any in-process AppIntent both use
    /// this so there is a single WCSession delegate + a single durable send
    /// queue (a second instance would register a competing delegate on the
    /// WCSession.default singleton). Watch analog of OpenFeelingsModelContainer.shared.
    static let shared = WatchSessionClient()
```

- [ ] **Step 2: Consume it in the app.** In `OpenFeelingsWatchApp.swift`, replace the `init()` (lines 9-12) so the `@State` uses the shared instance:

```swift
    init() {
        _sessionClient = State(initialValue: WatchSessionClient.shared)
    }
```

- [ ] **Step 3: Write a tiny identity test**

```swift
// OpenFeelingsWatchTests/WatchSessionClientSharedTests.swift
import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class WatchSessionClientSharedTests: XCTestCase {
    func testSharedIsSingleInstance() {
        XCTAssertTrue(WatchSessionClient.shared === WatchSessionClient.shared)
    }
}
```

- [ ] **Step 4: Run the test + build the watch app**

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' -only-testing:OpenFeelingsWatchTests/WatchSessionClientSharedTests 2>&1 | tail -15`
Expected: PASS (1 test) and the watch app compiles (the test build compiles the app target).

- [ ] **Step 5: Commit**

```bash
git add OpenFeelingsWatch/Services/WatchSessionClient.swift OpenFeelingsWatch/OpenFeelingsWatchApp.swift OpenFeelingsWatchTests/WatchSessionClientSharedTests.swift OpenFeelings.xcodeproj project.yml
git commit -m "Hoist WatchSessionClient to a shared instance"
```

---

## Task 6: `PendingWatchEntryStore`

The Siri `.none` hand-off store (mirrors iOS `PendingQuickEntryStore`).

**Files:**
- Create: `OpenFeelingsWatch/Services/PendingWatchEntryStore.swift`
- Test: `OpenFeelingsWatchTests/PendingWatchEntryStoreTests.swift`

**Interfaces:**
- Produces: `PendingWatchEntryStore(defaults:)`, `stash(_:)`, read-once `take() -> String?`.

- [ ] **Step 1: Write the failing test**

```swift
// OpenFeelingsWatchTests/PendingWatchEntryStoreTests.swift
import XCTest
@testable import OpenFeelingsWatch

final class PendingWatchEntryStoreTests: XCTestCase {
    private func fresh() -> UserDefaults { UserDefaults(suiteName: "pending-watch-\(UUID().uuidString)")! }

    func testStashThenTakeReturnsNoteOnce() {
        let store = PendingWatchEntryStore(defaults: fresh())
        store.stash("anxious about nothing in particular")
        XCTAssertEqual(store.take(), "anxious about nothing in particular")
        XCTAssertNil(store.take())
    }

    func testTakeWhenEmptyIsNil() {
        XCTAssertNil(PendingWatchEntryStore(defaults: fresh()).take())
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' -only-testing:OpenFeelingsWatchTests/PendingWatchEntryStoreTests 2>&1 | tail -15`
Expected: FAIL — "cannot find 'PendingWatchEntryStore' in scope".

- [ ] **Step 3: Write the store**

```swift
// OpenFeelingsWatch/Services/PendingWatchEntryStore.swift
import Foundation

/// Hands a pending utterance from the watch Siri intent (when no emotion
/// resolved) to the watch app, which consumes it on launch/foreground and
/// opens the check-in flow pre-seeded. The watch intent + app share one
/// process, so plain UserDefaults.standard suffices. Mirrors iOS
/// PendingQuickEntryStore.
struct PendingWatchEntryStore {
    private let defaults: UserDefaults
    private let key = "pendingWatchEntryNote"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func stash(_ note: String) {
        defaults.set(note, forKey: key)
    }

    /// Returns the pending note and clears it (read-once).
    func take() -> String? {
        guard let note = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return note
    }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' -only-testing:OpenFeelingsWatchTests/PendingWatchEntryStoreTests 2>&1 | tail -15`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add OpenFeelingsWatch/Services/PendingWatchEntryStore.swift OpenFeelingsWatchTests/PendingWatchEntryStoreTests.swift OpenFeelings.xcodeproj project.yml
git commit -m "Add PendingWatchEntryStore for the Siri hand-off"
```

---

## Task 7: In-app dictation — `DictationEntryView` + root entry + routing

**Files:**
- Create: `OpenFeelingsWatch/Views/DictationEntryView.swift`
- Modify: `OpenFeelingsWatch/Views/CheckInRootView.swift` (`Step` enum, root mic affordance, `.dictation` destination, parse/seed/route)

**Interfaces:**
- Consumes: `FeelingParserProvider.current().parse`, `CheckInWizardState.apply(_:)`, the existing `Step` cases (`.confirm`, `.intensity`, `.secondary`, `.core`).
- Produces: `Step.dictation`; a `handleDictation()` flow that resets the wizard, applies the parse, and sets `path` by confidence.

- [ ] **Step 1: Create `DictationEntryView`** (mirrors `NoteEntryView`'s focused dictation TextField):

```swift
// OpenFeelingsWatch/Views/DictationEntryView.swift
import SwiftUI

/// "Speak how you feel" capture: a focused TextField that watchOS presents
/// with dictation/scribble on appear (no Speech framework). The parent runs
/// the parse + routing when the user continues.
struct DictationEntryView: View {
    @Binding var text: String
    var onContinue: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("Say how you feel")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("Dictate or type", text: $text, axis: .vertical)
                .focused($focused)
                .submitLabel(.done)
                .lineLimit(1...4)
            Button("Continue", action: onContinue)
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .navigationTitle("Quick entry")
        .onAppear { focused = true }
    }
}
```

- [ ] **Step 2: Wire it into `CheckInRootView`.** Make these edits:

(a) Add `case dictation` to the `Step` enum (after `case sensations`):

```swift
    enum Step: Hashable {
        case dictation
        case sensations
        case core
        case secondary
        case specific
        case intensity
        case note
        case confirm
    }
```

(b) Add a dictation-text `@State` next to the existing `@State private var path`:

```swift
    @State private var dictatedText = ""
```

(c) Add a "Speak" affordance to the root. Put a mic toolbar button on `rootView` inside the `NavigationStack` (non-invasive; doesn't disturb the picker list). Add this `.toolbar` modifier to `rootView` (alongside `.navigationTitle("Check In")`):

```swift
            rootView
                .navigationTitle("Check In")
                .navigationDestination(for: Step.self) { destination(for: $0) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dictatedText = ""
                            path = [.dictation]
                        } label: {
                            Image(systemName: "mic.fill")
                        }
                        .accessibilityLabel("Speak how you feel")
                    }
                }
```

(d) Add the `.dictation` case to `destination(for:)`:

```swift
        case .dictation:
            DictationEntryView(
                text: $dictatedText,
                onContinue: { Task { await handleDictation() } }
            )
```

(e) Add the routing handler (resets the shared wizard, applies the parse, routes by confidence):

```swift
    @MainActor
    private func handleDictation() async {
        let parsed = await FeelingParserProvider.current().parse(dictatedText)
        wizard.reset()           // shared instance: clear stale didSend / body / fields
        wizard.apply(parsed)
        switch parsed.confidence {
        case .high where parsed.intensity != nil:
            path = [.confirm]
        case .high:
            path = [.intensity]  // no intensity stated: let the user dial it before confirm
        case .low:
            path = [.secondary]  // refine the weakly-matched core; picker includes intensity
        case .none:
            path = [.core]       // no emotion: pick from scratch, note carried through
        }
    }
```

- [ ] **Step 3: Build the watch app**

Run: `xcodegen generate && xcodebuild build -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' 2>&1 | tail -4`
Expected: `** BUILD SUCCEEDED **`. (View flow is verified by build + the Task-10 manual device check; watchOS has no reliable XCUITest.)

- [ ] **Step 4: Commit**

```bash
git add OpenFeelingsWatch/Views/DictationEntryView.swift OpenFeelingsWatch/Views/CheckInRootView.swift OpenFeelings.xcodeproj project.yml
git commit -m "Add in-app watch dictation entry + confidence routing"
```

---

## Task 8: Watch Siri intent + App Shortcut

**Files:**
- Create: `OpenFeelingsWatch/AppIntents/WatchCheckInIntent.swift` (intent + `OpenWatchCheckInIntent`)
- Create: `OpenFeelingsWatch/AppIntents/WatchAppShortcuts.swift`
- Test: `OpenFeelingsWatchTests/WatchCheckInIntentTests.swift`

**Interfaces:**
- Consumes: `FeelingParserProvider`, `WatchCheckInPayload(coreID:coreName:secondaryID:…:intensity:note:)`, `WatchSessionClient.shared.send(_:)`, `PendingWatchEntryStore`.
- Produces: `WatchCheckInIntent` with a pure `static func run(phrase:pending:) async -> Outcome`; `enum Outcome { case send(WatchCheckInPayload, spoken: String); case handOff(spoken: String) }`.

- [ ] **Step 1: Write the failing test** (exercises the pure `run`; the WCSession send is left to `perform()`)

```swift
// OpenFeelingsWatchTests/WatchCheckInIntentTests.swift
import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class WatchCheckInIntentTests: XCTestCase {
    func testHighConfidenceBuildsSendPayload() async {
        let outcome = await WatchCheckInIntent.run(phrase: "anxious 4 out of 5")
        guard case let .send(payload, spoken) = outcome else { return XCTFail("expected .send, got \(outcome)") }
        XCTAssertEqual(payload.coreName, "Fearful")
        XCTAssertEqual(payload.secondaryName, "Anxious")
        XCTAssertEqual(payload.intensity, 4)
        XCTAssertTrue(spoken.contains("Anxious"))
    }

    func testNoneStashesAndHandsOff() async {
        let defaults = UserDefaults(suiteName: "watch-intent-\(UUID().uuidString)")!
        let outcome = await WatchCheckInIntent.run(phrase: "zzzz qqqq",
                                                   pending: PendingWatchEntryStore(defaults: defaults))
        guard case .handOff = outcome else { return XCTFail("expected .handOff, got \(outcome)") }
        XCTAssertEqual(PendingWatchEntryStore(defaults: defaults).take(), "zzzz qqqq")
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' -only-testing:OpenFeelingsWatchTests/WatchCheckInIntentTests 2>&1 | tail -15`
Expected: FAIL — "cannot find 'WatchCheckInIntent' in scope".

- [ ] **Step 3: Write the intent.** Mirrors iOS `LogFeelingIntent` (run/perform split, `static let` metadata for Swift 6, `opensIntent` for the `.none` open):

```swift
// OpenFeelingsWatch/AppIntents/WatchCheckInIntent.swift
import AppIntents

struct WatchCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a feeling"
    static let description = IntentDescription("Say how you're feeling and log it from your watch.")
    static let openAppWhenRun = false

    @Parameter(title: "How are you feeling?")
    var phrase: String

    enum Outcome {
        case send(WatchCheckInPayload, spoken: String)
        case handOff(spoken: String)
    }

    /// Pure, testable core: parse, then either build a payload to send or stash
    /// the utterance for the in-app hand-off. The WCSession send happens in perform().
    static func run(
        phrase: String,
        pending: PendingWatchEntryStore = PendingWatchEntryStore()
    ) async -> Outcome {
        let parsed = await FeelingParserProvider.current().parse(phrase)
        guard let core = parsed.core else {
            pending.stash(parsed.rawUtterance)
            return .handOff(spoken: "Let's finish this on your watch.")
        }
        let payload = WatchCheckInPayload(
            coreID: core.id,
            coreName: core.name,
            secondaryID: parsed.secondary?.id,
            secondaryName: parsed.secondary?.name,
            specificID: parsed.specific?.id,
            specificName: parsed.specific?.name,
            intensity: parsed.intensity,
            note: parsed.note.isEmpty ? nil : parsed.note
        )
        let title = parsed.specific?.name ?? parsed.secondary?.name ?? core.name
        let spoken: String
        if parsed.confidence == .high {
            let level = parsed.intensity.map { ", intensity \($0)" } ?? ""
            spoken = "Logged \(title)\(level)."
        } else {
            spoken = "Saved under \(title) — open the app to pin it down."
        }
        return .send(payload, spoken: spoken)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        switch await Self.run(phrase: phrase) {
        case .send(let payload, let spoken):
            WatchSessionClient.shared.send(payload)
            return .result(dialog: IntentDialog(stringLiteral: spoken))
        case .handOff(let spoken):
            // Open the watch app; CheckInRootView consumes the pending note.
            // VERIFY opensIntent against the watchOS AppIntents SDK (fallback:
            // drop the dialog and return .result(opensIntent: OpenWatchCheckInIntent())).
            return .result(opensIntent: OpenWatchCheckInIntent(), dialog: IntentDialog(stringLiteral: spoken))
        }
    }
}

/// Tiny app-opener the .none branch forwards to; opening the watch app triggers
/// CheckInRootView's pending-note consumption.
struct OpenWatchCheckInIntent: AppIntent {
    static let title: LocalizedStringResource = "Finish a feeling on your watch"
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult { .result() }
}
```

```swift
// OpenFeelingsWatch/AppIntents/WatchAppShortcuts.swift
import AppIntents

struct WatchAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: WatchCheckInIntent(),
            phrases: [
                "Log a feeling in \(.applicationName)",
                "Tell \(.applicationName) how I feel"
            ],
            shortTitle: "Log a feeling",
            systemImageName: "mic.fill"
        )
    }
}
```

- [ ] **Step 4: Run the test + build**

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' -only-testing:OpenFeelingsWatchTests/WatchCheckInIntentTests 2>&1 | tail -20`
Expected: PASS (2 tests). If `perform()` fails to compile because the combined `.result(opensIntent:dialog:)` overload is unavailable on watchOS, apply the fallback in the comment (drop the dialog) — the `run` core and the tests stay unchanged.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelingsWatch/AppIntents OpenFeelingsWatchTests/WatchCheckInIntentTests.swift OpenFeelings.xcodeproj project.yml
git commit -m "Add watch Siri intent + AppShortcuts"
```

---

## Task 9: Consume the pending note on app launch

**Files:**
- Modify: `OpenFeelingsWatch/Views/CheckInRootView.swift` (consume `PendingWatchEntryStore` on appear/foreground)

**Interfaces:**
- Consumes: `PendingWatchEntryStore`, `CheckInWizardState.reset()`, `Step.core`.

- [ ] **Step 1: Add scenePhase + consumption.** In `CheckInRootView`, add the environment value near the other `@Environment` lines:

```swift
    @Environment(\.scenePhase) private var scenePhase
```

Add the consumption modifiers to the `NavigationStack` (next to the existing `.onAppear { applyScreenshotModeIfNeeded() }`):

```swift
        .onAppear { consumePendingWatchEntry() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumePendingWatchEntry() }
        }
```

And the function:

```swift
    private func consumePendingWatchEntry() {
        guard let note = PendingWatchEntryStore().take() else { return }
        wizard.reset()
        wizard.note = note
        path = [.core]   // pick the emotion; the note carries through to the payload
    }
```

- [ ] **Step 2: Build the watch app**

Run: `xcodegen generate && xcodebuild build -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' 2>&1 | tail -4`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add OpenFeelingsWatch/Views/CheckInRootView.swift OpenFeelings.xcodeproj project.yml
git commit -m "Consume pending watch entry on launch (Siri hand-off)"
```

---

## Task 10: Integration gate — full suites + manual device checks + handoff

**Files:** none (verification only), then `.docs/ai`.

- [ ] **Step 1: Full watch test suite**

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelingsWatch -destination 'platform=watchOS Simulator,name=<watch sim>' 2>&1 | tail -20`
Expected: all watch tests PASS (existing `CheckInWizardStateTests` / `WatchSettingsStoreTests` + the new mapper / smoke / pending / shared / intent tests).

- [ ] **Step 2: iOS regression guard** (the `toDraft` split must not have regressed iOS)

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/ParsedFeelingTests -only-testing:OpenFeelingsTests/FeelingParserTests -only-testing:OpenFeelingsTests/LogFeelingIntentTests 2>&1 | tail -15`
Expected: PASS (all). Plus a full iOS build: `xcodebuild build -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -3` → `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Manual device checks** (cannot be unit-tested — watchOS Siri + WCSession + dictation need a real paired device or the paired sim pair):
  - **In-app:** open the watch app → tap the mic ("Speak how you feel") → dictate "really anxious about the demo" → high-confidence lands on the confirm screen (Fearful › Anxious, intensity 4, note) → Send → the entry appears on the **phone** (Today/History, "From Apple Watch"). Try "I'm anxious" (no intensity) → routes through the IntensityPicker first. Try gibberish → lands on the core picker with the note pre-filled.
  - **Siri:** run the "Log a feeling in Open Feelings" Shortcut on the watch with "frustrated, 3 out of 5" → it sends and the entry reaches the phone; with unrecognizable input → the watch app opens to the check-in flow with the note pre-filled. If the app-open doesn't fire, apply the Task-8 `opensIntent` fallback.
  - **Offline:** with the phone unreachable, a watch send should queue (existing `WatchSessionClient` behavior) and drain when the phone returns.

- [ ] **Step 4: Update handoff docs** — `current-state.md` (branch, what shipped, pending manual checks + merge order: after the iOS branch), `decisions.md` (the `WatchSessionClient.shared` hoist + the `toDraft` split + the two review-found routing fixes), `roadmap.md` (new item, stacked-branch note). One commit.

```bash
git add .docs/ai
git commit -m "Handoff: watch natural-language entry implemented (pending manual check + merge)"
```
