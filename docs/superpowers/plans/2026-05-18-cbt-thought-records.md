# CBT Thought Records Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Burns-style six-step thought-record flow under the Direction tab so users can examine and reframe a stuck thought, with an optional entry point from any check-in's share menu.

**Architecture:** A new SwiftData `@Model` (`ThoughtRecord`) plus a string-backed `ThinkingPattern` enum (8 cases) drive a value-type `ThoughtRecordDraft` that hosts in-memory wizard state. The wizard is a `NavigationStack`-based modal (`ThoughtRecordFlowView`) hosting seven step views; the confirm step writes to SwiftData. Direction tab gets a third area (`ThoughtRecordsArea`) for empty/populated states and the list. Detail view (`ThoughtRecordDetail`) re-enters the wizard for edits. LogCard share menu gains a "Examine this thought" entry that pre-fills the draft from the source `FeelingLog`.

**Tech Stack:** SwiftUI, SwiftData, XCTest, iOS 26.0 deployment target, Swift 6.0. Existing design tokens (`Color.OF.*`, `CGFloat.OF.*`, `OFCard`, `OFListRow`, `OFSectionHeader`, `OFEmptyState`) and the pattern from `SortFlowView` / `ValuesArea` / `CommittedActionDetail`.

**Reference reading before starting:**
- `docs/superpowers/specs/2026-05-18-cbt-thought-records-design.md` — the spec this plan implements
- `OpenFeelings/Models/ValueSort.swift` — pattern for an `@Model` with computed accessor over comma-joined raw string
- `OpenFeelings/Models/CommittedAction.swift` — pattern for an `@Model` with a bare-UUID foreign key reference
- `OpenFeelings/Views/Direction/Values/ValuesArea.swift` — pattern for a Direction-tab area with empty + populated states
- `OpenFeelings/Views/Direction/Values/Sort/SortFlowView.swift` — pattern for the NavigationStack wizard with in-memory session object
- `OpenFeelings/Views/CheckInWizard/Steps/StrengthStep.swift` — the inline five-dot intensity picker we'll replicate
- `AGENTS.md` — XcodeGen regeneration after adding/removing files, test command for iPad simulator

---

## File plan

**New:**

| Path | Responsibility |
|---|---|
| `OpenFeelings/Models/ThinkingPattern.swift` | 8-case enum + displayName/description + encode/parseList helpers |
| `OpenFeelings/Models/ThoughtRecord.swift` | `@Model` with raw/computed accessors, `isSaveable`, `intensityDelta` |
| `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDraft.swift` | Value-type wizard state; `from(log:)`, `from(record:)`, `apply(to:)`, `toThoughtRecord()` |
| `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordsArea.swift` | Direction-tab third area: empty state, list, swipe-delete |
| `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordFlowView.swift` | Wizard host with `NavigationStack` step routing |
| `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDetail.swift` | Read-only detail + edit/delete affordances |
| `OpenFeelings/Views/Direction/Thoughts/Steps/SituationStepView.swift` | Step 1: free-text "What was happening?" |
| `OpenFeelings/Views/Direction/Thoughts/Steps/AutomaticThoughtStepView.swift` | Step 2: required thought |
| `OpenFeelings/Views/Direction/Thoughts/Steps/IntensityBeforeStepView.swift` | Step 3: 5-dot intensity |
| `OpenFeelings/Views/Direction/Thoughts/Steps/PatternsStepView.swift` | Step 4: 8 chip multi-select |
| `OpenFeelings/Views/Direction/Thoughts/Steps/BalancedThoughtStepView.swift` | Step 5: required reframe |
| `OpenFeelings/Views/Direction/Thoughts/Steps/IntensityAfterStepView.swift` | Step 6: 5-dot intensity |
| `OpenFeelings/Views/Direction/Thoughts/Steps/ConfirmThoughtRecordView.swift` | Step 7: read-only summary + Save |
| `OpenFeelingsTests/ThinkingPatternTests.swift` | Taxonomy integrity + encode/parse round-trips |
| `OpenFeelingsTests/ThoughtRecordTests.swift` | `isSaveable`, `intensityDelta`, init defaults |
| `OpenFeelingsTests/ThoughtRecordDraftTests.swift` | `from(log:)` pre-fill, `from(record:)`, `apply(to:)`, `toThoughtRecord()` |
| `OpenFeelingsTests/ThoughtRecordsAreaPersistenceTests.swift` | Newest-first sort, swipe-delete, in-memory container fetch |

**Modified:**

| Path | Change |
|---|---|
| `OpenFeelings/OpenFeelingsApp.swift` | Add `ThoughtRecord.self` to the `Schema(...)` array (3 places: tests, simulator, cloud) |
| `OpenFeelings/Views/Direction/DirectionView.swift` | Append `ThoughtRecordsArea()` to the VStack and the preview's `modelContainer(for:)` array |
| `OpenFeelings/Views/HistoryView.swift` | Add "Examine this thought" item to `LogCard.shareMenu`; carry source-log into a sheet binding that presents `ThoughtRecordFlowView`. TodayView has its own `logCardContent` without a share menu and is intentionally not modified here. |
| `docs/release/cloudkit-production-deployment.md` | Add `CD_ThoughtRecord` to the schema reference table; add `CD_createdAt` to the queryable-index list |

---

## Task 1: ThinkingPattern taxonomy

**Files:**
- Create: `OpenFeelings/Models/ThinkingPattern.swift`
- Test: `OpenFeelingsTests/ThinkingPatternTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/ThinkingPatternTests.swift`:

```swift
import XCTest
@testable import OpenFeelings

final class ThinkingPatternTests: XCTestCase {
    func testHasExactlyEightCases() {
        XCTAssertEqual(ThinkingPattern.allCases.count, 8)
    }

    func testEveryCaseHasNonEmptyDisplayNameAndDescription() {
        for pattern in ThinkingPattern.allCases {
            XCTAssertFalse(pattern.displayName.isEmpty,
                           "displayName empty for \(pattern.rawValue)")
            XCTAssertFalse(pattern.description.isEmpty,
                           "description empty for \(pattern.rawValue)")
        }
    }

    func testRawValuesAreLowerCamelCaseSlugs() {
        let regex = #"^[a-z][A-Za-z0-9]*$"#
        for pattern in ThinkingPattern.allCases {
            XCTAssertNotNil(
                pattern.rawValue.range(of: regex, options: .regularExpression),
                "rawValue is not lowerCamelCase: \(pattern.rawValue)"
            )
        }
    }

    func testEncodeListAndParseListRoundTrip() {
        let list: [ThinkingPattern] = [.blackAndWhite, .mindReading, .alwaysNever]
        let raw = ThinkingPattern.encodeList(list)
        XCTAssertEqual(ThinkingPattern.parseList(raw), list)
    }

    func testParseListDropsUnknownRawValues() {
        let raw = "mindReading,notARealPattern,alwaysNever"
        XCTAssertEqual(ThinkingPattern.parseList(raw),
                       [.mindReading, .alwaysNever])
    }

    func testParseEmptyStringYieldsEmpty() {
        XCTAssertEqual(ThinkingPattern.parseList(""), [])
    }

    func testEncodeEmptyListYieldsEmptyString() {
        XCTAssertEqual(ThinkingPattern.encodeList([]), "")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=Tesela-Test' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:OpenFeelingsTests/ThinkingPatternTests test
```

Expected: FAIL with "Cannot find type 'ThinkingPattern' in scope".

- [ ] **Step 3: Implement ThinkingPattern**

Create `OpenFeelings/Models/ThinkingPattern.swift`:

```swift
import Foundation

/// The 8 curated "thinking patterns" surfaced as chips in the thought-record
/// wizard. Soft-renamed from Burns's 10 cognitive distortions to fit
/// Open Feelings' non-clinical tone (see spec for the Burns→our-name map).
/// Stored on `ThoughtRecord.patternsRaw` as a comma-joined list of raw
/// values; the computed `patterns` accessor decodes via `parseList`.
enum ThinkingPattern: String, CaseIterable, Codable, Sendable, Identifiable {
    case blackAndWhite
    case mindReading
    case worstCase
    case allMyFault
    case shouldStorm
    case filterTheGood
    case fortuneTelling
    case alwaysNever

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
        guard !raw.isEmpty else { return [] }
        return raw.split(separator: ",")
                  .compactMap { ThinkingPattern(rawValue: String($0)) }
    }

    static func encodeList(_ list: [ThinkingPattern]) -> String {
        list.map(\.rawValue).joined(separator: ",")
    }
}
```

- [ ] **Step 4: Regenerate project and run tests**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=Tesela-Test' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:OpenFeelingsTests/ThinkingPatternTests test
```

Expected: PASS — 7 tests, 0 failures.

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Models/ThinkingPattern.swift \
        OpenFeelingsTests/ThinkingPatternTests.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ThinkingPattern taxonomy for thought records"
```

---

## Task 2: ThoughtRecord @Model + schema registration

**Files:**
- Create: `OpenFeelings/Models/ThoughtRecord.swift`
- Modify: `OpenFeelings/OpenFeelingsApp.swift`
- Test: `OpenFeelingsTests/ThoughtRecordTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/ThoughtRecordTests.swift`:

```swift
import XCTest
import SwiftData
@testable import OpenFeelings

@MainActor
final class ThoughtRecordTests: XCTestCase {

    // MARK: - Defaults

    func testFreshRecordHasSensibleDefaults() {
        let record = ThoughtRecord()
        XCTAssertEqual(record.situation, "")
        XCTAssertEqual(record.automaticThought, "")
        XCTAssertNil(record.intensityBefore)
        XCTAssertEqual(record.patternsRaw, "")
        XCTAssertEqual(record.balancedThought, "")
        XCTAssertNil(record.intensityAfter)
        XCTAssertNil(record.linkedLogID)
    }

    // MARK: - isSaveable

    func testIsSaveableTrueWhenAllRequiredFieldsPresent() {
        let r = ThoughtRecord(automaticThought: "x",
                              intensityBefore: 4,
                              balancedThought: "y",
                              intensityAfter: 2)
        XCTAssertTrue(r.isSaveable)
    }

    func testIsSaveableFalseWhenAutomaticThoughtEmpty() {
        let r = ThoughtRecord(automaticThought: "",
                              intensityBefore: 4,
                              balancedThought: "y",
                              intensityAfter: 2)
        XCTAssertFalse(r.isSaveable)
    }

    func testIsSaveableFalseWhenAutomaticThoughtIsWhitespace() {
        let r = ThoughtRecord(automaticThought: "   \n  ",
                              intensityBefore: 4,
                              balancedThought: "y",
                              intensityAfter: 2)
        XCTAssertFalse(r.isSaveable)
    }

    func testIsSaveableFalseWhenBalancedThoughtEmpty() {
        let r = ThoughtRecord(automaticThought: "x",
                              intensityBefore: 4,
                              balancedThought: "",
                              intensityAfter: 2)
        XCTAssertFalse(r.isSaveable)
    }

    func testIsSaveableFalseWhenIntensityBeforeMissing() {
        let r = ThoughtRecord(automaticThought: "x",
                              intensityBefore: nil,
                              balancedThought: "y",
                              intensityAfter: 2)
        XCTAssertFalse(r.isSaveable)
    }

    func testIsSaveableFalseWhenIntensityAfterMissing() {
        let r = ThoughtRecord(automaticThought: "x",
                              intensityBefore: 4,
                              balancedThought: "y",
                              intensityAfter: nil)
        XCTAssertFalse(r.isSaveable)
    }

    // MARK: - intensityDelta

    func testIntensityDeltaNilWhenEitherIntensityMissing() {
        let onlyBefore = ThoughtRecord(intensityBefore: 4, intensityAfter: nil)
        let onlyAfter = ThoughtRecord(intensityBefore: nil, intensityAfter: 2)
        XCTAssertNil(onlyBefore.intensityDelta)
        XCTAssertNil(onlyAfter.intensityDelta)
    }

    func testIntensityDeltaIsPositiveWhenReframeReducedIntensity() {
        let r = ThoughtRecord(intensityBefore: 4, intensityAfter: 2)
        XCTAssertEqual(r.intensityDelta, 2)
    }

    func testIntensityDeltaIsZeroWhenIntensityUnchanged() {
        let r = ThoughtRecord(intensityBefore: 3, intensityAfter: 3)
        XCTAssertEqual(r.intensityDelta, 0)
    }

    func testIntensityDeltaIsNegativeWhenReframeMadeWorse() {
        let r = ThoughtRecord(intensityBefore: 2, intensityAfter: 4)
        XCTAssertEqual(r.intensityDelta, -2)
    }

    // MARK: - patterns accessor

    func testPatternsAccessorEncodesAndDecodesViaRawStorage() {
        let r = ThoughtRecord()
        r.patterns = [.blackAndWhite, .mindReading, .alwaysNever]
        XCTAssertEqual(r.patternsRaw, "blackAndWhite,mindReading,alwaysNever")
        XCTAssertEqual(r.patterns, [.blackAndWhite, .mindReading, .alwaysNever])
    }

    // MARK: - Schema registration

    func testModelContainerAcceptsThoughtRecord() throws {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self, ThoughtRecord.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let record = ThoughtRecord(automaticThought: "x",
                                   intensityBefore: 3,
                                   balancedThought: "y",
                                   intensityAfter: 1)
        context.insert(record)
        try context.save()
        let rows = try context.fetch(FetchDescriptor<ThoughtRecord>())
        XCTAssertEqual(rows.count, 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
xcodebuild ... -only-testing:OpenFeelingsTests/ThoughtRecordTests test
```

Expected: FAIL with "Cannot find type 'ThoughtRecord' in scope".

- [ ] **Step 3: Implement ThoughtRecord**

Create `OpenFeelings/Models/ThoughtRecord.swift`:

```swift
import Foundation
import SwiftData

/// One CBT thought-record entry. Mirrors the Burns "Feeling Good" five-step
/// shape with intensity split into before/after for an explicit visual of
/// whether the reframe shifted the feeling. Pure-string + Int? storage keeps
/// the schema CloudKit-clean (every field has a default or is Optional).
@Model
final class ThoughtRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var situation: String = ""
    var automaticThought: String = ""
    var intensityBefore: Int?
    /// Comma-joined `ThinkingPattern.rawValue` list. Use the `patterns`
    /// computed accessor to read/write a typed array.
    var patternsRaw: String = ""
    var balancedThought: String = ""
    var intensityAfter: Int?
    /// Optional foreign key to a `FeelingLog.id`. Bare UUID, no relationship —
    /// matches the `CommittedAction.valueRef` pattern.
    var linkedLogID: UUID?

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         situation: String = "",
         automaticThought: String = "",
         intensityBefore: Int? = nil,
         patterns: [ThinkingPattern] = [],
         balancedThought: String = "",
         intensityAfter: Int? = nil,
         linkedLogID: UUID? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.situation = situation
        self.automaticThought = automaticThought
        self.intensityBefore = intensityBefore
        self.patternsRaw = ThinkingPattern.encodeList(patterns)
        self.balancedThought = balancedThought
        self.intensityAfter = intensityAfter
        self.linkedLogID = linkedLogID
    }
}

extension ThoughtRecord {
    var patterns: [ThinkingPattern] {
        get { ThinkingPattern.parseList(patternsRaw) }
        set { patternsRaw = ThinkingPattern.encodeList(newValue) }
    }

    /// `intensityBefore - intensityAfter`. Positive means the reframe reduced
    /// the felt intensity; zero means no change; negative means it got
    /// worse. Nil when either field is missing.
    var intensityDelta: Int? {
        guard let before = intensityBefore, let after = intensityAfter else { return nil }
        return before - after
    }

    /// True iff all four required fields are populated (whitespace-trimmed
    /// non-empty thought + balanced thought, both intensities chosen).
    /// Drives Save-button enablement on the wizard's confirm step.
    var isSaveable: Bool {
        let trimmedThought = automaticThought.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBalanced = balancedThought.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedThought.isEmpty
            && !trimmedBalanced.isEmpty
            && intensityBefore != nil
            && intensityAfter != nil
    }
}
```

- [ ] **Step 4: Register ThoughtRecord in the model container schema**

Modify `OpenFeelings/OpenFeelingsApp.swift` lines 56-59. Replace:

```swift
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self
        ])
```

with:

```swift
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self,
            ThoughtRecord.self
        ])
```

- [ ] **Step 5: Regenerate project and run tests**

```sh
xcodegen generate
xcodebuild ... -only-testing:OpenFeelingsTests/ThoughtRecordTests test
```

Expected: PASS — 13 tests, 0 failures.

- [ ] **Step 6: Run full unit suite to confirm no regression**

```sh
xcodebuild ... -only-testing:OpenFeelingsTests test
```

Expected: 343 + 13 ≈ 356 tests, all passing.

- [ ] **Step 7: Commit**

```sh
git add OpenFeelings/Models/ThoughtRecord.swift \
        OpenFeelings/OpenFeelingsApp.swift \
        OpenFeelingsTests/ThoughtRecordTests.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ThoughtRecord @Model and register in schema"
```

---

## Task 3: ThoughtRecordDraft value type

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDraft.swift`
- Test: `OpenFeelingsTests/ThoughtRecordDraftTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/ThoughtRecordDraftTests.swift`:

```swift
import XCTest
@testable import OpenFeelings

@MainActor
final class ThoughtRecordDraftTests: XCTestCase {

    private func sampleLog(intensity: Int? = 4) -> FeelingLog {
        let core = EmotionTaxonomy.cores.first { $0.id == "angry" }!
        let secondary = core.secondaries.first { $0.name == "Bitter" }
        let selection = EmotionSelection(core: core, secondary: secondary, specific: nil)
        let log = FeelingLog(selection: selection, intensity: intensity, note: "")
        log.createdAt = Date(timeIntervalSince1970: 1_715_000_000)
        return log
    }

    // MARK: - Initial state

    func testInitialDraftIsAllEmptyOrNil() {
        let draft = ThoughtRecordDraft()
        XCTAssertEqual(draft.situation, "")
        XCTAssertEqual(draft.automaticThought, "")
        XCTAssertNil(draft.intensityBefore)
        XCTAssertTrue(draft.patterns.isEmpty)
        XCTAssertEqual(draft.balancedThought, "")
        XCTAssertNil(draft.intensityAfter)
        XCTAssertNil(draft.linkedLogID)
    }

    // MARK: - from(log:)

    func testDraftFromLogCarriesLinkedID() {
        let log = sampleLog()
        let draft = ThoughtRecordDraft.from(log: log)
        XCTAssertEqual(draft.linkedLogID, log.id)
    }

    func testDraftFromLogPrefillsSituationWithPathAndTime() {
        let log = sampleLog()
        let draft = ThoughtRecordDraft.from(log: log)
        // Path is "Angry > Bitter"; we replace `> ` with `· ` for display.
        XCTAssertTrue(draft.situation.contains("Angry"),
                      "Situation should include the emotion path: \(draft.situation)")
        XCTAssertTrue(draft.situation.contains("·"),
                      "Situation should use middle-dot separator: \(draft.situation)")
    }

    func testDraftFromLogPrefillsIntensityWhenLogHasOne() {
        let log = sampleLog(intensity: 4)
        let draft = ThoughtRecordDraft.from(log: log)
        XCTAssertEqual(draft.intensityBefore, 4)
    }

    func testDraftFromLogLeavesIntensityNilWhenLogHasNone() {
        let log = sampleLog(intensity: nil)
        let draft = ThoughtRecordDraft.from(log: log)
        XCTAssertNil(draft.intensityBefore)
    }

    // MARK: - from(record:)

    func testDraftFromRecordCopiesAllFields() {
        let record = ThoughtRecord(
            situation: "morning",
            automaticThought: "I'll fail",
            intensityBefore: 5,
            patterns: [.fortuneTelling, .worstCase],
            balancedThought: "I've handled this before",
            intensityAfter: 2,
            linkedLogID: UUID()
        )
        let draft = ThoughtRecordDraft.from(record: record)
        XCTAssertEqual(draft.id, record.id)
        XCTAssertEqual(draft.situation, "morning")
        XCTAssertEqual(draft.automaticThought, "I'll fail")
        XCTAssertEqual(draft.intensityBefore, 5)
        XCTAssertEqual(draft.patterns, [.fortuneTelling, .worstCase])
        XCTAssertEqual(draft.balancedThought, "I've handled this before")
        XCTAssertEqual(draft.intensityAfter, 2)
        XCTAssertEqual(draft.linkedLogID, record.linkedLogID)
    }

    // MARK: - apply(to:)

    func testApplyOverwritesAllRecordFields() {
        let record = ThoughtRecord()
        var draft = ThoughtRecordDraft()
        draft.situation = "evening"
        draft.automaticThought = "they're upset with me"
        draft.intensityBefore = 4
        draft.patterns = [.mindReading]
        draft.balancedThought = "I haven't asked them"
        draft.intensityAfter = 2
        let logID = UUID()
        draft.linkedLogID = logID

        draft.apply(to: record)
        XCTAssertEqual(record.situation, "evening")
        XCTAssertEqual(record.automaticThought, "they're upset with me")
        XCTAssertEqual(record.intensityBefore, 4)
        XCTAssertEqual(record.patterns, [.mindReading])
        XCTAssertEqual(record.balancedThought, "I haven't asked them")
        XCTAssertEqual(record.intensityAfter, 2)
        XCTAssertEqual(record.linkedLogID, logID)
    }

    // MARK: - toThoughtRecord

    func testToThoughtRecordPreservesIDAndAllFields() {
        var draft = ThoughtRecordDraft()
        draft.id = UUID()
        draft.automaticThought = "x"
        draft.intensityBefore = 3
        draft.patterns = [.blackAndWhite]
        draft.balancedThought = "y"
        draft.intensityAfter = 1
        let record = draft.toThoughtRecord()
        XCTAssertEqual(record.id, draft.id)
        XCTAssertEqual(record.automaticThought, "x")
        XCTAssertEqual(record.intensityBefore, 3)
        XCTAssertEqual(record.patterns, [.blackAndWhite])
        XCTAssertEqual(record.balancedThought, "y")
        XCTAssertEqual(record.intensityAfter, 1)
    }

    // MARK: - isSaveable (mirrors ThoughtRecord)

    func testDraftIsSaveableMirrorsRecordLogic() {
        var draft = ThoughtRecordDraft()
        XCTAssertFalse(draft.isSaveable)
        draft.automaticThought = "x"
        draft.balancedThought = "y"
        draft.intensityBefore = 3
        XCTAssertFalse(draft.isSaveable, "Missing intensityAfter")
        draft.intensityAfter = 2
        XCTAssertTrue(draft.isSaveable)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```sh
xcodebuild ... -only-testing:OpenFeelingsTests/ThoughtRecordDraftTests test
```

Expected: FAIL with "Cannot find type 'ThoughtRecordDraft' in scope".

- [ ] **Step 3: Implement ThoughtRecordDraft**

Create `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDraft.swift`:

```swift
import Foundation

/// In-memory wizard state for a thought record. Value-type so mutations
/// don't persist until the confirm step calls `toThoughtRecord()` (for the
/// new flow) or `apply(to:)` (for the edit flow). Mirrors the pattern of
/// `CheckInDraft` for the iOS wizard and `SortSession` for the value sort.
/// Equatable so the wizard can detect dirty state for the cancel-confirm
/// alert in `ThoughtRecordFlowView`.
struct ThoughtRecordDraft: Equatable {
    var id: UUID = UUID()
    var situation: String = ""
    var automaticThought: String = ""
    var intensityBefore: Int?
    var patterns: [ThinkingPattern] = []
    var balancedThought: String = ""
    var intensityAfter: Int?
    var linkedLogID: UUID?

    /// True iff the confirm step's Save button should be enabled. Same rule
    /// as `ThoughtRecord.isSaveable`.
    var isSaveable: Bool {
        let trimmedThought = automaticThought.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBalanced = balancedThought.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedThought.isEmpty
            && !trimmedBalanced.isEmpty
            && intensityBefore != nil
            && intensityAfter != nil
    }

    /// Pre-fill from a check-in. Used by the "Examine this thought" share-
    /// menu entry on `LogCard`. `situation` becomes `"<pathTitle> · <time>"`,
    /// `intensityBefore` mirrors the log's intensity if set.
    static func from(log: FeelingLog) -> ThoughtRecordDraft {
        var draft = ThoughtRecordDraft()
        draft.linkedLogID = log.id
        let time = log.createdAt.formatted(date: .omitted, time: .shortened)
        let path = log.pathTitle.replacingOccurrences(of: " > ", with: " · ")
        draft.situation = path.isEmpty ? time : "\(path) · \(time)"
        draft.intensityBefore = log.intensity
        return draft
    }

    /// Pre-fill from an existing record (edit flow). Carries the record's
    /// `id` so the confirm step's `apply(to:)` updates that row.
    static func from(record: ThoughtRecord) -> ThoughtRecordDraft {
        var draft = ThoughtRecordDraft()
        draft.id = record.id
        draft.situation = record.situation
        draft.automaticThought = record.automaticThought
        draft.intensityBefore = record.intensityBefore
        draft.patterns = record.patterns
        draft.balancedThought = record.balancedThought
        draft.intensityAfter = record.intensityAfter
        draft.linkedLogID = record.linkedLogID
        return draft
    }

    /// Overwrite the given record's mutable fields. Used by the edit-flow
    /// Save action.
    func apply(to record: ThoughtRecord) {
        record.situation = situation
        record.automaticThought = automaticThought
        record.intensityBefore = intensityBefore
        record.patterns = patterns
        record.balancedThought = balancedThought
        record.intensityAfter = intensityAfter
        record.linkedLogID = linkedLogID
    }

    /// Build a new `ThoughtRecord` from this draft. Used by the new-flow
    /// Save action. The draft's `id` is preserved so a subsequent edit-flow
    /// re-uses the same row.
    func toThoughtRecord() -> ThoughtRecord {
        ThoughtRecord(
            id: id,
            situation: situation,
            automaticThought: automaticThought,
            intensityBefore: intensityBefore,
            patterns: patterns,
            balancedThought: balancedThought,
            intensityAfter: intensityAfter,
            linkedLogID: linkedLogID
        )
    }
}
```

- [ ] **Step 4: Regenerate project and run tests**

```sh
xcodegen generate
xcodebuild ... -only-testing:OpenFeelingsTests/ThoughtRecordDraftTests test
```

Expected: PASS — 9 tests, 0 failures.

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDraft.swift \
        OpenFeelingsTests/ThoughtRecordDraftTests.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ThoughtRecordDraft for in-memory wizard state"
```

---

## Task 4: Text-input step views (Situation, AutomaticThought, BalancedThought)

These three step views share a structure: a prompt line, a TextField (multi-line, axis: .vertical), and a "Continue" button gated on emptiness for the required ones. Implement them together — they're small and similar.

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/Steps/SituationStepView.swift`
- Create: `OpenFeelings/Views/Direction/Thoughts/Steps/AutomaticThoughtStepView.swift`
- Create: `OpenFeelings/Views/Direction/Thoughts/Steps/BalancedThoughtStepView.swift`

- [ ] **Step 1: Implement SituationStepView**

Create `OpenFeelings/Views/Direction/Thoughts/Steps/SituationStepView.swift`:

```swift
import SwiftUI

/// Step 1 of the thought-record wizard. Optional free-text context for the
/// thought ("What was happening?"). Empty is OK — Continue is always enabled.
struct SituationStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("What was happening?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Optional. A few words is enough.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            TextField("e.g., morning standup",
                      text: $draft.situation,
                      axis: .vertical)
                .lineLimit(2...6)
                .font(.OF.body)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Thought record")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 2: Implement AutomaticThoughtStepView**

Create `OpenFeelings/Views/Direction/Thoughts/Steps/AutomaticThoughtStepView.swift`:

```swift
import SwiftUI

/// Step 2. Required: the thought the user noticed. Continue disabled until
/// the field has non-whitespace text.
struct AutomaticThoughtStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    private var canAdvance: Bool {
        !draft.automaticThought
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("What thought went through your head?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Quote yourself if you can. Verbatim is fine.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            TextField("e.g., I'm going to embarrass myself",
                      text: $draft.automaticThought,
                      axis: .vertical)
                .lineLimit(3...8)
                .font(.OF.body)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.4)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("The thought")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 3: Implement BalancedThoughtStepView**

Create `OpenFeelings/Views/Direction/Thoughts/Steps/BalancedThoughtStepView.swift`:

```swift
import SwiftUI

/// Step 5. Required: a balanced/alternative way of looking at the situation.
/// Continue disabled until non-empty.
struct BalancedThoughtStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    private var canAdvance: Bool {
        !draft.balancedThought
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("Is there a different way of looking at it?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Not a forced positive — just a fairer reading.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            TextField("e.g., I've handled tougher meetings before",
                      text: $draft.balancedThought,
                      axis: .vertical)
                .lineLimit(3...8)
                .font(.OF.body)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.4)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("A balanced view")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 4: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Views/Direction/Thoughts/Steps/SituationStepView.swift \
        OpenFeelings/Views/Direction/Thoughts/Steps/AutomaticThoughtStepView.swift \
        OpenFeelings/Views/Direction/Thoughts/Steps/BalancedThoughtStepView.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add text-input step views for thought record wizard"
```

---

## Task 5: Intensity step views (before + after)

Both use a 5-dot picker inline (same pattern as `StrengthStep.swift`). Continue disabled until a value is selected.

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/Steps/IntensityBeforeStepView.swift`
- Create: `OpenFeelings/Views/Direction/Thoughts/Steps/IntensityAfterStepView.swift`

- [ ] **Step 1: Implement IntensityBeforeStepView**

Create `OpenFeelings/Views/Direction/Thoughts/Steps/IntensityBeforeStepView.swift`:

```swift
import SwiftUI

/// Step 3. How strong did the feeling feel before reframing. Five-dot
/// picker matching `StrengthStep`'s visual; Continue gated on a non-nil
/// selection.
struct IntensityBeforeStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("How strong was the feeling?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("1 is barely noticing it, 5 is at full force.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            intensityDotsPicker(selection: $draft.intensityBefore)

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.intensityBefore == nil)
            .opacity(draft.intensityBefore == nil ? 0.4 : 1)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Before")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Five tappable dots. Tap a dot to select; tap the same dot again to clear.
/// Mirrors the toggling behavior of `StrengthStep`. Named `intensityDotsPicker`
/// (not `intensityDots`) to avoid visual confusion with the private
/// `intensityDots(intensity:)` helpers already in `TodayView` and
/// `HistoryView` which render a non-interactive row.
@ViewBuilder
func intensityDotsPicker(selection: Binding<Int?>) -> some View {
    VStack(spacing: CGFloat.OF.sm) {
        HStack(spacing: CGFloat.OF.sm) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    if selection.wrappedValue == value {
                        selection.wrappedValue = nil
                    } else {
                        selection.wrappedValue = value
                    }
                } label: {
                    Circle()
                        .fill(isFilled(value: value, selection: selection.wrappedValue)
                              ? AnyShapeStyle(Color.OF.accent)
                              : AnyShapeStyle(Color.OF.divider))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Intensity \(value)")
                .accessibilityAddTraits(
                    selection.wrappedValue == value ? .isSelected : []
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        HStack {
            Text("Just noticing")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            Spacer()
            Text("At full force")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
        }
    }
    .padding(CGFloat.OF.lg)
    .background(Color.OF.surface,
                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
}

private func isFilled(value: Int, selection: Int?) -> Bool {
    guard let selection else { return false }
    return value <= selection
}
```

- [ ] **Step 2: Implement IntensityAfterStepView**

Create `OpenFeelings/Views/Direction/Thoughts/Steps/IntensityAfterStepView.swift`:

```swift
import SwiftUI

/// Step 6. How strong the feeling feels *after* the reframe. Reuses the
/// `intensityDots` helper defined in IntensityBeforeStepView.swift.
struct IntensityAfterStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("How strong does it feel now?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Same scale. It's OK if it didn't move.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            intensityDotsPicker(selection: $draft.intensityAfter)

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(draft.intensityAfter == nil)
            .opacity(draft.intensityAfter == nil ? 0.4 : 1)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("After")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 3: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 4: Commit**

```sh
git add OpenFeelings/Views/Direction/Thoughts/Steps/IntensityBeforeStepView.swift \
        OpenFeelings/Views/Direction/Thoughts/Steps/IntensityAfterStepView.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add intensity step views for thought record wizard"
```

---

## Task 6: PatternsStepView

Multi-select chip picker for the 8 `ThinkingPattern` cases. Tap toggles; long-press shows description in a popover. Continue always enabled (patterns are optional).

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/Steps/PatternsStepView.swift`

- [ ] **Step 1: Implement PatternsStepView**

Create `OpenFeelings/Views/Direction/Thoughts/Steps/PatternsStepView.swift`:

```swift
import SwiftUI

/// Step 4. Multi-select chips for the 8 thinking patterns. Tap toggles
/// selection; long-press surfaces the pattern's description in an
/// `.popover`. Selection is optional — Continue always enabled.
struct PatternsStepView: View {
    @Binding var draft: ThoughtRecordDraft
    let onContinue: () -> Void

    @State private var describing: ThinkingPattern?

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
            VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                Text("Notice any thinking patterns?")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)
                Text("Pick zero or more. Long-press a chip for a description.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: CGFloat.OF.md)],
                      spacing: CGFloat.OF.md) {
                ForEach(ThinkingPattern.allCases) { pattern in
                    chip(for: pattern)
                }
            }

            Spacer()

            Button(action: onContinue) {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(CGFloat.OF.md)
        .navigationTitle("Patterns")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func chip(for pattern: ThinkingPattern) -> some View {
        let selected = draft.patterns.contains(pattern)
        Button {
            toggle(pattern)
        } label: {
            HStack(spacing: CGFloat.OF.xs) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected
                        ? AnyShapeStyle(Color.OF.accent)
                        : AnyShapeStyle(Color.OF.textMuted))
                Text(pattern.displayName)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, CGFloat.OF.md)
            .background(
                selected
                    ? AnyShapeStyle(Color.OF.accent.opacity(0.12))
                    : AnyShapeStyle(Color.OF.surface),
                in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
            )
            .overlay {
                RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                    .stroke(selected
                        ? Color.OF.accent.opacity(0.45)
                        : Color.OF.divider, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pattern.\(pattern.rawValue)")
        .onLongPressGesture {
            describing = pattern
        }
        .popover(item: $describing) { pattern in
            VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
                Text(pattern.displayName)
                    .font(.OF.headline)
                Text(pattern.description)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
            }
            .padding(CGFloat.OF.md)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func toggle(_ pattern: ThinkingPattern) {
        if let idx = draft.patterns.firstIndex(of: pattern) {
            draft.patterns.remove(at: idx)
        } else {
            draft.patterns.append(pattern)
        }
    }
}
```

- [ ] **Step 2: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Views/Direction/Thoughts/Steps/PatternsStepView.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add PatternsStepView for thinking-pattern chip multi-select"
```

---

## Task 7: ConfirmThoughtRecordView

Read-only summary of all six fields. Save button bottom-right, disabled until `draft.isSaveable`. Tapping a section pencil sends the user back to that step (handled by the parent flow view).

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/Steps/ConfirmThoughtRecordView.swift`

- [ ] **Step 1: Implement ConfirmThoughtRecordView**

Create `OpenFeelings/Views/Direction/Thoughts/Steps/ConfirmThoughtRecordView.swift`:

```swift
import SwiftUI

/// Step 7 — the confirm screen. Read-only summary of the entire draft with
/// a Save button at the bottom. Save is disabled until `draft.isSaveable`.
/// Per-section pencil buttons jump back to the corresponding step via
/// `onEdit`.
struct ConfirmThoughtRecordView: View {
    let draft: ThoughtRecordDraft
    let onSave: () -> Void
    let onEdit: (FlowStep) -> Void

    enum FlowStep {
        case situation, automaticThought, intensityBefore, patterns,
             balancedThought, intensityAfter
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
                section(title: "Situation",
                        body: draft.situation.isEmpty ? "—" : draft.situation,
                        onEdit: { onEdit(.situation) })

                section(title: "Thought",
                        body: draft.automaticThought,
                        onEdit: { onEdit(.automaticThought) })

                section(title: "Intensity before",
                        body: intensityLabel(draft.intensityBefore),
                        onEdit: { onEdit(.intensityBefore) })

                section(title: "Patterns",
                        body: patternsLabel,
                        onEdit: { onEdit(.patterns) })

                section(title: "Balanced view",
                        body: draft.balancedThought,
                        onEdit: { onEdit(.balancedThought) })

                section(title: "Intensity after",
                        body: intensityLabel(draft.intensityAfter),
                        onEdit: { onEdit(.intensityAfter) })

                Button(action: onSave) {
                    Text("Save").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isSaveable)
                .opacity(draft.isSaveable ? 1 : 0.4)
                .padding(.top, CGFloat.OF.md)
            }
            .padding(CGFloat.OF.md)
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var patternsLabel: String {
        draft.patterns.isEmpty
            ? "—"
            : draft.patterns.map(\.displayName).joined(separator: ", ")
    }

    private func intensityLabel(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value) / 5"
    }

    @ViewBuilder
    private func section(title: String, body: String, onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            HStack {
                Text(title)
                    .font(.OF.caption.weight(.semibold))
                    .foregroundStyle(Color.OF.textMuted)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.OF.accent)
                }
                .buttonStyle(.plain)
            }
            Text(body)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
    }
}
```

- [ ] **Step 2: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Views/Direction/Thoughts/Steps/ConfirmThoughtRecordView.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ConfirmThoughtRecordView for wizard summary + Save"
```

---

## Task 8: ThoughtRecordFlowView orchestrator

The wizard host. Mirrors `SortFlowView`'s `NavigationStack` step-path pattern. Owns the `@State` `ThoughtRecordDraft`. Save inserts a new `ThoughtRecord` (new flow) or applies to an existing one (edit flow, recognized by a pre-set `existingRecord` parameter).

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordFlowView.swift`

- [ ] **Step 1: Implement ThoughtRecordFlowView**

Create `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordFlowView.swift`:

```swift
import SwiftData
import SwiftUI

/// Hosts the 7-screen thought-record wizard. Driven by an in-memory
/// `ThoughtRecordDraft`. Save behavior depends on whether `existingRecord`
/// is set (edit) or nil (new). Caller is responsible for dismissing the
/// sheet — this view just calls `onComplete` after Save or Cancel.
struct ThoughtRecordFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Initial state. For the "new" flow with no pre-fills, pass
    /// `ThoughtRecordDraft()`. For "examine this thought" from a check-in,
    /// pass `ThoughtRecordDraft.from(log:)`. For the edit flow, pass
    /// `ThoughtRecordDraft.from(record:)` AND set `existingRecord` to that
    /// record.
    @State var draft: ThoughtRecordDraft
    var existingRecord: ThoughtRecord?

    @State private var path: [Step] = []
    @State private var showingCancelAlert = false
    /// Snapshot of the draft at sheet-open time. Compared in `isDirty` to
    /// decide whether Cancel should confirm. Captured in `.task` rather than
    /// `init` so the draft pre-fills (e.g. from `from(log:)`) are included.
    @State private var initialDraft: ThoughtRecordDraft?

    enum Step: Hashable {
        case automaticThought
        case intensityBefore
        case patterns
        case balancedThought
        case intensityAfter
        case confirm
    }

    private var isDirty: Bool {
        guard let initial = initialDraft else { return false }
        return draft != initial
    }

    var body: some View {
        NavigationStack(path: $path) {
            SituationStepView(draft: $draft) {
                path.append(.automaticThought)
            }
            .toolbar { cancelToolbar }
            .navigationDestination(for: Step.self) { step in
                destination(for: step)
                    .toolbar { cancelToolbar }
            }
        }
        .task {
            if initialDraft == nil {
                initialDraft = draft
            }
        }
        .alert("Discard changes?", isPresented: $showingCancelAlert) {
            Button("Discard", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your thought record won't be saved.")
        }
    }

    @ToolbarContentBuilder
    private var cancelToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
                if isDirty {
                    showingCancelAlert = true
                } else {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for step: Step) -> some View {
        switch step {
        case .automaticThought:
            AutomaticThoughtStepView(draft: $draft) {
                path.append(.intensityBefore)
            }
        case .intensityBefore:
            IntensityBeforeStepView(draft: $draft) {
                path.append(.patterns)
            }
        case .patterns:
            PatternsStepView(draft: $draft) {
                path.append(.balancedThought)
            }
        case .balancedThought:
            BalancedThoughtStepView(draft: $draft) {
                path.append(.intensityAfter)
            }
        case .intensityAfter:
            IntensityAfterStepView(draft: $draft) {
                path.append(.confirm)
            }
        case .confirm:
            ConfirmThoughtRecordView(
                draft: draft,
                onSave: save,
                onEdit: { flowStep in
                    path = pathTo(flowStep)
                }
            )
        }
    }

    /// Compute the NavigationStack path that ends at the given confirm-step
    /// edit target. The user is then on that step with all prior values still
    /// in `draft`; tapping Continue rebuilds the path forward to confirm.
    private func pathTo(_ flowStep: ConfirmThoughtRecordView.FlowStep) -> [Step] {
        switch flowStep {
        case .situation:        return []
        case .automaticThought: return [.automaticThought]
        case .intensityBefore:  return [.automaticThought, .intensityBefore]
        case .patterns:         return [.automaticThought, .intensityBefore, .patterns]
        case .balancedThought:  return [.automaticThought, .intensityBefore, .patterns, .balancedThought]
        case .intensityAfter:   return [.automaticThought, .intensityBefore, .patterns, .balancedThought, .intensityAfter]
        }
    }

    private func save() {
        guard draft.isSaveable else { return }
        if let existing = existingRecord {
            draft.apply(to: existing)
        } else {
            let record = draft.toThoughtRecord()
            context.insert(record)
        }
        try? context.save()
        dismiss()
    }
}
```

- [ ] **Step 2: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Views/Direction/Thoughts/ThoughtRecordFlowView.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ThoughtRecordFlowView wizard orchestrator"
```

---

## Task 9: ThoughtRecordDetail

Read-only view of a saved record with edit (re-enters wizard) and delete (swipe via parent list) affordances.

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDetail.swift`

- [ ] **Step 1: Implement ThoughtRecordDetail**

Create `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDetail.swift`:

```swift
import SwiftData
import SwiftUI

/// Read-only detail view for a saved `ThoughtRecord`. Toolbar pencil opens
/// the wizard pre-filled (edit flow). Linked-log footer appears only when
/// `linkedLogID` resolves to an existing `FeelingLog`.
struct ThoughtRecordDetail: View {
    let record: ThoughtRecord

    @Environment(\.modelContext) private var context
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]
    @State private var showingEdit = false

    private var linkedLog: FeelingLog? {
        guard let id = record.linkedLogID else { return nil }
        return logs.first { $0.id == id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat.OF.lg) {
                Text("\u{201C}\(record.automaticThought)\u{201D}")
                    .font(.OF.headline)
                    .foregroundStyle(Color.OF.text)

                if !record.situation.isEmpty {
                    labeled(title: "Situation", body: record.situation)
                }

                if !record.patterns.isEmpty {
                    VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
                        Text("Patterns")
                            .font(.OF.caption.weight(.semibold))
                            .foregroundStyle(Color.OF.textMuted)
                        FlowingChips(patterns: record.patterns)
                    }
                }

                labeled(title: "Balanced view", body: record.balancedThought)

                intensityShift

                if let linkedLog {
                    linkedLogFooter(linkedLog)
                }

                Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
            .padding(CGFloat.OF.md)
        }
        .navigationTitle("Thought record")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            ThoughtRecordFlowView(
                draft: ThoughtRecordDraft.from(record: record),
                existingRecord: record
            )
        }
    }

    @ViewBuilder
    private func labeled(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            Text(title)
                .font(.OF.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Text(body)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
        }
    }

    @ViewBuilder
    private var intensityShift: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            Text("Intensity shift")
                .font(.OF.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            HStack(spacing: CGFloat.OF.md) {
                intensityRow(label: "Before", value: record.intensityBefore)
                Image(systemName: "arrow.right")
                    .foregroundStyle(Color.OF.textMuted)
                intensityRow(label: "After", value: record.intensityAfter)
            }
        }
    }

    @ViewBuilder
    private func intensityRow(label: String, value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { v in
                    Circle()
                        .fill(filled(v, value: value)
                              ? AnyShapeStyle(Color.OF.accent)
                              : AnyShapeStyle(Color.OF.divider))
                        .frame(width: 12, height: 12)
                }
            }
        }
    }

    private func filled(_ value: Int, value selection: Int?) -> Bool {
        guard let selection else { return false }
        return value <= selection
    }

    @ViewBuilder
    private func linkedLogFooter(_ log: FeelingLog) -> some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.xs) {
            Text("From check-in")
                .font(.OF.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Text(log.pathTitle.replacingOccurrences(of: " > ", with: " · "))
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
        }
    }
}

/// Simple inline chip row for the read-only detail view. Pattern names wrap
/// across multiple rows via LazyVGrid with adaptive sizing.
private struct FlowingChips: View {
    let patterns: [ThinkingPattern]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: CGFloat.OF.xs)],
                  spacing: CGFloat.OF.xs) {
            ForEach(patterns) { pattern in
                Text(pattern.displayName)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.text)
                    .padding(.horizontal, CGFloat.OF.sm)
                    .padding(.vertical, CGFloat.OF.xs)
                    .background(
                        Color.OF.accent.opacity(0.12),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(Color.OF.accent.opacity(0.45), lineWidth: 1)
                    }
            }
        }
    }
}
```

- [ ] **Step 2: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Views/Direction/Thoughts/ThoughtRecordDetail.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ThoughtRecordDetail read-only view with edit affordance"
```

---

## Task 10: ThoughtRecordsArea (Direction tab card)

Empty state with "Start a record" CTA; populated state with `+` button and list of recent records (newest first), each row swipe-deletable.

**Files:**
- Create: `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordsArea.swift`
- Test: `OpenFeelingsTests/ThoughtRecordsAreaPersistenceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/ThoughtRecordsAreaPersistenceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import OpenFeelings

@MainActor
final class ThoughtRecordsAreaPersistenceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self, ThoughtRecord.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testInsertedRecordPersistsAndIsFetchedNewestFirst() throws {
        let context = try makeContext()
        let older = ThoughtRecord(
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            automaticThought: "old",
            intensityBefore: 5,
            balancedThought: "x",
            intensityAfter: 3
        )
        let newer = ThoughtRecord(
            createdAt: Date(timeIntervalSince1970: 1_700_001_000),
            automaticThought: "new",
            intensityBefore: 5,
            balancedThought: "y",
            intensityAfter: 2
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let descriptor = FetchDescriptor<ThoughtRecord>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let rows = try context.fetch(descriptor)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].automaticThought, "new")
        XCTAssertEqual(rows[1].automaticThought, "old")
    }

    func testDeletingARecordRemovesItFromTheStore() throws {
        let context = try makeContext()
        let record = ThoughtRecord(
            automaticThought: "x",
            intensityBefore: 3,
            balancedThought: "y",
            intensityAfter: 1
        )
        context.insert(record)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ThoughtRecord>()).count, 1)

        context.delete(record)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<ThoughtRecord>()).count, 0)
    }

    func testPatternsRawSurvivesPersistence() throws {
        let context = try makeContext()
        let record = ThoughtRecord(
            automaticThought: "x",
            intensityBefore: 4,
            patterns: [.mindReading, .worstCase, .alwaysNever],
            balancedThought: "y",
            intensityAfter: 2
        )
        context.insert(record)
        try context.save()

        let rows = try context.fetch(FetchDescriptor<ThoughtRecord>())
        XCTAssertEqual(rows.first?.patterns,
                       [.mindReading, .worstCase, .alwaysNever])
    }

    func testLinkedLogIDIsPersisted() throws {
        let context = try makeContext()
        let logID = UUID()
        let record = ThoughtRecord(
            automaticThought: "x",
            intensityBefore: 3,
            balancedThought: "y",
            intensityAfter: 1,
            linkedLogID: logID
        )
        context.insert(record)
        try context.save()

        let rows = try context.fetch(FetchDescriptor<ThoughtRecord>())
        XCTAssertEqual(rows.first?.linkedLogID, logID)
    }
}
```

- [ ] **Step 2: Run tests to verify they pass already**

```sh
xcodebuild ... -only-testing:OpenFeelingsTests/ThoughtRecordsAreaPersistenceTests test
```

Expected: PASS — 4 tests, 0 failures. (These don't require the view yet — they exercise the model + container.)

- [ ] **Step 3: Implement ThoughtRecordsArea**

Create `OpenFeelings/Views/Direction/Thoughts/ThoughtRecordsArea.swift`:

```swift
import SwiftData
import SwiftUI

/// Direction-tab third area, below `ValuesArea`. Renders an empty hero
/// when no records exist, or a list of recent records (newest first) with
/// swipe-to-delete. Tapping a row pushes `ThoughtRecordDetail`. The `+`
/// button in the populated state opens the wizard for a brand-new record.
struct ThoughtRecordsArea: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ThoughtRecord.createdAt, order: .reverse)
    private var records: [ThoughtRecord]

    @State private var showingWizard = false
    @State private var pendingDelete: ThoughtRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
            Text("Thought records")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.OF.text)

            if records.isEmpty {
                emptyHero
            } else {
                populated
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingWizard) {
            ThoughtRecordFlowView(draft: ThoughtRecordDraft())
        }
        .alert(item: $pendingDelete) { record in
            Alert(
                title: Text("Delete this record?"),
                message: Text("This can't be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    delete(record)
                },
                secondaryButton: .cancel()
            )
        }
    }

    @ViewBuilder
    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: CGFloat.OF.sm) {
            Text("Examine a thought that's been stuck.")
                .font(.headline)
                .foregroundStyle(Color.OF.text)
            Text("Walk through it in six short steps. Notice if it shifts.")
                .foregroundStyle(Color.OF.textMuted)
            Button {
                showingWizard = true
            } label: {
                Text("Start a record")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, CGFloat.OF.xs)
        }
        .padding(CGFloat.OF.md)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
    }

    @ViewBuilder
    private var populated: some View {
        HStack {
            Text("RECENT")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.OF.textMuted)
            Spacer()
            Button { showingWizard = true } label: {
                Image(systemName: "plus")
            }
        }

        ForEach(records) { record in
            NavigationLink {
                ThoughtRecordDetail(record: record)
            } label: {
                row(for: record)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    pendingDelete = record
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func row(for record: ThoughtRecord) -> some View {
        HStack(alignment: .top, spacing: CGFloat.OF.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.createdAt.formatted(.dateTime.weekday(.abbreviated)
                    .month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(Color.OF.textMuted)
                Text(record.automaticThought)
                    .font(.body)
                    .foregroundStyle(Color.OF.text)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let delta = record.intensityDelta {
                Text(deltaLabel(delta))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(deltaColor(delta))
            }
        }
        .padding(.vertical, CGFloat.OF.xs)
        .padding(.horizontal, CGFloat.OF.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                .fill(Color.OF.surface)
        )
    }

    private func deltaLabel(_ delta: Int) -> String {
        if delta > 0 { return "−\(delta)" }
        if delta < 0 { return "+\(-delta)" }
        return "0"
    }

    private func deltaColor(_ delta: Int) -> Color {
        if delta > 0 { return Color.OF.accent }
        if delta < 0 { return Color.OF.textMuted }
        return Color.OF.textMuted
    }

    private func delete(_ record: ThoughtRecord) {
        context.delete(record)
        try? context.save()
    }
}

/// Required for `.alert(item:)`.
extension ThoughtRecord: @retroactive Identifiable {}
```

Note on the `@retroactive Identifiable` extension at the bottom: `ThoughtRecord` already has an `id: UUID` property, so it conforms to `Identifiable` automatically — but only after Swift 5.10. If this errors out on your Swift version, remove the `extension` line; the auto-conformance works as of Swift 6.0.

- [ ] **Step 4: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **. If the Identifiable extension errors, delete that line.

- [ ] **Step 5: Re-run full unit suite to confirm**

```sh
xcodebuild ... -only-testing:OpenFeelingsTests test
```

Expected: All tests still passing.

- [ ] **Step 6: Commit**

```sh
git add OpenFeelings/Views/Direction/Thoughts/ThoughtRecordsArea.swift \
        OpenFeelingsTests/ThoughtRecordsAreaPersistenceTests.swift \
        OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ThoughtRecordsArea for Direction tab + persistence tests"
```

---

## Task 11: Wire ThoughtRecordsArea into DirectionView

**Files:**
- Modify: `OpenFeelings/Views/Direction/DirectionView.swift`

- [ ] **Step 1: Modify DirectionView**

Open `OpenFeelings/Views/Direction/DirectionView.swift`. Replace:

```swift
                IntentionsContent()
                ValuesArea()
```

with:

```swift
                IntentionsContent()
                ValuesArea()
                ThoughtRecordsArea()
```

And in the `#Preview` block, update the `modelContainer(for:)` array to include `ThoughtRecord.self`:

```swift
        .modelContainer(for: [
            FeelingLog.self,
            Intention.self,
            CustomValue.self, ValueSort.self, CommittedAction.self,
            ThoughtRecord.self
        ], inMemory: true)
```

- [ ] **Step 2: Build**

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 3: Run Direction UI tests to confirm no regression**

```sh
xcodebuild ... -only-testing:OpenFeelingsUITests/DirectionUITests test
```

Expected: all 5 Direction UI tests still pass. (The new area pushes the existing content down; the tests scroll to find the sort affordance, so they should still work.)

- [ ] **Step 4: Commit**

```sh
git add OpenFeelings/Views/Direction/DirectionView.swift
git commit -m "Wire ThoughtRecordsArea into Direction tab"
```

---

## Task 12: LogCard share menu — "Examine this thought" entry

The check-in entry point. `LogCard` is defined in `HistoryView.swift:276` and is used only by `HistoryView`. `TodayView` renders its own `logCardContent` helper without a share menu — adding a share affordance there is **out of scope for this plan**; only HistoryView's `LogCard` gets the new menu item.

Users who want to challenge a thought from a Today entry can tap the row to navigate to History and use it there. If we later want a Today entry point, that's a separate change.

**Files:**
- Modify: `OpenFeelings/Views/HistoryView.swift`

- [ ] **Step 1: Locate the share menu in LogCard**

Find the `private var shareMenu: some View` in `HistoryView.swift` (around line 365+). It uses a `Menu` with items like "Apple Journal", "Day One", "Notes", etc.

- [ ] **Step 2: Add an "Examine this thought" menu item that presents the wizard**

`LogCard` will need a new `@State` to track whether the thought-record sheet is showing. Add to `LogCard`:

```swift
@State private var showingThoughtRecord = false
```

In the share menu, add (place above the existing journal/notes entries so it's prominent):

```swift
Button {
    showingThoughtRecord = true
} label: {
    Label("Examine this thought", systemImage: "questionmark.bubble")
}
```

In the body, after the existing `.sheet` modifiers (or alongside them), add:

```swift
.sheet(isPresented: $showingThoughtRecord) {
    ThoughtRecordFlowView(draft: ThoughtRecordDraft.from(log: log))
}
```

- [ ] **Step 3: Build**

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

Expected: ** BUILD SUCCEEDED **

- [ ] **Step 4: Run full UI suite to confirm no regression**

```sh
xcodebuild ... -only-testing:OpenFeelingsUITests test
```

Expected: All 11 UI tests still pass (one may flake on cold launch — re-run the failing test in isolation if so; this is a pre-existing flake documented in build 28).

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Views/HistoryView.swift
git commit -m "Add Examine this thought share-menu entry on LogCard"
```

---

## Task 13: Update CloudKit production deployment runbook

**Files:**
- Modify: `docs/release/cloudkit-production-deployment.md`

- [ ] **Step 1: Add CD_ThoughtRecord to the schema reference**

Open `docs/release/cloudkit-production-deployment.md`. After the `### CD_CommittedAction` block, add:

````markdown
### `CD_ThoughtRecord` — *new since build 28*

| SwiftData property | CloudKit field | Type | Notes |
|---|---|---|---|
| `id` | `CD_id` | String (UUID) | |
| `createdAt` | `CD_createdAt` | Date | **Queryable index required** — newest-first sort on Direction tab |
| `situation` | `CD_situation` | String | Optional context |
| `automaticThought` | `CD_automaticThought` | String | The noticed thought (required to save) |
| `intensityBefore` | `CD_intensityBefore` | Int (optional) | 1…5 |
| `patternsRaw` | `CD_patternsRaw` | String | Comma-joined `ThinkingPattern` raw values |
| `balancedThought` | `CD_balancedThought` | String | Reframe (required to save) |
| `intensityAfter` | `CD_intensityAfter` | Int (optional) | 1…5 |
| `linkedLogID` | `CD_linkedLogID` | String (UUID, optional) | Optional FK to `FeelingLog.id` |
````

- [ ] **Step 2: Add the queryable index row**

In the "Step 3 — Add queryable indexes" table, add a new row:

```markdown
| `CD_ThoughtRecord` | `CD_createdAt` | Queryable |
```

- [ ] **Step 3: Update the top-of-file warning**

Find the `> ⚠️ Likely silent-sync failure right now.` block at the top. Update the parenthetical to mention `CD_ThoughtRecord`:

> Replace `(CustomBodyRegion, CustomValue, ValueSort, CommittedAction, UserBodyMap)` with `(CustomBodyRegion, CustomValue, ValueSort, CommittedAction, UserBodyMap, ThoughtRecord)`.

- [ ] **Step 4: Commit**

```sh
git add docs/release/cloudkit-production-deployment.md
git commit -m "Document CD_ThoughtRecord in CloudKit production runbook"
```

---

## Task 14: End-to-end verification + roadmap update

- [ ] **Step 1: Run the full unit + UI test suite**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=Tesela-Test' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

Expected: Net 343 + 13 (Task 2) + 9 (Task 3) + 4 (Task 10) = 369 unit tests; 11 UI tests. If the cold-launch UI test flakes, re-run in isolation.

- [ ] **Step 2: Manual smoke on iPad simulator**

Launch the app on a fresh sim. Verify:

1. Direction tab shows three areas: Intentions, Values, Thought records.
2. Tap "Start a record" → wizard opens at Situation step.
3. Walk through all 7 screens, save. Returns to Direction tab.
4. Record appears in "Recent" list with date + truncated thought + delta badge.
5. Tap the row → detail view opens with all fields + intensity-shift arrow.
6. Tap pencil → wizard re-opens with all fields pre-filled. Edit one field, save. Record updates in place.
7. Swipe-delete a record → confirmation alert → confirms removes it.
8. From History tab, tap a LogCard share menu → "Examine this thought" → wizard opens with Situation + intensity-before pre-filled from the log.

- [ ] **Step 3: Update the roadmap**

Open `.docs/ai/roadmap.md`. Under "Later" or "Next" (your choice), add:

```markdown
### Next
- [x] CBT Thought Records — Direction-tab third area. Burns-style 6-step
  wizard, 8 curated thinking-pattern chips, optional linkage to a check-in
  via LogCard share menu. Shipped in build [NEXT_BUILD].
```

Replace `[NEXT_BUILD]` with the next build number once the release script
bumps it.

- [ ] **Step 4: Commit the roadmap update**

```sh
git add .docs/ai/roadmap.md
git commit -m "Mark thought records as shipped in roadmap"
```

- [ ] **Step 5: Ship to TestFlight**

```sh
./scripts/release.sh
```

Expected output ends with `✔ Open Feelings 0.1.0 (build N) uploaded to TestFlight`.

---

## Notes on the CloudKit production redeploy

Adding `ThoughtRecord` adds `CD_ThoughtRecord` (one new record type) and one new queryable index to the schema. The existing TestFlight builds already require a re-deploy because builds 21–27 added five new types — `CD_ThoughtRecord` joins that list. After this plan ships, follow `docs/release/cloudkit-production-deployment.md` to redeploy. Until that's done, thought records will silent-fail to mirror to iCloud (same caveat documented for the other build-27 types).

## What's intentionally out of scope (handled later)

These items are mentioned in the spec under "Out (deferred to a follow-up)" and **must not** be implemented as part of this plan:

- Watch-side support for thought records
- Insights charts (patterns over time, intensity-shift histogram)
- Therapy-PDF inclusion of thought records
- Reminders to do a thought record
- Sharing individual records via the iOS share sheet (Markdown / Journal / Day One / Notes)
- Bulk operations / search across records

If any of these come up during implementation, defer them to a future plan; do not expand scope.
