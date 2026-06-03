# Challenge a Past Journal Entry — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** From the Thoughts tab, let the user start a thought record by picking a past journal entry (one that has a written note) and have the wizard pre-fill the automatic thought from that note while showing the original note as read-only reference.

**Architecture:** A new optional "source chooser" screen becomes the root of the thought-record wizard *only* for the brand-new flow (gated by a new `showsSourceChooser` init flag on `ThoughtRecordFlowView`). Choosing "Challenge a past entry" pushes a `JournalEntryPicker`; selecting a `FeelingLog` mutates the existing draft via a new `applyChallenge(from:)` method (note → `automaticThought`, plus the same situation/intensity/link as the existing `from(log:)`), records the original note for read-only display, and advances into the existing Situation step. The edit flow and the journal-side "Examine this thought" flow are untouched (flag defaults to `false`; `from(log:)` is unchanged).

**Tech Stack:** Swift 6, SwiftUI, SwiftData (`@Query`/`@Model`), XCTest. Project is xcodegen-managed (path-globbed sources — new files under `OpenFeelings/` are picked up by `xcodegen generate`).

**Spec:** `docs/superpowers/specs/2026-06-03-challenge-journal-entry-design.md`

---

## File Structure

**Create:**
- `OpenFeelings/Views/Direction/Thoughts/Steps/SourceChooserStepView.swift` — Step 0 "Challenge a past entry / Start blank".
- `OpenFeelings/Views/Direction/Thoughts/JournalEntryPicker.swift` — list of noted journal entries + `challengeable(_:)` filter helper.

**Modify:**
- `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDraft.swift` — add `applyChallenge(from:)` instance method.
- `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordFlowView.swift` — `showsSourceChooser` flag, `Step.situation` + `Step.pickEntry`, conditional root, `sourceNote` state, pass-through.
- `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordsArea.swift` — both `showingWizard = true` entry points pass `showsSourceChooser: true`.
- `OpenFeelings/Views/Direction/Thoughts/Steps/AutomaticThoughtStepView.swift` — optional `sourceNote` read-only reference block.
- `OpenFeelings/Views/Direction/Thoughts/Steps/ConfirmThoughtRecordView.swift` — optional `sourceNote` read-only section.

**Test:**
- `OpenFeelingsTests/ThoughtRecordDraftTests.swift` — tests for `applyChallenge(from:)` and `from(log:)` non-regression.
- `OpenFeelingsTests/JournalEntryPickerTests.swift` (create) — tests for `challengeable(_:)`.

**Why no model changes:** reuse existing `ThoughtRecord.linkedLogID`. The original note is shown via transient flow state (`sourceNote`), never persisted onto `ThoughtRecord`.

---

## Task 1: `applyChallenge(from:)` draft method

**Files:**
- Modify: `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDraft.swift`
- Test: `OpenFeelingsTests/ThoughtRecordDraftTests.swift`

- [ ] **Step 1: Write the failing tests**

Add to `ThoughtRecordDraftTests.swift`. The existing `sampleLog(intensity:)` helper builds an `angry/Bitter` log with empty note; add an overload that sets the note. Insert this helper just below the existing `sampleLog` (around line 14) and the tests after the `from(log:)` section (around line 56):

```swift
    private func sampleLog(intensity: Int? = 4, note: String) -> FeelingLog {
        let log = sampleLog(intensity: intensity)
        log.note = note
        return log
    }

    // MARK: - applyChallenge(from:)

    func testApplyChallengePrefillsAutomaticThoughtFromNote() {
        let log = sampleLog(intensity: 3, note: "everyone thinks I'm a fraud")
        let draft = ThoughtRecordDraft()
        draft.applyChallenge(from: log)
        XCTAssertEqual(draft.automaticThought, "everyone thinks I'm a fraud")
    }

    func testApplyChallengeCarriesLinkSituationAndIntensity() {
        let log = sampleLog(intensity: 3, note: "everyone thinks I'm a fraud")
        let draft = ThoughtRecordDraft()
        draft.applyChallenge(from: log)
        XCTAssertEqual(draft.linkedLogID, log.id)
        XCTAssertEqual(draft.intensityBefore, 3)
        XCTAssertTrue(draft.situation.contains("Angry"),
                      "Situation should include the emotion path: \(draft.situation)")
        XCTAssertTrue(draft.situation.contains("·"),
                      "Situation should use middle-dot separator: \(draft.situation)")
    }

    func testFromLogStillDoesNotPrefillAutomaticThought() {
        // Non-regression: the journal-side "Examine this thought" flow must be unchanged.
        let log = sampleLog(intensity: 4, note: "I will mess this up")
        let draft = ThoughtRecordDraft.from(log: log)
        XCTAssertEqual(draft.automaticThought, "",
                       "from(log:) must NOT pre-fill automaticThought")
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:
```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:OpenFeelingsTests/ThoughtRecordDraftTests test
```
Expected: FAIL — compile error "value of type 'ThoughtRecordDraft' has no member 'applyChallenge'".

- [ ] **Step 3: Implement `applyChallenge(from:)`**

In `ThoughtRecordDraft.swift`, add this instance method immediately after `static func from(log:)` (after line 75). It reuses the exact situation/intensity logic from `from(log:)` and adds the note → `automaticThought` pre-fill. Mutates `self` (the wizard reuses the same `@State` draft instance, so we cannot return a new one):

```swift
    /// Pre-fill this draft to challenge a past journal entry. Mirrors
    /// `from(log:)` (link + situation + intensity) and additionally seeds
    /// `automaticThought` with the entry's note. Mutates `self` because the
    /// wizard reuses one `@State` draft instance across its steps.
    func applyChallenge(from log: FeelingLog) {
        linkedLogID = log.id
        let time = log.createdAt.formatted(date: .omitted, time: .shortened)
        let path = log.pathTitle.replacingOccurrences(of: " > ", with: " · ")
        situation = path.isEmpty ? time : "\(path) · \(time)"
        intensityBefore = log.intensity
        automaticThought = log.note
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run the Step 2 command. Expected: PASS (all `ThoughtRecordDraftTests`, including the three new ones).

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDraft.swift OpenFeelingsTests/ThoughtRecordDraftTests.swift
git commit -m "Add ThoughtRecordDraft.applyChallenge(from:) for journal-entry challenge"
```

---

## Task 2: `JournalEntryPicker` + `challengeable(_:)` filter

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/JournalEntryPicker.swift`
- Test: `OpenFeelingsTests/JournalEntryPickerTests.swift`

- [ ] **Step 1: Write the failing test**

Create `OpenFeelingsTests/JournalEntryPickerTests.swift`:

```swift
import XCTest
@testable import OpenFeelings

@MainActor
final class JournalEntryPickerTests: XCTestCase {

    private func log(note: String, at seconds: TimeInterval) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "angry" }!
        let selection = EmotionSelection(core: core, secondary: nil, specific: nil)
        let log = FeelingLog(selection: selection, intensity: 3, note: note)
        log.createdAt = Date(timeIntervalSince1970: seconds)
        return log
    }

    func testChallengeableExcludesEmptyAndWhitespaceNotes() {
        let logs = [
            log(note: "real thought", at: 100),
            log(note: "", at: 200),
            log(note: "   \n  ", at: 300),
        ]
        let result = JournalEntryPicker.challengeable(logs)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.note, "real thought")
    }

    func testChallengeablePreservesInputOrder() {
        let newer = log(note: "newer", at: 300)
        let older = log(note: "older", at: 100)
        // Caller passes a reverse-createdAt @Query, so newest is first; the
        // helper must not reorder.
        let result = JournalEntryPicker.challengeable([newer, older])
        XCTAssertEqual(result.map(\.note), ["newer", "older"])
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:OpenFeelingsTests/JournalEntryPickerTests test
```
Expected: FAIL — compile error: cannot find `JournalEntryPicker` in scope (file not yet created / not yet regenerated). If it fails to even compile the test target, that is the expected red state.

- [ ] **Step 3: Create the picker view + helper**

Create `OpenFeelings/Views/Direction/Thoughts/JournalEntryPicker.swift`. The row reuses styling cues from existing thought rows (surface card, OF colors) without embedding `LogCard`:

```swift
import SwiftData
import SwiftUI

/// Picker presented inside the thought-record wizard when the user chooses
/// "Challenge a past entry". Lists journal entries that have a written note,
/// newest first. Selecting one calls `onSelect` with that `FeelingLog`.
struct JournalEntryPicker: View {
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]
    let onSelect: (FeelingLog) -> Void

    /// Entries worth challenging: those with a non-whitespace note. Order is
    /// preserved (the caller's @Query already sorts newest-first).
    static func challengeable(_ logs: [FeelingLog]) -> [FeelingLog] {
        logs.filter {
            !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var entries: [FeelingLog] { Self.challengeable(logs) }

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .navigationTitle("Pick an entry")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var list: some View {
        ScrollView {
            VStack(spacing: CGFloat.OF.sm) {
                ForEach(entries) { log in
                    Button { onSelect(log) } label: { row(for: log) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("thought-record.pick-entry.row")
                }
            }
            .padding(CGFloat.OF.md)
        }
    }

    @ViewBuilder
    private func row(for log: FeelingLog) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.emotionTitle)
                    .font(.OF.body.weight(.semibold))
                    .foregroundStyle(Color.OF.text)
                Spacer()
                Text(log.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            Text(log.note)
                .font(.OF.body)
                .foregroundStyle(Color.OF.textMuted)
                .lineLimit(1)
        }
        .padding(CGFloat.OF.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: CGFloat.OF.sm) {
            Text("Nothing to challenge yet")
                .font(.OF.headline)
                .foregroundStyle(Color.OF.text)
            Text("Journal entries with notes will show up here to challenge.")
                .font(.OF.body)
                .foregroundStyle(Color.OF.textMuted)
                .multilineTextAlignment(.center)
        }
        .padding(CGFloat.OF.lg)
        .frame(maxWidth: .infinity)
    }
}
```

- [ ] **Step 4: Regenerate project so the new files compile**

Run:
```bash
xcodegen generate
```
Expected: "Created project at ...OpenFeelings.xcodeproj". (New files under `OpenFeelings/` and `OpenFeelingsTests/` are path-globbed in `project.yml`.)

- [ ] **Step 5: Run test to verify it passes**

Run the Step 2 command. Expected: PASS (both `JournalEntryPickerTests`).

- [ ] **Step 6: Commit**

```bash
git add OpenFeelings/Views/Direction/Thoughts/JournalEntryPicker.swift OpenFeelingsTests/JournalEntryPickerTests.swift OpenFeelings.xcodeproj
git commit -m "Add JournalEntryPicker for challenging past journal entries"
```

---

## Task 3: Source chooser + wizard gating

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/Steps/SourceChooserStepView.swift`
- Modify: `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordFlowView.swift`
- Modify: `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordsArea.swift`

This task is SwiftUI wiring; verification is a clean build. No unit test (NavigationStack flow is not unit-testable here).

- [ ] **Step 1: Create the chooser view**

Create `OpenFeelings/Views/Direction/Thoughts/Steps/SourceChooserStepView.swift`:

```swift
import SwiftUI

/// Optional Step 0, shown only when the wizard is opened fresh from the
/// Thoughts tab. Lets the user challenge a past journal entry or start blank.
struct SourceChooserStepView: View {
    let onChallengeEntry: () -> Void
    let onStartBlank: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("Where do you want to start?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Challenge something you already wrote, or begin from scratch.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            Button(action: onChallengeEntry) {
                Text("Challenge a past entry").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("thought-record.source.challenge")

            Button(action: onStartBlank) {
                Text("Start blank").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("thought-record.source.blank")

            Spacer()
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Thought record")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Add `showsSourceChooser` + new steps + `sourceNote` to the flow view**

In `ThoughtRecordFlowView.swift`:

(a) Add the stored flag and `sourceNote` state. Replace the property block + `init` (lines 17–30) with:

```swift
    @State private var draft: ThoughtRecordDraft
    private let existingRecord: ThoughtRecord?
    private let showsSourceChooser: Bool

    @State private var path: [Step] = []
    @State private var showingCancelAlert = false
    /// Original journal note when challenging a past entry; shown read-only on
    /// the automatic-thought and confirm steps. Nil for blank/edit/examine flows.
    @State private var sourceNote: String?
    @State private var initialSnapshot: ThoughtRecordDraft.Snapshot?

    init(draft: ThoughtRecordDraft,
         existingRecord: ThoughtRecord? = nil,
         showsSourceChooser: Bool = false) {
        self._draft = State(initialValue: draft)
        self.existingRecord = existingRecord
        self.showsSourceChooser = showsSourceChooser
    }
```

(b) Add the two new step cases. Replace the `enum Step` block (lines 32–39) with:

```swift
    enum Step: Hashable {
        case pickEntry
        case situation
        case automaticThought
        case intensityBefore
        case patterns
        case balancedThought
        case intensityAfter
        case confirm
    }
```

(c) Make the root conditional. Replace the `NavigationStack` root content (lines 47–56) with:

```swift
        NavigationStack(path: $path) {
            Group {
                if showsSourceChooser {
                    SourceChooserStepView(
                        onChallengeEntry: { path.append(.pickEntry) },
                        onStartBlank: { path.append(.situation) }
                    )
                } else {
                    SituationStepView(draft: draft) {
                        path.append(.automaticThought)
                    }
                }
            }
            .toolbar { cancelToolbar }
            .navigationDestination(for: Step.self) { step in
                destination(for: step)
                    .toolbar { cancelToolbar }
            }
        }
```

(d) Handle the new destinations and pass `sourceNote`. In `destination(for:)` (the `switch step` block, lines 84–115): add the `.pickEntry` and `.situation` cases at the top of the switch, and pass `sourceNote` into the automatic-thought and confirm cases. The full updated switch:

```swift
        switch step {
        case .pickEntry:
            JournalEntryPicker { log in
                draft.applyChallenge(from: log)
                sourceNote = log.note
                path.append(.situation)
            }
        case .situation:
            SituationStepView(draft: draft) {
                path.append(.automaticThought)
            }
        case .automaticThought:
            AutomaticThoughtStepView(draft: draft, sourceNote: sourceNote) {
                path.append(.intensityBefore)
            }
        case .intensityBefore:
            IntensityBeforeStepView(draft: draft) {
                path.append(.patterns)
            }
        case .patterns:
            PatternsStepView(draft: draft) {
                path.append(.balancedThought)
            }
        case .balancedThought:
            BalancedThoughtStepView(draft: draft) {
                path.append(.intensityAfter)
            }
        case .intensityAfter:
            IntensityAfterStepView(draft: draft) {
                path.append(.confirm)
            }
        case .confirm:
            ConfirmThoughtRecordView(
                draft: draft,
                sourceNote: sourceNote,
                onSave: save,
                onEdit: { flowStep in
                    path = pathTo(flowStep)
                }
            )
        }
```

(e) Fix the confirm-step "edit Situation" jump. `pathTo(.situation)` currently returns `[]`, which in chooser mode would land on the chooser, not the Situation step. Update the `.situation` case in `pathTo(_:)` (line 122) so it routes through the Situation step explicitly:

```swift
        case .situation:        return [.situation]
```

> Note: for the non-chooser (edit/examine) flow, `Step.situation` is never pushed during normal forward navigation, but the confirm-step "edit" jump now uses `[.situation]` uniformly. `SituationStepView`'s `onContinue` appends `.automaticThought`, so forward navigation from the jumped-to situation step still works in both modes.

- [ ] **Step 3: Wire the Thoughts-tab entry points**

In `ThoughtRecordsArea.swift`, the sheet builds the flow. Update the `.sheet` (lines 29–31) to enable the chooser:

```swift
        .sheet(isPresented: $showingWizard) {
            ThoughtRecordFlowView(draft: ThoughtRecordDraft(), showsSourceChooser: true)
        }
```

Both the empty-hero "Start a record" button and the populated `+` button set `showingWizard = true`, so this single change covers both. (The edit flow in `ThoughtRecordDetail.swift` and the "Examine this thought" flow in `HistoryView.swift` do not pass the flag and keep `showsSourceChooser: false`.)

- [ ] **Step 4: Build to verify everything compiles**

> Depends on Task 4's signature changes to `AutomaticThoughtStepView` / `ConfirmThoughtRecordView` (the `sourceNote` parameter). If executing strictly in order, this step will not compile until Task 4 Step 1 is done. **Do Task 4 Step 1 (the two view signature changes) before building here**, then run:

```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit** (after Task 4 compiles cleanly — commit Tasks 3 + 4 together)

See Task 4 Step 4 for the combined commit.

---

## Task 4: Read-only source-note reference

**Files:**
- Modify: `OpenFeelings/Views/Direction/Thoughts/Steps/AutomaticThoughtStepView.swift`
- Modify: `OpenFeelings/Views/Direction/Thoughts/Steps/ConfirmThoughtRecordView.swift`

- [ ] **Step 1: Add `sourceNote` to both step views**

(a) `AutomaticThoughtStepView.swift` — add the property and a reference block shown above the editable field. Replace the property declarations (lines 6–7) with:

```swift
    @Bindable var draft: ThoughtRecordDraft
    var sourceNote: String?
    let onContinue: () -> Void
```

Then, inside `body`'s outer `VStack` (after the heading `VStack` that ends at line 24, before the `TextField` at line 26), insert the reference block:

```swift
            if let sourceNote, !sourceNote.isEmpty {
                VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                    Text("From your journal entry")
                        .font(.OF.caption.weight(.semibold))
                        .foregroundStyle(Color.OF.textMuted)
                    Text(sourceNote)
                        .font(.OF.body)
                        .foregroundStyle(Color.OF.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CGFloat.OF.md)
                        .background(Color.OF.surface.opacity(0.6),
                                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                }
                .accessibilityIdentifier("thought-record.source-note")
            }
```

(b) `ConfirmThoughtRecordView.swift` — add the property and an extra read-only section. Replace the property declarations (lines 8–10) with:

```swift
    let draft: ThoughtRecordDraft
    var sourceNote: String?
    let onSave: () -> Void
    let onEdit: (FlowStep) -> Void
```

Then, in `body`'s `VStack`, insert a read-only block right after the "Situation" `section(...)` (after line 23, before the "Thought" section). This block has no pencil (the original journal note isn't editable here):

```swift
                if let sourceNote, !sourceNote.isEmpty {
                    VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                        Text("From your journal entry")
                            .font(.OF.caption.weight(.semibold))
                            .foregroundStyle(Color.OF.textMuted)
                        Text(sourceNote)
                            .font(.OF.body)
                            .foregroundStyle(Color.OF.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(CGFloat.OF.md)
                    .background(Color.OF.surface,
                                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                }
```

- [ ] **Step 2: Build to verify it compiles** (this satisfies Task 3 Step 4 too)

Run:
```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Run the full unit-test suite**

Run:
```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:OpenFeelingsTests test
```
Expected: `** TEST SUCCEEDED **` (existing suite + `ThoughtRecordDraftTests` + `JournalEntryPickerTests`).

- [ ] **Step 4: Commit Tasks 3 + 4 together**

```bash
git add OpenFeelings/Views/Direction/Thoughts/Steps/SourceChooserStepView.swift \
        OpenFeelings/Views/Direction/Thoughts/ThoughtRecordFlowView.swift \
        OpenFeelings/Views/Direction/Thoughts/ThoughtRecordsArea.swift \
        OpenFeelings/Views/Direction/Thoughts/Steps/AutomaticThoughtStepView.swift \
        OpenFeelings/Views/Direction/Thoughts/Steps/ConfirmThoughtRecordView.swift \
        OpenFeelings.xcodeproj
git commit -m "Add source chooser + journal-note reference to thought-record wizard"
```

---

## Task 5: Manual verification + handoff docs

- [ ] **Step 1: Manual smoke test in the simulator**

Launch the app (Thoughts tab). Verify:
1. "Start a record" → chooser appears with "Challenge a past entry" + "Start blank".
2. "Start blank" → Situation step, blank, exactly as before.
3. "Challenge a past entry" → picker lists only entries with notes, newest first; entries without notes are absent. (If none exist, the empty state shows.)
4. Select an entry → Situation step pre-filled (path · time); advance → automatic-thought field pre-filled with the note, and a read-only "From your journal entry" block shows the original note.
5. Finish → Confirm shows the "From your journal entry" block; Save → record persists; open it in the list → "From check-in" footer present.
6. From a check-in's "Examine this thought" (History tab share menu) → NO chooser, NO note pre-fill (unchanged).
7. Edit an existing record (pencil) → NO chooser; edits still save.

- [ ] **Step 2: Update handoff docs**

- `.docs/ai/current-state.md`: add a progress bullet (feature: challenge a past journal entry from Thoughts tab; build + tests green).
- `.docs/ai/roadmap.md`: check off the item if present, else add under a completed/Now section.
- `.docs/ai/decisions.md`: append an entry noting the two non-obvious choices — (a) `applyChallenge(from:)` is a *mutating instance method* (not a new `from(log:)` variant) because the wizard reuses one `@State` draft instance; (b) `from(log:)` deliberately left unchanged so the journal-side "Examine this thought" flow keeps its current no-note-prefill behavior.

- [ ] **Step 3: Commit docs**

```bash
git add .docs/ai/
git commit -m "Update handoff docs: challenge-a-journal-entry feature"
```

---

## Self-Review

**Spec coverage:**
- Step-0 chooser, blank-flow-only gating → Task 3 (`showsSourceChooser`, default `false`; edit/examine untouched).
- Picker showing only noted entries, newest first, no search → Task 2 (`challengeable(_:)` + `@Query` reverse sort).
- Pre-fill note → automaticThought + situation/intensity/link → Task 1 (`applyChallenge(from:)`).
- Read-only original note on automatic-thought + confirm steps → Task 4 (`sourceNote`).
- No model changes; reuse `linkedLogID`; "From check-in" footer → free via existing `ThoughtRecordDetail` (verified in Task 5 Step 1.5).
- `from(log:)` unchanged / "Examine this thought" unchanged → Task 1 Step 1 non-regression test + Task 5 Step 1.6.

**Type consistency:** `applyChallenge(from:)` (instance, mutating) used in Task 3 `.pickEntry`. `JournalEntryPicker(onSelect:)` + `challengeable(_:)` used in Tasks 2–3. `sourceNote: String?` parameter added in Task 4 and passed in Task 3 — names/signatures match. `Step.pickEntry` / `Step.situation` added and handled in Task 3.

**Placeholder scan:** none — every code step shows full code.

**Ordering note:** Task 3 build (Step 4) depends on Task 4 Step 1's signature changes; flagged inline. The combined Tasks 3+4 commit lands a compiling state.
