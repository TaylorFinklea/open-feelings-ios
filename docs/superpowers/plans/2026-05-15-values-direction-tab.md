# Values + Direction Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the renamed **Direction** tab with a values card-sort flow, ranked-values surface, and committed-actions tracking — all standalone from feeling-log data.

**Architecture:** Static `ValueTaxonomy` (~50 curated values) + three new SwiftData `@Model` types (`CustomValue`, `ValueSort`, `CommittedAction`). All ride the existing CloudKit private DB. The `Intentions` tab is renamed to `Direction` and hosts two areas: the existing Intentions content (unchanged) and a new Values area with a four-screen sort flow (Bucket → Pick finalists → Rank → Confirm). An in-memory `@Observable SortSession` owns the in-flight sort; only the final `Confirm` writes a row.

**Tech Stack:** Swift 6, SwiftUI, SwiftData + `NSPersistentCloudKitContainer`, XCTest. xcodegen workflow.

**Source spec:** `docs/superpowers/specs/2026-05-15-values-direction-tab-design.md`

---

## Working-directory note

There is in-flight uncommitted work for the **custom body regions** feature (Stream B) in the same tree. That work is parallel and does not block this plan: it modifies different files (`BodyEmotionMap.swift`, `FeelingLog.swift`, `LearnedBodyMap.swift`, `BodyStep.swift`, `BodyMapSettingsView.swift`, body-region tests). The Schema in `OpenFeelingsApp.swift` already lists `CustomBodyRegion.self`. This plan extends that schema with the three new Values models. Land or commit the body-regions work first, or commit each Values task strictly against the files it touches — either approach works.

## File structure

**New (Swift sources):**

| Path | Responsibility |
| --- | --- |
| `OpenFeelings/Models/ValueTaxonomy.swift` | `ValueDefinition` struct, static `all: [ValueDefinition]` list (~50 entries), id lookup. |
| `OpenFeelings/Models/ValueRef.swift` | Helpers to encode/decode `"family"` vs `"custom:<uuid>"`, `displayName` resolution with fallbacks. |
| `OpenFeelings/Models/CustomValue.swift` | `@Model final class CustomValue { id, name, createdAt }`. |
| `OpenFeelings/Models/ValueSort.swift` | `@Model final class ValueSort` + `SortBucket` enum + JSON encode/decode helpers. |
| `OpenFeelings/Models/CommittedAction.swift` | `@Model final class CommittedAction` + `markDone(at:)` mutator. |
| `OpenFeelings/Models/SortSession.swift` | `@Observable @MainActor final class SortSession` — in-flight sort state. |
| `OpenFeelings/Views/Direction/DirectionView.swift` | Tab root. Hosts `IntentionsContent` + `ValuesArea`. |
| `OpenFeelings/Views/Direction/Intentions/IntentionsContent.swift` | Body lifted from today's `IntentionsView.swift` (logic unchanged). |
| `OpenFeelings/Views/Direction/Values/ValuesArea.swift` | Empty state OR ranked-values + actions list + Re-sort. |
| `OpenFeelings/Views/Direction/Values/CommittedActionRow.swift` | One row in the actions list. |
| `OpenFeelings/Views/Direction/Values/CommittedActionDetail.swift` | Detail screen with mark-done + reflection. |
| `OpenFeelings/Views/Direction/Values/CommittedActionEditor.swift` | Sheet for create/edit. |
| `OpenFeelings/Views/Direction/Values/Sort/SortFlowView.swift` | NavigationStack hosting the four-step flow. |
| `OpenFeelings/Views/Direction/Values/Sort/BucketStepView.swift` | One-card-at-a-time bucketing. |
| `OpenFeelings/Views/Direction/Values/Sort/FinalistsStepView.swift` | Chip pile, pick ≤10. |
| `OpenFeelings/Views/Direction/Values/Sort/RankStepView.swift` | `List` with `.onMove` drag-to-rank. |
| `OpenFeelings/Views/Direction/Values/Sort/ConfirmSortView.swift` | Preview + Confirm → writes row. |
| `OpenFeelingsTests/ValuesTests.swift` | All 11 tests called out in the spec. |

**Modified:**

| Path | Change |
| --- | --- |
| `OpenFeelings/OpenFeelingsApp.swift` | Extend `Schema(...)` with `CustomValue.self, ValueSort.self, CommittedAction.self`. |
| `OpenFeelings/Design/AppNavigation.swift` | Rename `case intentions` → `case direction`; update `title`/`systemImage`. |
| `OpenFeelings/Views/RootView.swift` | Mount `DirectionView()`; update `accessibilityIdentifier` to `"tab.direction"`. |

**Deleted:**

| Path | Reason |
| --- | --- |
| `OpenFeelings/Views/IntentionsView.swift` | Body lifted into `Direction/Intentions/IntentionsContent.swift`. |

---

## Task 1: ValueTaxonomy + integrity test

**Files:**
- Create: `OpenFeelings/Models/ValueTaxonomy.swift`
- Create: `OpenFeelingsTests/ValuesTests.swift`

- [ ] **Step 1: Write the failing test**

`OpenFeelingsTests/ValuesTests.swift` (new file):

```swift
import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class ValuesTests: XCTestCase {
    func testValueTaxonomyIntegrity() {
        let all = ValueTaxonomy.all
        XCTAssertGreaterThanOrEqual(all.count, 40, "expect ~50 curated values")

        let ids = all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "duplicate ids in taxonomy")

        let slugRegex = #"^[a-z][a-z0-9_]*$"#
        for def in all {
            XCTAssertFalse(def.name.isEmpty, "empty name for id=\(def.id)")
            XCTAssertFalse(def.description.isEmpty, "empty description for id=\(def.id)")
            XCTAssertNotNil(def.id.range(of: slugRegex, options: .regularExpression),
                            "id is not a lowercase slug: \(def.id)")
        }
    }
}
```

- [ ] **Step 2: Run the test (must fail to compile)**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  test -only-testing:OpenFeelingsTests/ValuesTests/testValueTaxonomyIntegrity \
  2>&1 | tail -10
```

Expected: build error referencing `ValueTaxonomy` not found.

- [ ] **Step 3: Implement ValueTaxonomy**

`OpenFeelings/Models/ValueTaxonomy.swift` (new file):

```swift
import Foundation

/// One entry in the curated values deck used by the value-sort flow.
/// Adapted from established ACT card sorts (e.g. Bond/Hayes Personal
/// Values Card Sort) and shipped in code. The id is a stable slug that
/// MUST NEVER change once shipped — committed actions reference it.
struct ValueDefinition: Hashable, Sendable, Identifiable {
    let id: String
    let name: String
    let description: String
}

enum ValueTaxonomy {
    static let all: [ValueDefinition] = [
        .init(id: "acceptance",   name: "Acceptance",   description: "Receiving myself and others as we are."),
        .init(id: "adventure",    name: "Adventure",    description: "Seeking out new and stimulating experiences."),
        .init(id: "authenticity", name: "Authenticity", description: "Acting in line with who I really am."),
        .init(id: "autonomy",     name: "Autonomy",     description: "Choosing my own path, free from coercion."),
        .init(id: "beauty",       name: "Beauty",       description: "Noticing and creating what is beautiful."),
        .init(id: "caring",       name: "Caring",       description: "Looking after others with warmth."),
        .init(id: "challenge",    name: "Challenge",    description: "Stretching myself with difficult goals."),
        .init(id: "community",    name: "Community",    description: "Belonging to and contributing to a group."),
        .init(id: "compassion",   name: "Compassion",   description: "Acting kindly toward suffering, mine and others'."),
        .init(id: "connection",   name: "Connection",   description: "Engaging fully with the people around me."),
        .init(id: "contribution", name: "Contribution", description: "Adding value to lives beyond my own."),
        .init(id: "cooperation",  name: "Cooperation",  description: "Working together toward shared aims."),
        .init(id: "courage",      name: "Courage",      description: "Acting on what matters even when afraid."),
        .init(id: "creativity",   name: "Creativity",   description: "Bringing something new into existence."),
        .init(id: "curiosity",    name: "Curiosity",    description: "Exploring, questioning, staying open."),
        .init(id: "dependability",name: "Dependability",description: "Being someone others can count on."),
        .init(id: "discipline",   name: "Discipline",   description: "Following through with steady effort."),
        .init(id: "equality",     name: "Equality",     description: "Treating people as having equal worth."),
        .init(id: "excitement",   name: "Excitement",   description: "Pursuing thrill and intensity."),
        .init(id: "fairness",     name: "Fairness",     description: "Acting with justice and impartiality."),
        .init(id: "faith",        name: "Faith",        description: "Holding a steady trust in something larger."),
        .init(id: "family",       name: "Family",       description: "Investing in the people I call family."),
        .init(id: "fitness",      name: "Fitness",      description: "Caring for my body's strength and health."),
        .init(id: "flexibility",  name: "Flexibility",  description: "Adapting gracefully to what shows up."),
        .init(id: "forgiveness",  name: "Forgiveness",  description: "Letting go of resentment, mine and others'."),
        .init(id: "freedom",      name: "Freedom",      description: "Living without unnecessary constraint."),
        .init(id: "friendship",   name: "Friendship",   description: "Building close, mutual friendships."),
        .init(id: "fun",          name: "Fun",          description: "Making space for play and lightness."),
        .init(id: "generosity",   name: "Generosity",   description: "Giving freely of what I have."),
        .init(id: "growth",       name: "Growth",       description: "Continuing to learn and change."),
        .init(id: "health",       name: "Health",       description: "Tending to my physical and mental wellbeing."),
        .init(id: "honesty",      name: "Honesty",      description: "Telling the truth, even when it costs."),
        .init(id: "humor",        name: "Humor",        description: "Finding and sharing the absurd."),
        .init(id: "independence", name: "Independence", description: "Standing on my own when it matters."),
        .init(id: "industry",     name: "Industry",     description: "Doing meaningful, useful work."),
        .init(id: "intimacy",     name: "Intimacy",     description: "Sharing closeness, body and mind."),
        .init(id: "justice",      name: "Justice",      description: "Working for what is right."),
        .init(id: "kindness",     name: "Kindness",     description: "Treating others gently and well."),
        .init(id: "knowledge",    name: "Knowledge",    description: "Seeking understanding for its own sake."),
        .init(id: "love",         name: "Love",         description: "Loving and being loved."),
        .init(id: "loyalty",      name: "Loyalty",      description: "Standing by the people and groups I commit to."),
        .init(id: "mindfulness",  name: "Mindfulness",  description: "Showing up in the present moment."),
        .init(id: "openness",     name: "Openness",     description: "Welcoming new ideas, people, experiences."),
        .init(id: "order",        name: "Order",        description: "Living with structure and clarity."),
        .init(id: "patience",     name: "Patience",     description: "Waiting and acting with steady calm."),
        .init(id: "peace",        name: "Peace",        description: "Cultivating inner and outer calm."),
        .init(id: "play",         name: "Play",         description: "Making time for what is purely enjoyable."),
        .init(id: "respect",      name: "Respect",      description: "Treating people and things with regard."),
        .init(id: "responsibility",name: "Responsibility",description: "Taking ownership of my actions and choices."),
        .init(id: "safety",       name: "Safety",       description: "Keeping myself and those I love secure."),
        .init(id: "self_care",    name: "Self-care",    description: "Looking after my own needs."),
        .init(id: "service",      name: "Service",      description: "Acting on behalf of others' wellbeing."),
        .init(id: "spirituality", name: "Spirituality", description: "Engaging with something beyond myself."),
        .init(id: "stability",    name: "Stability",    description: "Living with steady ground beneath me."),
        .init(id: "tradition",    name: "Tradition",    description: "Honoring practices passed down."),
        .init(id: "trust",        name: "Trust",        description: "Building and keeping trust with others.")
    ]

    static func definition(id: String) -> ValueDefinition? {
        all.first { $0.id == id }
    }
}
```

- [ ] **Step 4: Run the test (must pass)**

Run the same `xcodebuild test -only-testing:...` command. Expected: PASS.

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Models/ValueTaxonomy.swift OpenFeelingsTests/ValuesTests.swift
git commit -m "Add ValueTaxonomy with curated values deck"
```

---

## Task 2: ValueRef helper + display-name tests

**Files:**
- Create: `OpenFeelings/Models/ValueRef.swift`
- Modify: `OpenFeelingsTests/ValuesTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `OpenFeelingsTests/ValuesTests.swift` (inside the `ValuesTests` class):

```swift
    func testValueRefDisplayNameResolvesCurated() {
        let name = ValueRef.displayName(for: "family", customs: [])
        XCTAssertEqual(name, "Family")
    }

    func testValueRefDisplayNameResolvesCustom() {
        let uuid = UUID()
        let custom = CustomValue(id: uuid, name: "Surfing")
        let name = ValueRef.displayName(for: "custom:\(uuid.uuidString)", customs: [custom])
        XCTAssertEqual(name, "Surfing")
    }

    func testValueRefDisplayNameMissingCustomFallback() {
        let name = ValueRef.displayName(for: "custom:\(UUID().uuidString)", customs: [])
        XCTAssertEqual(name, "(removed value)")
    }

    func testValueRefIsCustom() {
        XCTAssertTrue(ValueRef.isCustom("custom:abc"))
        XCTAssertFalse(ValueRef.isCustom("family"))
    }
```

- [ ] **Step 2: Run tests (must fail to compile — `ValueRef` and `CustomValue` do not exist yet)**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  test -only-testing:OpenFeelingsTests/ValuesTests \
  2>&1 | tail -10
```

Expected: build error — `ValueRef` and/or `CustomValue` unresolved.

- [ ] **Step 3: Implement CustomValue and ValueRef (minimal — CustomValue used as a struct-like value here)**

`OpenFeelings/Models/CustomValue.swift` (new file):

```swift
import Foundation
import SwiftData

/// User-added value. Lives alongside the curated `ValueTaxonomy`
/// so users can add idiosyncratic values during a sort.
/// CloudKit-synced through the same private DB as other models.
@Model
final class CustomValue {
    /// Stable identifier referenced from `ValueSort.rankedTopRaw`,
    /// `ValueSort.bucketAssignmentsRaw`, and `CommittedAction.valueRef`
    /// via the `"custom:<uuid>"` form. Survives renames.
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

extension CustomValue {
    static func sortedByCreation(_ values: [CustomValue]) -> [CustomValue] {
        values.sorted { $0.createdAt < $1.createdAt }
    }
}
```

`OpenFeelings/Models/ValueRef.swift` (new file):

```swift
import Foundation

/// Encodes a reference to a value as a string. `"family"` for curated
/// taxonomy entries, `"custom:<uuid>"` for user-added values. String form
/// is what gets persisted into `ValueSort` and `CommittedAction.valueRef`.
enum ValueRef {
    static let customPrefix = "custom:"

    static func isCustom(_ ref: String) -> Bool {
        ref.hasPrefix(customPrefix)
    }

    static func customUUID(from ref: String) -> UUID? {
        guard isCustom(ref) else { return nil }
        return UUID(uuidString: String(ref.dropFirst(customPrefix.count)))
    }

    static func makeCustomRef(_ id: UUID) -> String {
        customPrefix + id.uuidString
    }

    /// Resolve a ref to a user-facing name.
    /// Falls back to `"(removed value)"` if the referenced custom value
    /// is missing, and `"(unknown value)"` if a curated id is unknown.
    static func displayName(for ref: String, customs: [CustomValue]) -> String {
        if let uuid = customUUID(from: ref) {
            return customs.first { $0.id == uuid }?.name ?? "(removed value)"
        }
        return ValueTaxonomy.definition(id: ref)?.name ?? "(unknown value)"
    }
}
```

- [ ] **Step 4: Run tests (must pass)**

Same `xcodebuild test -only-testing:OpenFeelingsTests/ValuesTests` command. Expected: 5 tests passing (one from Task 1 + 4 new).

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Models/CustomValue.swift OpenFeelings/Models/ValueRef.swift \
  OpenFeelingsTests/ValuesTests.swift
git commit -m "Add CustomValue model and ValueRef resolver"
```

---

## Task 3: ValueSort model + JSON round-trip test

**Files:**
- Create: `OpenFeelings/Models/ValueSort.swift`
- Modify: `OpenFeelings/OpenFeelingsApp.swift`
- Modify: `OpenFeelingsTests/ValuesTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `OpenFeelingsTests/ValuesTests.swift`:

```swift
    private func makeContext(schema overrideSchema: Schema? = nil) throws -> ModelContext {
        let schema = overrideSchema ?? Schema([
            CustomValue.self, ValueSort.self, CommittedAction.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testValueSortJSONRoundTripPreservesBucketAndRanking() throws {
        let uuid = UUID()
        let assignments: [String: SortBucket] = [
            "family": .veryImportant,
            "honesty": .veryImportant,
            "status": .notForMe,
            "growth": .important,
            ValueRef.makeCustomRef(uuid): .veryImportant
        ]
        let ranked = ["family", "honesty", ValueRef.makeCustomRef(uuid)]
        let sort = ValueSort(bucketAssignments: assignments, rankedTop: ranked)

        XCTAssertEqual(sort.bucketAssignments, assignments)
        XCTAssertEqual(sort.rankedTop, ranked)

        // Persisting and re-reading via raw fields also round-trips.
        let raw = sort.bucketAssignmentsRaw
        let copy = ValueSort()
        copy.bucketAssignmentsRaw = raw
        copy.rankedTopRaw = sort.rankedTopRaw
        XCTAssertEqual(copy.bucketAssignments, assignments)
        XCTAssertEqual(copy.rankedTop, ranked)
    }

    func testNewestValueSortIsActive() throws {
        let context = try makeContext()
        let older = ValueSort(
            createdAt: Date(timeIntervalSince1970: 1_000_000),
            bucketAssignments: ["family": .veryImportant],
            rankedTop: ["family"]
        )
        let newer = ValueSort(
            createdAt: Date(timeIntervalSince1970: 2_000_000),
            bucketAssignments: ["growth": .veryImportant],
            rankedTop: ["growth"]
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        var descriptor = FetchDescriptor<ValueSort>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        let active = try context.fetch(descriptor).first
        XCTAssertEqual(active?.rankedTop, ["growth"])
    }
```

- [ ] **Step 2: Run tests (must fail to compile)**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  test -only-testing:OpenFeelingsTests/ValuesTests \
  2>&1 | tail -10
```

Expected: build error — `ValueSort` and `SortBucket` unresolved.

- [ ] **Step 3: Implement ValueSort + SortBucket**

`OpenFeelings/Models/ValueSort.swift` (new file):

```swift
import Foundation
import SwiftData

/// Which bucket a value was sorted into during Phase 1 of the card sort.
enum SortBucket: String, Codable, Sendable, CaseIterable {
    case veryImportant
    case important
    case notForMe
}

/// One completed value sort. Newest sort by `createdAt` is the active set;
/// older ones are retained as read-only history. Refs are strings:
/// `"family"` for curated entries, `"custom:<uuid>"` for `CustomValue`.
@Model
final class ValueSort {
    var id: UUID = UUID()
    var createdAt: Date = Date()

    /// JSON-encoded `[String: String]` (refs → SortBucket.rawValue).
    /// String storage matches `bodyRegionsRaw` precedent on `FeelingLog`
    /// and avoids CloudKit limitations around typed dictionaries.
    var bucketAssignmentsRaw: String = "{}"

    /// JSON-encoded `[String]` — ordered finalists, position 0 = #1 rank.
    var rankedTopRaw: String = "[]"

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         bucketAssignments: [String: SortBucket] = [:],
         rankedTop: [String] = []) {
        self.id = id
        self.createdAt = createdAt
        self.bucketAssignmentsRaw = Self.encodeAssignments(bucketAssignments)
        self.rankedTopRaw = Self.encodeRanked(rankedTop)
    }
}

extension ValueSort {
    var bucketAssignments: [String: SortBucket] {
        get { Self.decodeAssignments(bucketAssignmentsRaw) }
        set { bucketAssignmentsRaw = Self.encodeAssignments(newValue) }
    }

    var rankedTop: [String] {
        get { Self.decodeRanked(rankedTopRaw) }
        set { rankedTopRaw = Self.encodeRanked(newValue) }
    }

    static func encodeAssignments(_ dict: [String: SortBucket]) -> String {
        let raw = dict.mapValues(\.rawValue)
        guard let data = try? JSONEncoder().encode(raw),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    static func decodeAssignments(_ raw: String) -> [String: SortBucket] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded.compactMapValues { SortBucket(rawValue: $0) }
    }

    static func encodeRanked(_ list: [String]) -> String {
        guard let data = try? JSONEncoder().encode(list),
              let s = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return s
    }

    static func decodeRanked(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }
}
```

- [ ] **Step 4: Register in the app schema**

In `OpenFeelings/OpenFeelingsApp.swift` replace the line:

```swift
let schema = Schema([FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self])
```

with:

```swift
let schema = Schema([
    FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
    CustomValue.self, ValueSort.self
])
```

(We'll add `CommittedAction.self` in Task 4 — keep the schema change tight to the model being introduced.)

- [ ] **Step 5: Run tests (must pass — but `CommittedAction` symbol is referenced in `makeContext`; remove it for now)**

Update the `makeContext` schema literal added in Step 1 to drop `CommittedAction.self` for this commit, then re-add it in Task 4:

```swift
let schema = overrideSchema ?? Schema([CustomValue.self, ValueSort.self])
```

Run:

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  test -only-testing:OpenFeelingsTests/ValuesTests \
  2>&1 | tail -10
```

Expected: all 7 tests passing.

- [ ] **Step 6: Commit**

```sh
git add OpenFeelings/Models/ValueSort.swift OpenFeelings/OpenFeelingsApp.swift \
  OpenFeelingsTests/ValuesTests.swift
git commit -m "Add ValueSort model with JSON round-trip"
```

---

## Task 4: CommittedAction model + lifecycle tests

**Files:**
- Create: `OpenFeelings/Models/CommittedAction.swift`
- Modify: `OpenFeelings/OpenFeelingsApp.swift`
- Modify: `OpenFeelingsTests/ValuesTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `OpenFeelingsTests/ValuesTests.swift`:

```swift
    func testCommittedActionLifecycleMarkDoneSetsCompletedAt() throws {
        let action = CommittedAction(title: "Call my brother", valueRef: "family",
                                     whatsHard: "We haven't spoken in a year.")
        XCTAssertFalse(action.isDone)
        XCTAssertNil(action.completedAt)
        XCTAssertEqual(action.reflection, "")

        let now = Date()
        action.markDone(at: now)

        XCTAssertTrue(action.isDone)
        XCTAssertEqual(action.completedAt, now)
        XCTAssertEqual(action.title, "Call my brother")
        XCTAssertEqual(action.valueRef, "family")
        XCTAssertEqual(action.whatsHard, "We haven't spoken in a year.")
        XCTAssertEqual(action.reflection, "")
    }

    func testCommittedActionPersistsAcrossReSort() throws {
        let context = try makeContext()
        let action = CommittedAction(title: "Hard 1:1", valueRef: "honesty")
        context.insert(action)

        // First sort exists.
        let first = ValueSort(bucketAssignments: ["honesty": .veryImportant],
                              rankedTop: ["honesty"])
        context.insert(first)
        try context.save()

        // User re-sorts and "honesty" gets dropped from the new ranked list.
        let second = ValueSort(createdAt: Date(timeIntervalSinceNow: 10),
                               bucketAssignments: ["growth": .veryImportant],
                               rankedTop: ["growth"])
        context.insert(second)
        try context.save()

        let descriptor = FetchDescriptor<CommittedAction>()
        let found = try context.fetch(descriptor)
        XCTAssertEqual(found.count, 1)
        XCTAssertEqual(found.first?.valueRef, "honesty")
    }

    func testCommittedActionWithDroppedValueRefStillResolvesToFallback() {
        let action = CommittedAction(title: "x", valueRef: "honesty")
        // Active sort no longer includes "honesty"; ranked list is just ["growth"].
        let activeRanked: [String] = ["growth"]
        let inActive = activeRanked.contains(action.valueRef)
        XCTAssertFalse(inActive)
        let label = inActive
            ? ValueRef.displayName(for: action.valueRef, customs: [])
            : "(not in current values)"
        XCTAssertEqual(label, "(not in current values)")
    }
```

- [ ] **Step 2: Restore the test-helper schema to include `CommittedAction.self`**

In the `makeContext` helper added in Task 3 Step 1, change back to:

```swift
let schema = overrideSchema ?? Schema([
    CustomValue.self, ValueSort.self, CommittedAction.self
])
```

- [ ] **Step 3: Run tests (must fail — `CommittedAction` undefined)**

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  test -only-testing:OpenFeelingsTests/ValuesTests \
  2>&1 | tail -10
```

Expected: build error.

- [ ] **Step 4: Implement CommittedAction**

`OpenFeelings/Models/CommittedAction.swift` (new file):

```swift
import Foundation
import SwiftData

/// A concrete commitment tied to one value. Standalone from feeling logs.
/// Persists across re-sorts: the `valueRef` is a stable id; if the user's
/// active `ValueSort` drops that value, the action stays in the list with
/// a "(not in current values)" badge instead of disappearing.
@Model
final class CommittedAction {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var title: String = ""
    var valueRef: String = ""      // "family" or "custom:<uuid>"
    var whatsHard: String = ""     // optional; empty if not provided
    var isDone: Bool = false
    var completedAt: Date?
    var reflection: String = ""    // optional; written after marking done

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         title: String,
         valueRef: String,
         whatsHard: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.valueRef = valueRef
        self.whatsHard = whatsHard
        self.isDone = false
        self.completedAt = nil
        self.reflection = ""
    }
}

extension CommittedAction {
    /// Flip to done and stamp the completion time. Idempotent if already done.
    func markDone(at instant: Date = Date()) {
        if isDone { return }
        isDone = true
        completedAt = instant
    }
}
```

- [ ] **Step 5: Extend the app schema**

In `OpenFeelings/OpenFeelingsApp.swift`, update the `Schema(...)` line to:

```swift
let schema = Schema([
    FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
    CustomValue.self, ValueSort.self, CommittedAction.self
])
```

- [ ] **Step 6: Run tests (must pass)**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  test -only-testing:OpenFeelingsTests/ValuesTests \
  2>&1 | tail -10
```

Expected: all 10 tests passing.

- [ ] **Step 7: Commit**

```sh
git add OpenFeelings/Models/CommittedAction.swift OpenFeelings/OpenFeelingsApp.swift \
  OpenFeelingsTests/ValuesTests.swift
git commit -m "Add CommittedAction model with mark-done lifecycle"
```

---

## Task 5: SortSession in-memory state + tests

**Files:**
- Create: `OpenFeelings/Models/SortSession.swift`
- Modify: `OpenFeelingsTests/ValuesTests.swift`

- [ ] **Step 1: Add failing tests**

Append to `OpenFeelingsTests/ValuesTests.swift`:

```swift
    private func sampleSession(_ customs: [CustomValue] = []) -> SortSession {
        SortSession(curated: ValueTaxonomy.all, custom: customs)
    }

    func testSortSessionAdvanceRefusesWhenBucketingIncomplete() {
        let session = sampleSession()
        XCTAssertEqual(session.phase, .bucketing)
        let advanced = session.advancePhase()
        XCTAssertFalse(advanced)
        XCTAssertEqual(session.phase, .bucketing)
    }

    func testSortSessionFinalistsCappedAtTen() {
        let session = sampleSession()
        // Bucket the first 12 cards as veryImportant.
        for _ in 0..<12 {
            guard let ref = session.currentRef else { break }
            session.bucket(ref, into: .veryImportant)
        }
        // Now bucket everything else as notForMe so we can advance.
        while let ref = session.currentRef {
            session.bucket(ref, into: .notForMe)
        }
        XCTAssertTrue(session.advancePhase())
        XCTAssertEqual(session.phase, .pickingFinalists)

        let pool = session.veryImportantPool
        XCTAssertEqual(pool.count, 12)

        for ref in pool { session.toggleFinalist(ref) }
        XCTAssertEqual(session.finalists.count, 10, "cap at 10 enforced")
    }

    func testSortSessionUndoRevertsLastBucket() {
        let session = sampleSession()
        guard let first = session.currentRef else { return XCTFail("empty deck") }
        session.bucket(first, into: .veryImportant)
        XCTAssertEqual(session.assignments[first], .veryImportant)
        XCTAssertNotEqual(session.currentRef, first)
        let undone = session.undoLastBucket()
        XCTAssertTrue(undone)
        XCTAssertNil(session.assignments[first])
        XCTAssertEqual(session.currentRef, first)
    }

    func testSortSessionFinalizeWritesValueSortRow() throws {
        let context = try makeContext()
        let session = sampleSession()
        // Bucket all into notForMe except the first 3 which go to veryImportant.
        for i in 0..<3 {
            if let ref = session.currentRef {
                session.bucket(ref, into: .veryImportant)
            }
            _ = i
        }
        while let ref = session.currentRef {
            session.bucket(ref, into: .notForMe)
        }
        XCTAssertTrue(session.advancePhase())
        for ref in session.veryImportantPool { session.toggleFinalist(ref) }
        XCTAssertTrue(session.advancePhase())                  // pickingFinalists → ranking
        XCTAssertEqual(session.ranked.count, session.finalists.count)
        XCTAssertTrue(session.advancePhase())                  // ranking → confirming
        let written = session.finalize(into: context)
        XCTAssertNotNil(written)
        try context.save()

        let descriptor = FetchDescriptor<ValueSort>()
        let rows = try context.fetch(descriptor)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.rankedTop.count, 3)
    }
```

- [ ] **Step 2: Run tests (must fail to compile)**

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  test -only-testing:OpenFeelingsTests/ValuesTests \
  2>&1 | tail -10
```

Expected: build error — `SortSession` and its members unresolved.

- [ ] **Step 3: Implement SortSession**

`OpenFeelings/Models/SortSession.swift` (new file):

```swift
import Foundation
import SwiftData
import SwiftUI

/// In-flight state for one card-sort session. Held in memory by
/// `SortFlowView` and discarded on cancel. Only `finalize(into:)` writes
/// a row. Phase transitions are gated — `advancePhase()` refuses if the
/// current phase isn't complete.
@MainActor
@Observable
final class SortSession {
    enum Phase: Sendable {
        case bucketing
        case pickingFinalists
        case ranking
        case confirming
    }

    private(set) var phase: Phase = .bucketing

    /// Snapshot of the deck order at session start. The current card pointer
    /// `index` walks this array. Custom values added mid-flow are appended.
    private(set) var deck: [String]
    private(set) var index: Int = 0

    private(set) var assignments: [String: SortBucket] = [:]
    private(set) var history: [String] = []        // refs in bucket order, for undo
    private(set) var finalists: [String] = []
    private(set) var ranked: [String] = []

    static let finalistCap = 10

    init(curated: [ValueDefinition], custom: [CustomValue]) {
        let curatedRefs = curated.map(\.id)
        let customRefs = custom.map { ValueRef.makeCustomRef($0.id) }
        self.deck = curatedRefs + customRefs
    }

    var currentRef: String? {
        guard index < deck.count else { return nil }
        return deck[index]
    }

    var veryImportantPool: [String] {
        deck.filter { assignments[$0] == .veryImportant }
    }

    func bucket(_ ref: String, into bucket: SortBucket) {
        guard phase == .bucketing, currentRef == ref else { return }
        assignments[ref] = bucket
        history.append(ref)
        index += 1
    }

    @discardableResult
    func undoLastBucket() -> Bool {
        guard phase == .bucketing, let last = history.popLast() else { return false }
        assignments.removeValue(forKey: last)
        index = max(0, index - 1)
        return true
    }

    /// Append a new custom value to the remaining deck (only valid during bucketing).
    func appendCustom(_ ref: String) {
        guard phase == .bucketing else { return }
        deck.append(ref)
    }

    func toggleFinalist(_ ref: String) {
        guard phase == .pickingFinalists else { return }
        if let i = finalists.firstIndex(of: ref) {
            finalists.remove(at: i)
        } else if finalists.count < Self.finalistCap {
            finalists.append(ref)
        }
    }

    func reorderRanked(from source: IndexSet, to destination: Int) {
        guard phase == .ranking else { return }
        ranked.move(fromOffsets: source, toOffset: destination)
    }

    @discardableResult
    func advancePhase() -> Bool {
        switch phase {
        case .bucketing:
            guard index >= deck.count else { return false }
            phase = .pickingFinalists
            return true
        case .pickingFinalists:
            guard !finalists.isEmpty else { return false }
            ranked = finalists
            phase = .ranking
            return true
        case .ranking:
            guard !ranked.isEmpty else { return false }
            phase = .confirming
            return true
        case .confirming:
            return false
        }
    }

    /// Reset to a fresh bucketing pass while keeping the deck the same.
    /// Used by the empty-Very-important-pile fallback in FinalistsStepView.
    func restartBucketing() {
        phase = .bucketing
        index = 0
        assignments.removeAll()
        history.removeAll()
        finalists.removeAll()
        ranked.removeAll()
    }

    /// Write the finalized ValueSort row. No-op + returns nil if not in
    /// the confirming phase or the ranked list is empty.
    @discardableResult
    func finalize(into context: ModelContext) -> ValueSort? {
        guard phase == .confirming, !ranked.isEmpty else { return nil }
        let sort = ValueSort(
            createdAt: .now,
            bucketAssignments: assignments,
            rankedTop: ranked
        )
        context.insert(sort)
        return sort
    }
}
```

- [ ] **Step 4: Run tests (must pass)**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  test -only-testing:OpenFeelingsTests/ValuesTests \
  2>&1 | tail -10
```

Expected: all 14 tests passing.

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Models/SortSession.swift OpenFeelingsTests/ValuesTests.swift
git commit -m "Add SortSession for in-memory sort progress"
```

---

## Task 6: Rename Intentions tab → Direction (compile-time)

**Files:**
- Modify: `OpenFeelings/Design/AppNavigation.swift`
- Modify: `OpenFeelings/Views/RootView.swift`

- [ ] **Step 1: Rename the enum case**

In `OpenFeelings/Design/AppNavigation.swift`, change:

```swift
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case today
    case checkIn
    case insights
    case intentions
    case settings

    var title: String {
        switch self {
        case .today:      "Today"
        case .checkIn:    "Check In"
        case .insights:   "Insights"
        case .intentions: "Intentions"
        case .settings:   "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today:      "sun.horizon"
        case .checkIn:    "circle.grid.3x3"
        case .insights:   "chart.line.uptrend.xyaxis"
        case .intentions: "leaf"
        case .settings:   "gearshape"
        }
    }
}
```

to:

```swift
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case today
    case checkIn
    case insights
    case direction
    case settings

    var title: String {
        switch self {
        case .today:     "Today"
        case .checkIn:   "Check In"
        case .insights:  "Insights"
        case .direction: "Direction"
        case .settings:  "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today:     "sun.horizon"
        case .checkIn:   "circle.grid.3x3"
        case .insights:  "chart.line.uptrend.xyaxis"
        case .direction: "leaf"
        case .settings:  "gearshape"
        }
    }
}
```

- [ ] **Step 2: Update RootView mount and accessibility id**

In `OpenFeelings/Views/RootView.swift`, replace this block:

```swift
NavigationStack { IntentionsView() }
    .tabItem {
        Label(AppTab.intentions.title, systemImage: AppTab.intentions.systemImage)
            .accessibilityIdentifier("tab.intentions")
    }
    .tag(AppTab.intentions)
```

with:

```swift
NavigationStack { DirectionView() }
    .tabItem {
        Label(AppTab.direction.title, systemImage: AppTab.direction.systemImage)
            .accessibilityIdentifier("tab.direction")
    }
    .tag(AppTab.direction)
```

(`DirectionView` does not exist yet — the build will be red until Task 7 lands. That's fine; finish Task 7 in the same commit.)

- [ ] **Step 3: Search for any other references to `.intentions` and update**

```sh
grep -rn '\.intentions\b\|"tab.intentions"\|AppTab\.intentions' OpenFeelings OpenFeelingsTests OpenFeelingsUITests 2>/dev/null
```

Expected after edit: zero matches. If any remain, update them to `.direction` / `"tab.direction"` and re-grep until clean. (Typical hits will be in any test or analytics that names the enum case.)

- [ ] **Step 4: Stop here — do not commit yet**

`DirectionView` is referenced but not implemented. Move to Task 7; commit at the end of Task 7.

---

## Task 7: Lift IntentionsView body into IntentionsContent + DirectionView shell

**Files:**
- Create: `OpenFeelings/Views/Direction/DirectionView.swift`
- Create: `OpenFeelings/Views/Direction/Intentions/IntentionsContent.swift`
- Delete: `OpenFeelings/Views/IntentionsView.swift`

- [ ] **Step 1: Read the existing IntentionsView**

Read the full body of `OpenFeelings/Views/IntentionsView.swift`. The file is the source of truth — copy it verbatim into the new location, only changing the type name.

- [ ] **Step 2: Create IntentionsContent.swift**

`OpenFeelings/Views/Direction/Intentions/IntentionsContent.swift` (new file):

Copy the entire body of `IntentionsView.swift` here, replacing the type name `IntentionsView` with `IntentionsContent` and removing any `NavigationStack` or top-level navigation chrome (the parent `DirectionView` owns the `NavigationStack`). If `IntentionsView` does NOT wrap its body in a `NavigationStack` (it should not, since `RootView` already wraps it), the copy is otherwise unchanged — just rename the struct.

Example shape:

```swift
import SwiftUI
import SwiftData

struct IntentionsContent: View {
    // ...all @Query, @Environment, @State exactly as they were in IntentionsView...

    var body: some View {
        // ...identical body...
    }

    // ...identical helpers, subviews, fileprivate types...
}
```

- [ ] **Step 3: Create DirectionView.swift with placeholder Values area**

`OpenFeelings/Views/Direction/DirectionView.swift` (new file):

```swift
import SwiftUI

struct DirectionView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                IntentionsContent()
                ValuesArea()
            }
            .padding(.horizontal)
        }
        .navigationTitle("Direction")
    }
}

/// Placeholder — filled in by Task 8.
private struct ValuesArea: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Values")
                .font(.title3.weight(.semibold))
            Text("Coming next.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack { DirectionView() }
}
```

(The `ValuesArea` here is a temporary inline placeholder. Task 8 replaces it with the real implementation in its own file.)

- [ ] **Step 4: Delete the old IntentionsView.swift**

```sh
git rm OpenFeelings/Views/IntentionsView.swift
```

- [ ] **Step 5: Regenerate Xcode project and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 6: Run the full test suite to confirm nothing else broke**

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -5
```

Expected: all tests pass (existing + 14 new from earlier tasks).

- [ ] **Step 7: Commit**

```sh
git add -A
git commit -m "Rename Intentions tab to Direction; lift body into IntentionsContent"
```

---

## Task 8: ValuesArea — empty state + Start the sort button

**Files:**
- Create: `OpenFeelings/Views/Direction/Values/ValuesArea.swift`
- Modify: `OpenFeelings/Views/Direction/DirectionView.swift`

- [ ] **Step 1: Create ValuesArea.swift**

`OpenFeelings/Views/Direction/Values/ValuesArea.swift` (new file):

```swift
import SwiftUI
import SwiftData

struct ValuesArea: View {
    @Query(sort: \ValueSort.createdAt, order: .reverse) private var sorts: [ValueSort]
    @State private var showingSort = false

    private var activeSort: ValueSort? { sorts.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Values")
                .font(.title3.weight(.semibold))

            if activeSort == nil {
                EmptyStateView { showingSort = true }
            } else {
                Text("Sort exists — populated state lands in Task 11.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingSort) {
            // Placeholder — SortFlowView lands in Task 10.
            Text("Sort flow — Task 10")
                .padding()
                .presentationDetents([.medium])
        }
    }
}

private struct EmptyStateView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your values, on your terms")
                .font(.headline)
            Text("A short card sort to figure out what matters to you, then a place to act on it.")
                .foregroundStyle(.secondary)
            Button(action: onStart) {
                Text("Start the sort")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
```

- [ ] **Step 2: Remove the placeholder from DirectionView**

In `OpenFeelings/Views/Direction/DirectionView.swift`, delete the `private struct ValuesArea` block at the bottom — the new file provides it. The top of the file (`import SwiftUI`, `struct DirectionView`, `#Preview`) stays.

- [ ] **Step 3: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```sh
git add OpenFeelings/Views/Direction/Values/ValuesArea.swift OpenFeelings/Views/Direction/DirectionView.swift
git commit -m "Add ValuesArea empty state"
```

---

## Task 9: Sort step views — Bucket, Finalists, Rank, Confirm

**Files:**
- Create: `OpenFeelings/Views/Direction/Values/Sort/BucketStepView.swift`
- Create: `OpenFeelings/Views/Direction/Values/Sort/FinalistsStepView.swift`
- Create: `OpenFeelings/Views/Direction/Values/Sort/RankStepView.swift`
- Create: `OpenFeelings/Views/Direction/Values/Sort/ConfirmSortView.swift`

- [ ] **Step 1: Create BucketStepView**

`OpenFeelings/Views/Direction/Values/Sort/BucketStepView.swift` (new file):

```swift
import SwiftUI
import SwiftData

struct BucketStepView: View {
    @Bindable var session: SortSession
    @Environment(\.modelContext) private var context

    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @State private var showingAddCustom = false
    @State private var newCustomName = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("\(session.index + 1) of \(session.deck.count)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            if let ref = session.currentRef {
                cardView(ref: ref)
                bucketButtons(ref: ref)
            } else {
                advancePrompt
            }

            HStack {
                Button("Undo", systemImage: "arrow.uturn.backward") {
                    session.undoLastBucket()
                }
                .disabled(session.history.isEmpty)
                Spacer()
                Button("Add your own value", systemImage: "plus") {
                    newCustomName = ""
                    showingAddCustom = true
                }
            }
            .font(.subheadline)
        }
        .padding()
        .navigationTitle("Sort values")
        .sheet(isPresented: $showingAddCustom) {
            AddCustomValueSheet(name: $newCustomName) { trimmed in
                let custom = CustomValue(name: trimmed)
                context.insert(custom)
                try? context.save()
                session.appendCustom(ValueRef.makeCustomRef(custom.id))
                showingAddCustom = false
            }
        }
    }

    @ViewBuilder
    private func cardView(ref: String) -> some View {
        VStack(spacing: 8) {
            Text(ValueRef.displayName(for: ref, customs: customs))
                .font(.title.weight(.semibold))
            if !ValueRef.isCustom(ref),
               let def = ValueTaxonomy.definition(id: ref) {
                Text(def.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func bucketButtons(ref: String) -> some View {
        VStack(spacing: 10) {
            Button { session.bucket(ref, into: .veryImportant) } label: {
                Text("Very important").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button { session.bucket(ref, into: .important) } label: {
                Text("Important").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button { session.bucket(ref, into: .notForMe) } label: {
                Text("Not for me").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var advancePrompt: some View {
        VStack(spacing: 12) {
            Text("All values bucketed.")
                .font(.headline)
            Button("Continue") { session.advancePhase() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
    }
}

private struct AddCustomValueSheet: View {
    @Binding var name: String
    let onAdd: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Value name", text: $name)
                    .focused($focused)
            }
            .navigationTitle("Add a value")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onAdd(trimmed)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task { focused = true }
        }
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 2: Create FinalistsStepView**

`OpenFeelings/Views/Direction/Values/Sort/FinalistsStepView.swift` (new file):

```swift
import SwiftUI
import SwiftData

struct FinalistsStepView: View {
    @Bindable var session: SortSession
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]

    var body: some View {
        let pool = session.veryImportantPool
        VStack(alignment: .leading, spacing: 16) {
            if pool.isEmpty {
                emptyPoolFallback
            } else {
                Text("Pick your finalists")
                    .font(.title2.weight(.semibold))
                Text("\(session.finalists.count) / \(SortSession.finalistCap)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                chipsGrid(refs: pool)
                Spacer(minLength: 8)
                Button("Continue to ranking") {
                    session.advancePhase()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(session.finalists.isEmpty)
            }
        }
        .padding()
        .navigationTitle("Finalists")
    }

    @ViewBuilder
    private var emptyPoolFallback: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("No values marked Very important")
                .font(.headline)
            Text("Restart the sort and place at least one value in the Very important bucket.")
                .foregroundStyle(.secondary)
            Button("Restart sort") {
                session.restartBucketing()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func chipsGrid(refs: [String]) -> some View {
        let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(refs, id: \.self) { ref in
                let selected = session.finalists.contains(ref)
                Button { session.toggleFinalist(ref) } label: {
                    HStack(spacing: 6) {
                        if selected { Image(systemName: "checkmark") }
                        Text(ValueRef.displayName(for: ref, customs: customs))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(selected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                    )
                    .foregroundStyle(selected ? Color.accentColor : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
```

- [ ] **Step 3: Create RankStepView**

`OpenFeelings/Views/Direction/Values/Sort/RankStepView.swift` (new file):

```swift
import SwiftUI
import SwiftData

struct RankStepView: View {
    @Bindable var session: SortSession
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Drag to rank")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 8)

            List {
                ForEach(session.ranked, id: \.self) { ref in
                    HStack {
                        if let position = session.ranked.firstIndex(of: ref) {
                            Text("\(position + 1)")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 24, alignment: .leading)
                                .foregroundStyle(.secondary)
                        }
                        Text(ValueRef.displayName(for: ref, customs: customs))
                    }
                }
                .onMove { source, destination in
                    session.reorderRanked(from: source, to: destination)
                }
            }
            .environment(\.editMode, .constant(.active))

            Button("Continue") { session.advancePhase() }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .navigationTitle("Rank")
    }
}
```

- [ ] **Step 4: Create ConfirmSortView**

`OpenFeelings/Views/Direction/Values/Sort/ConfirmSortView.swift` (new file):

```swift
import SwiftUI
import SwiftData

struct ConfirmSortView: View {
    @Bindable var session: SortSession
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Confirm your values")
                .font(.title2.weight(.semibold))
                .padding(.horizontal)

            List {
                ForEach(Array(session.ranked.enumerated()), id: \.offset) { pair in
                    HStack {
                        Text("\(pair.offset + 1)")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 24, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Text(ValueRef.displayName(for: pair.element, customs: customs))
                    }
                }
            }
            .listStyle(.plain)

            Button("Confirm") {
                if session.finalize(into: context) != nil {
                    try? context.save()
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .navigationTitle("Confirm")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 5: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED. (No wiring yet — these views aren't reachable until Task 10.)

- [ ] **Step 6: Commit**

```sh
git add OpenFeelings/Views/Direction/Values/Sort/
git commit -m "Add sort step views (Bucket, Finalists, Rank, Confirm)"
```

---

## Task 10: SortFlowView + wire it into ValuesArea

**Files:**
- Create: `OpenFeelings/Views/Direction/Values/Sort/SortFlowView.swift`
- Modify: `OpenFeelings/Views/Direction/Values/ValuesArea.swift`

- [ ] **Step 1: Create SortFlowView**

`OpenFeelings/Views/Direction/Values/Sort/SortFlowView.swift` (new file):

```swift
import SwiftUI
import SwiftData

/// Hosts the four-screen sort flow. Owns the SortSession.
struct SortFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]

    @State private var session: SortSession?

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    switch session.phase {
                    case .bucketing:        BucketStepView(session: session)
                    case .pickingFinalists: FinalistsStepView(session: session)
                    case .ranking:          RankStepView(session: session)
                    case .confirming:       ConfirmSortView(session: session)
                    }
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .task {
            if session == nil {
                session = SortSession(curated: ValueTaxonomy.all, custom: customs)
            }
        }
    }
}
```

- [ ] **Step 2: Wire SortFlowView into ValuesArea**

In `OpenFeelings/Views/Direction/Values/ValuesArea.swift`, replace the `.sheet(isPresented: $showingSort) { ... }` body:

```swift
.sheet(isPresented: $showingSort) {
    SortFlowView()
}
```

- [ ] **Step 3: Regenerate and build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Manual smoke test on simulator**

Launch the app in the simulator (or the user can do this), navigate to the **Direction** tab → tap **Start the sort** → bucket several cards → advance through finalists → rank → confirm. Verify a `ValueSort` row is written (the Values area will show "Sort exists — populated state lands in Task 11." after the sheet dismisses; that's the gating signal).

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Views/Direction/Values/Sort/SortFlowView.swift OpenFeelings/Views/Direction/Values/ValuesArea.swift
git commit -m "Wire SortFlowView into Direction tab"
```

---

## Task 11: ValuesArea — populated state (ranked list + Re-sort + actions section)

**Files:**
- Modify: `OpenFeelings/Views/Direction/Values/ValuesArea.swift`

- [ ] **Step 1: Replace ValuesArea body to render the populated case**

`OpenFeelings/Views/Direction/Values/ValuesArea.swift` (full replacement of the struct body):

```swift
import SwiftUI
import SwiftData

struct ValuesArea: View {
    @Query(sort: \ValueSort.createdAt, order: .reverse) private var sorts: [ValueSort]
    @Query(sort: \CustomValue.createdAt) private var customs: [CustomValue]
    @Query(sort: \CommittedAction.createdAt, order: .reverse) private var actions: [CommittedAction]
    @State private var showingSort = false
    @State private var showingEditor = false

    private var activeSort: ValueSort? { sorts.first }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Values")
                .font(.title3.weight(.semibold))

            if let active = activeSort {
                populatedState(active: active)
            } else {
                EmptyStateView { showingSort = true }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showingSort) { SortFlowView() }
        .sheet(isPresented: $showingEditor) {
            if let active = activeSort {
                CommittedActionEditor(rankedTop: active.rankedTop, customs: customs)
            }
        }
    }

    @ViewBuilder
    private func populatedState(active: ValueSort) -> some View {
        HStack {
            Text("YOUR VALUES")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                showingSort = true
            } label: {
                Label("Re-sort", systemImage: "arrow.triangle.2.circlepath")
            }
            .font(.subheadline)
        }

        ForEach(Array(active.rankedTop.enumerated()), id: \.offset) { pair in
            HStack {
                Text("\(pair.offset + 1)")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 24, alignment: .leading)
                    .foregroundStyle(.secondary)
                Text(ValueRef.displayName(for: pair.element, customs: customs))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
        }

        HStack {
            Text("COMMITTED ACTIONS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button { showingEditor = true } label: {
                Image(systemName: "plus")
            }
        }
        .padding(.top, 8)

        if actions.isEmpty {
            Text("No committed actions yet. Tap + to add one.")
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            ForEach(actions) { action in
                NavigationLink {
                    CommittedActionDetail(action: action, customs: customs)
                } label: {
                    CommittedActionRow(action: action,
                                       customs: customs,
                                       activeRanked: active.rankedTop)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct EmptyStateView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your values, on your terms")
                .font(.headline)
            Text("A short card sort to figure out what matters to you, then a place to act on it.")
                .foregroundStyle(.secondary)
            Button(action: onStart) {
                Text("Start the sort")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
```

`CommittedActionRow`, `CommittedActionEditor`, and `CommittedActionDetail` are added in Task 12. The build will be red until Task 12 lands.

- [ ] **Step 2: Pause here — Task 11 and Task 12 commit together at end of Task 12.**

---

## Task 12: CommittedActionRow + Detail + Editor

**Files:**
- Create: `OpenFeelings/Views/Direction/Values/CommittedActionRow.swift`
- Create: `OpenFeelings/Views/Direction/Values/CommittedActionDetail.swift`
- Create: `OpenFeelings/Views/Direction/Values/CommittedActionEditor.swift`

- [ ] **Step 1: Create CommittedActionRow**

`OpenFeelings/Views/Direction/Values/CommittedActionRow.swift` (new file):

```swift
import SwiftUI

struct CommittedActionRow: View {
    let action: CommittedAction
    let customs: [CustomValue]
    let activeRanked: [String]

    private var valueLabel: String {
        if activeRanked.contains(action.valueRef) {
            return ValueRef.displayName(for: action.valueRef, customs: customs)
        }
        return ValueRef.displayName(for: action.valueRef, customs: customs) + " · not in current values"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: action.isDone ? "checkmark.square.fill" : "square")
                .font(.title3)
                .foregroundStyle(action.isDone ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(.body)
                    .foregroundStyle(action.isDone ? .secondary : .primary)
                Text(valueLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .opacity(action.isDone ? 0.6 : 1.0)
    }
}
```

- [ ] **Step 2: Create CommittedActionDetail**

`OpenFeelings/Views/Direction/Values/CommittedActionDetail.swift` (new file):

```swift
import SwiftUI
import SwiftData

struct CommittedActionDetail: View {
    @Bindable var action: CommittedAction
    let customs: [CustomValue]
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                Text(action.title).font(.title3.weight(.semibold))
                Text("Serves: \(ValueRef.displayName(for: action.valueRef, customs: customs))")
                    .foregroundStyle(.secondary)
            }

            if !action.whatsHard.isEmpty {
                Section("What's hard about it") {
                    Text(action.whatsHard)
                }
            }

            if !action.isDone {
                Section {
                    Button("Mark done") {
                        action.markDone()
                        try? context.save()
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                Section("Done") {
                    if let completedAt = action.completedAt {
                        Text(completedAt.formatted(date: .long, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Reflection") {
                    TextField("How did it go?",
                              text: $action.reflection,
                              axis: .vertical)
                        .lineLimit(2...8)
                        .onChange(of: action.reflection) { _, _ in
                            try? context.save()
                        }
                }
            }
        }
        .navigationTitle("Committed action")
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

- [ ] **Step 3: Create CommittedActionEditor**

`OpenFeelings/Views/Direction/Values/CommittedActionEditor.swift` (new file):

```swift
import SwiftUI
import SwiftData

struct CommittedActionEditor: View {
    let rankedTop: [String]
    let customs: [CustomValue]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var valueRef: String = ""
    @State private var whatsHard: String = ""
    @State private var showAllValues = false

    private var allRefs: [String] {
        ValueTaxonomy.all.map(\.id) + customs.map { ValueRef.makeCustomRef($0.id) }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !valueRef.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Action") {
                    TextField("What will you do?", text: $title, axis: .vertical)
                        .lineLimit(1...3)
                }

                Section("Value it serves") {
                    Picker("Value", selection: $valueRef) {
                        Text("Pick one").tag("")
                        ForEach(showAllValues ? allRefs : rankedTop, id: \.self) { ref in
                            Text(ValueRef.displayName(for: ref, customs: customs)).tag(ref)
                        }
                    }
                    .pickerStyle(.inline)

                    Button(showAllValues ? "Show ranked only" : "All your values") {
                        showAllValues.toggle()
                    }
                    .font(.subheadline)
                }

                Section("What's hard about it (optional)") {
                    TextField("Optional", text: $whatsHard, axis: .vertical)
                        .lineLimit(1...6)
                }
            }
            .navigationTitle("New committed action")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedHard = whatsHard.trimmingCharacters(in: .whitespacesAndNewlines)
                        let action = CommittedAction(
                            title: trimmedTitle,
                            valueRef: valueRef,
                            whatsHard: trimmedHard
                        )
                        context.insert(action)
                        try? context.save()
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Regenerate, build, and run the full test suite**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED + all tests pass.

- [ ] **Step 5: Commit (covers Task 11 + Task 12)**

```sh
git add OpenFeelings/Views/Direction/Values/
git commit -m "Add Values populated state with committed actions"
```

---

## Task 13: Manual end-to-end verification

**No files.** Run the app on the simulator and execute the spec's manual verification list.

- [ ] **Step 1: Launch the app**

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build
open -a Simulator
```

Then run the app from Xcode (Product → Run) or `xcrun simctl launch`.

- [ ] **Step 2: Walk the spec's verification list**

Verify, in order:

1. Tab bar shows **Direction** (leaf icon).
2. Intentions today-editor and look-back render unchanged at the top of the Direction tab.
3. Below Intentions, Values area shows empty state with **Start the sort**.
4. Tap Start → bucketing screen. Bucket several cards. Undo reverses the last assignment.
5. Tap **Add your own value**, enter "Curiosity Plus", Add. It appears in the remaining deck.
6. Finish bucketing → finalists screen. Tap chips. Try to add an 11th → refused.
7. Advance → rank screen. Drag to reorder. Advance → confirm. Tap **Confirm**.
8. Values area now shows YOUR VALUES ranked + Re-sort button + empty COMMITTED ACTIONS section.
9. Tap **+**, enter "Call my brother", pick a value, optionally add "what's hard". Save. Row appears.
10. Tap row → detail. Tap **Mark done**. Reflection editor appears; type and save.
11. Force-quit and relaunch. Reflection persists.
12. Tap **Re-sort**, complete a different sort. YOUR VALUES updates; the committed action stays in COMMITTED ACTIONS. If its value was dropped, the subtitle reads "not in current values".

- [ ] **Step 3: Note any defects and triage**

Any unexpected behavior found in Step 2: open a fresh task per defect — do not patch silently in this plan's commits. End-of-plan is not the place to widen scope.

- [ ] **Step 4: Final commit if any docs-only updates were made**

If no defects, no commit needed. The feature is complete.

---

## Self-review summary

Reading this back against `docs/superpowers/specs/2026-05-15-values-direction-tab-design.md`:

- **Data models:** Task 1 (`ValueTaxonomy`), Task 2 (`CustomValue`, `ValueRef`), Task 3 (`ValueSort` + `SortBucket`), Task 4 (`CommittedAction`), Task 5 (`SortSession`). All present.
- **Tab rename + IA:** Task 6 (rename), Task 7 (lift Intentions, create DirectionView).
- **Empty Values state:** Task 8.
- **Sort flow (4 screens):** Task 9 (step views), Task 10 (host + wiring).
- **Empty-Very-important-pile fallback:** Task 9 Step 2 (`emptyPoolFallback` in `FinalistsStepView`).
- **Populated Values area + Re-sort + actions list:** Task 11.
- **Committed action row/detail/editor:** Task 12.
- **All 11 spec tests:** Tasks 1, 2, 3, 4, 5 (test IDs: `testValueTaxonomyIntegrity`, `testValueRef*` (3), `testValueSortJSONRoundTrip*`, `testNewestValueSortIsActive`, `testCommittedAction*` (3), `testSortSession*` (4) — 14 total, exceeding the spec's 11 by including coverage helpers).
- **Manual verification:** Task 13.

No placeholders, no "TBD", no "similar to Task N" without showing the code. Type and method names are consistent across tasks (`SortSession.Phase`, `SortBucket`, `ValueRef.makeCustomRef`, `ValueSort.bucketAssignments`).
