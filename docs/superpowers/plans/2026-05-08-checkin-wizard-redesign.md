# Check In Wizard Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing 3-step Check In wizard with a calm, configurable, one-question-per-step flow including body→emotion suggestion, personalization, and Settings-driven step composition.

**Architecture:** A pure-value `CheckInFlowEngine` computes the ordered step list from user settings. Each step is a small SwiftUI view that takes a draft binding and renders its single question. A new data layer (`BodyEmotionMap`, `UserBodyMap`, `LearnedBodyMap`) drives suggestions on the picker step. Two new Settings sub-screens expose flow composition and the body→core override editor.

**Tech Stack:** SwiftUI 5+, SwiftData, XCTest, xcodegen, iOS 26 deployment target. No new dependencies.

**Spec:** `docs/superpowers/specs/2026-05-08-checkin-wizard-redesign-design.md`

**Branch:** `checkin-wizard-redesign-v2` (create at start; merge to main and run `./scripts/release.sh` at end).

**Test command (use everywhere "Run tests" appears):**
```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -30
```

**Build command (use everywhere "Run build" appears):**
```bash
xcodegen generate && \
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -10
```

**Project regeneration:** xcodegen sweeps `OpenFeelings/**/*.swift` and `OpenFeelingsTests/**/*.swift`. Run `xcodegen generate` after creating new files. The plan reminds you at each new-file task.

**Branch setup (do this before Task 1):**
```bash
git checkout -b checkin-wizard-redesign-v2
```

---

## Phase 1 — Data layer

### Task 1: Add `BodyRegion.nowhere` case

**Files:**
- Modify: `OpenFeelings/Models/BodyTaxonomy.swift`
- Modify: `OpenFeelingsTests/BodyTaxonomyTests.swift`

- [ ] **Step 1: Write failing tests for `nowhere`**

Append to `OpenFeelingsTests/BodyTaxonomyTests.swift`, inside the existing class:

```swift
    // MARK: - Nowhere region

    func testNowhereCaseExists() {
        XCTAssertEqual(BodyRegion.nowhere.rawValue, "nowhere")
    }

    func testNowhereDisplayName() {
        XCTAssertEqual(BodyRegion.nowhere.displayName, "Nowhere")
    }

    func testNowhereInAllCases() {
        XCTAssertTrue(BodyRegion.allCases.contains(.nowhere))
    }

    func testNowhereRoundTrip() {
        let raw = BodyRegion.encodeList([.nowhere])
        XCTAssertEqual(BodyRegion.parseList(raw), [.nowhere])
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run tests. Expected: `BodyRegion.nowhere` does not exist — compile error.

- [ ] **Step 3: Add the case**

In `OpenFeelings/Models/BodyTaxonomy.swift`, modify the enum and `displayName`:

```swift
enum BodyRegion: String, CaseIterable, Hashable, Sendable, Identifiable {
    case head, throat, chest, stomach, gut, shoulders, back, hands, legs, wholeBody, nowhere

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .head:      "Head"
        case .throat:    "Throat"
        case .chest:     "Chest"
        case .stomach:   "Stomach"
        case .gut:       "Gut"
        case .shoulders: "Shoulders"
        case .back:      "Back"
        case .hands:     "Hands"
        case .legs:      "Legs"
        case .wholeBody: "Everywhere"
        case .nowhere:   "Nowhere"
        }
    }
    // existing parseList / encodeList unchanged
    ...
}
```

(Note the rename of `wholeBody.displayName` from "Whole body" to "Everywhere" — the spec specifies this.)

- [ ] **Step 4: Run tests to verify they pass**

All `BodyTaxonomyTests` pass. Existing tests keep passing.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Models/BodyTaxonomy.swift OpenFeelingsTests/BodyTaxonomyTests.swift
git commit -m "Add BodyRegion.nowhere for somatic-absence state"
```

---

### Task 2: Curated default body→core mapping

**Files:**
- Create: `OpenFeelings/Models/BodyEmotionMap.swift`
- Create: `OpenFeelingsTests/BodyEmotionMapTests.swift`

- [ ] **Step 1: Write failing test**

Create `OpenFeelingsTests/BodyEmotionMapTests.swift`:

```swift
import XCTest
@testable import OpenFeelings

final class BodyEmotionMapTests: XCTestCase {
    func testHeadDefaults() {
        XCTAssertEqual(Set(BodyEmotionMap.defaultCores(for: .head)),
                       Set(["fearful", "disgusted", "angry"]))
    }

    func testChestDefaults() {
        XCTAssertEqual(Set(BodyEmotionMap.defaultCores(for: .chest)),
                       Set(["angry", "happy", "fearful"]))
    }

    func testWholeBodyDefaults() {
        XCTAssertEqual(Set(BodyEmotionMap.defaultCores(for: .wholeBody)),
                       Set(["happy", "sad", "angry", "fearful", "disgusted"]))
    }

    func testNowhereDefaults() {
        XCTAssertEqual(Set(BodyEmotionMap.defaultCores(for: .nowhere)),
                       Set(["sad"]))
    }

    func testEveryRegionHasNonEmptyDefaults() {
        for region in BodyRegion.allCases {
            XCTAssertFalse(BodyEmotionMap.defaultCores(for: region).isEmpty,
                           "region \(region.rawValue) has empty default cores")
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: `BodyEmotionMap` does not exist.

- [ ] **Step 3: Create `BodyEmotionMap`**

Create `OpenFeelings/Models/BodyEmotionMap.swift`:

```swift
import Foundation

/// Curated mapping from body regions to the emotion cores commonly felt there.
/// Source heuristics: mainstream somatic-emotion literature (Damasio, body
/// maps). Marked as starting heuristics — clinical review pass is on the
/// roadmap before general release.
enum BodyEmotionMap {
    /// Curated defaults table. Returns the EmotionCore IDs for the given region.
    static func defaultCores(for region: BodyRegion) -> [String] {
        switch region {
        case .head:      ["fearful", "disgusted", "angry"]
        case .throat:    ["sad", "fearful"]
        case .chest:     ["angry", "happy", "fearful"]
        case .stomach:   ["fearful", "disgusted", "sad"]
        case .gut:       ["fearful", "disgusted"]
        case .shoulders: ["angry", "sad", "fearful"]
        case .back:      ["angry", "sad"]
        case .hands:     ["angry", "fearful", "happy"]
        case .legs:      ["fearful", "angry", "happy"]
        case .wholeBody: ["happy", "sad", "angry", "fearful", "disgusted"]
        case .nowhere:   ["sad"]
        }
    }
}
```

- [ ] **Step 4: xcodegen + run tests**

```bash
xcodegen generate
```

Then run tests. Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Models/BodyEmotionMap.swift OpenFeelingsTests/BodyEmotionMapTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add curated body→emotion default mapping"
```

---

### Task 3: Intersection narrowing in BodyEmotionMap

**Files:**
- Modify: `OpenFeelings/Models/BodyEmotionMap.swift`
- Modify: `OpenFeelingsTests/BodyEmotionMapTests.swift`

- [ ] **Step 1: Append failing tests**

Add to `BodyEmotionMapTests`:

```swift
    // MARK: - suggestedCores narrowing

    func testSingleRegionReturnsItsDefaults() {
        let s = BodyEmotionMap.suggestedCores(for: [.chest], overrides: nil)
        XCTAssertEqual(s, Set(["angry", "happy", "fearful"]))
    }

    func testIntersectionNarrowing() {
        // Stomach: {fearful, disgusted, sad}; Legs: {fearful, angry, happy}.
        // Intersection: {fearful}.
        let s = BodyEmotionMap.suggestedCores(for: [.stomach, .legs], overrides: nil)
        XCTAssertEqual(s, Set(["fearful"]))
    }

    func testEmptyIntersectionFallsBackToUnion() {
        // Throat: {sad, fearful}; Disgusted-only region pair would give empty.
        // Use Back ({angry, sad}) + Disgusted-heavy: Gut ({fearful, disgusted}).
        // Intersection: empty → fallback to union.
        let s = BodyEmotionMap.suggestedCores(for: [.back, .gut], overrides: nil)
        XCTAssertEqual(s, Set(["angry", "sad", "fearful", "disgusted"]))
    }

    func testEmptyRegionsReturnsEmptySet() {
        let s = BodyEmotionMap.suggestedCores(for: [], overrides: nil)
        XCTAssertEqual(s, [])
    }

    func testEverywhereDoesNotNarrow() {
        // wholeBody returns all 5 cores so intersection with anything ⊇ all.
        let s = BodyEmotionMap.suggestedCores(for: [.wholeBody], overrides: nil)
        XCTAssertEqual(s, Set(["happy", "sad", "angry", "fearful", "disgusted"]))
    }

    func testNowhereSuggestsSadOnly() {
        // Nowhere alone → just Sad. UI is responsible for "no dimming"
        // styling; the function returns the suggestion set faithfully.
        let s = BodyEmotionMap.suggestedCores(for: [.nowhere], overrides: nil)
        XCTAssertEqual(s, Set(["sad"]))
    }
```

- [ ] **Step 2: Run tests, verify they fail**

`suggestedCores` is undefined.

- [ ] **Step 3: Implement `suggestedCores`**

Append to `OpenFeelings/Models/BodyEmotionMap.swift` inside the enum:

```swift
    /// Resolves the effective suggested cores for a set of regions.
    ///
    /// Intersection narrowing: starts with each region's mapping, intersects
    /// across all regions. If the intersection is empty (regions disagree),
    /// falls back to the union so the user always sees some highlight.
    ///
    /// `overrides` will be wired in once `UserBodyMap` exists; for now this
    /// signature accepts an `Any?` placeholder via `nil` callers.
    static func suggestedCores(
        for regions: Set<BodyRegion>,
        overrides: UserBodyMap?
    ) -> Set<String> {
        guard !regions.isEmpty else { return [] }

        let perRegionSets = regions.map { region -> Set<String> in
            Set(defaultCores(for: region))
        }

        // Intersect across all regions.
        let intersection = perRegionSets.dropFirst().reduce(perRegionSets.first ?? []) { acc, next in
            acc.intersection(next)
        }
        if !intersection.isEmpty {
            return intersection
        }
        // Fallback: union when intersection is empty.
        return perRegionSets.reduce(Set<String>()) { $0.union($1) }
    }
```

The `overrides: UserBodyMap?` parameter is plumbed through but unused in this task. Task 5 wires the override layer.

- [ ] **Step 4: Stub `UserBodyMap` so this compiles**

Create a minimal `OpenFeelings/Models/UserBodyMap.swift`:

```swift
import Foundation

/// Placeholder for Task 4 — the full SwiftData model arrives there. Defining
/// the type here so `BodyEmotionMap.suggestedCores`'s signature compiles before
/// Task 4 lands.
final class UserBodyMap {
    init() {}
}
```

Run xcodegen.

```bash
xcodegen generate
```

- [ ] **Step 5: Run tests + commit**

Expected: all `BodyEmotionMapTests` pass.

```bash
git add OpenFeelings/Models/BodyEmotionMap.swift OpenFeelings/Models/UserBodyMap.swift OpenFeelingsTests/BodyEmotionMapTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add intersection narrowing to BodyEmotionMap.suggestedCores"
```

---

### Task 4: `UserBodyMap` SwiftData model with override entries

**Files:**
- Modify: `OpenFeelings/Models/UserBodyMap.swift` (replace stub from Task 3)
- Create: `OpenFeelingsTests/UserBodyMapTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/UserBodyMapTests.swift`:

```swift
import XCTest
import SwiftData
@testable import OpenFeelings

final class UserBodyMapTests: XCTestCase {
    func testEmptyMapHasNoOverrides() {
        let map = UserBodyMap()
        XCTAssertNil(map.coreIDs(for: .chest))
    }

    func testWriteAndReadOverride() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["fearful"])
        XCTAssertEqual(map.coreIDs(for: .chest), ["fearful"])
    }

    func testOverwriteOverride() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["fearful"])
        map.setOverride(for: .chest, coreIDs: ["angry", "fearful"])
        XCTAssertEqual(Set(map.coreIDs(for: .chest) ?? []), Set(["angry", "fearful"]))
    }

    func testClearOverride() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["fearful"])
        map.clearOverride(for: .chest)
        XCTAssertNil(map.coreIDs(for: .chest))
    }

    func testResetClearsAll() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["fearful"])
        map.setOverride(for: .hands, coreIDs: ["angry"])
        map.resetAll()
        XCTAssertNil(map.coreIDs(for: .chest))
        XCTAssertNil(map.coreIDs(for: .hands))
    }

    func testEntryCodableRoundTrip() throws {
        let entry = UserBodyMapEntry(regionRaw: "chest", coreIDs: ["fearful", "angry"])
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(UserBodyMapEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }
}
```

- [ ] **Step 2: Run, verify failure**

Tests fail — `UserBodyMap` from Task 3 is a placeholder, lacks methods.

- [ ] **Step 3: Replace `UserBodyMap` with the SwiftData model**

Replace `OpenFeelings/Models/UserBodyMap.swift` entirely:

```swift
import Foundation
import SwiftData

/// One Codable row of user-overridden body→core mapping.
struct UserBodyMapEntry: Codable, Hashable, Sendable {
    let regionRaw: String      // BodyRegion.rawValue
    let coreIDs: [String]      // EmotionCore.id values, 1+
}

/// A user's explicit overrides of the curated body→core map. Stored as a
/// SwiftData `@Model` so changes sync via CloudKit alongside `FeelingLog`
/// and `Intention`. Single instance per user (matching the singleton-record
/// pattern used elsewhere).
@Model
final class UserBodyMap {
    /// Encoded entries. Stored as a serialized JSON String because SwiftData
    /// + CloudKit doesn't accept `[Codable]` directly.
    var entriesRaw: String = "[]"

    init() {}

    /// Decoded view. Recomputed each access; writes go through `setOverride`.
    var entries: [UserBodyMapEntry] {
        get {
            guard let data = entriesRaw.data(using: .utf8),
                  let list = try? JSONDecoder().decode([UserBodyMapEntry].self, from: data) else {
                return []
            }
            return list
        }
        set {
            let data = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
            entriesRaw = String(data: data, encoding: .utf8) ?? "[]"
        }
    }

    func coreIDs(for region: BodyRegion) -> [String]? {
        entries.first(where: { $0.regionRaw == region.rawValue })?.coreIDs
    }

    func setOverride(for region: BodyRegion, coreIDs: [String]) {
        var current = entries.filter { $0.regionRaw != region.rawValue }
        current.append(UserBodyMapEntry(regionRaw: region.rawValue, coreIDs: coreIDs))
        entries = current
    }

    func clearOverride(for region: BodyRegion) {
        entries = entries.filter { $0.regionRaw != region.rawValue }
    }

    func resetAll() {
        entries = []
    }
}
```

- [ ] **Step 4: Run tests + xcodegen**

```bash
xcodegen generate
```

Run tests. All `UserBodyMapTests` pass.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Models/UserBodyMap.swift OpenFeelingsTests/UserBodyMapTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add UserBodyMap SwiftData model for body→core overrides"
```

---

### Task 5: Override layer in `BodyEmotionMap.suggestedCores`

**Files:**
- Modify: `OpenFeelings/Models/BodyEmotionMap.swift`
- Modify: `OpenFeelingsTests/BodyEmotionMapTests.swift`

- [ ] **Step 1: Append failing tests**

Add to `BodyEmotionMapTests`:

```swift
    // MARK: - Override layer

    func testOverrideReplacesDefaultForOneRegion() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["sad"])
        let s = BodyEmotionMap.suggestedCores(for: [.chest], overrides: map)
        XCTAssertEqual(s, Set(["sad"]))
    }

    func testOverrideAffectsIntersection() {
        // Default chest: {angry, happy, fearful}. Override to {sad}.
        // Combine with legs ({fearful, angry, happy}): intersection is empty,
        // falls back to union of {sad} ∪ {fearful, angry, happy}.
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["sad"])
        let s = BodyEmotionMap.suggestedCores(for: [.chest, .legs], overrides: map)
        XCTAssertEqual(s, Set(["sad", "fearful", "angry", "happy"]))
    }

    func testNonOverriddenRegionUsesDefault() {
        let map = UserBodyMap()
        map.setOverride(for: .hands, coreIDs: ["sad"])
        // Chest is not overridden.
        let s = BodyEmotionMap.suggestedCores(for: [.chest], overrides: map)
        XCTAssertEqual(s, Set(["angry", "happy", "fearful"]))
    }
```

- [ ] **Step 2: Run, verify failures**

The override path is not yet honored.

- [ ] **Step 3: Wire overrides**

Modify `suggestedCores` body in `BodyEmotionMap.swift`:

```swift
    static func suggestedCores(
        for regions: Set<BodyRegion>,
        overrides: UserBodyMap?
    ) -> Set<String> {
        guard !regions.isEmpty else { return [] }

        let perRegionSets = regions.map { region -> Set<String> in
            if let overridden = overrides?.coreIDs(for: region), !overridden.isEmpty {
                return Set(overridden)
            }
            return Set(defaultCores(for: region))
        }

        let intersection = perRegionSets.dropFirst().reduce(perRegionSets.first ?? []) { acc, next in
            acc.intersection(next)
        }
        if !intersection.isEmpty {
            return intersection
        }
        return perRegionSets.reduce(Set<String>()) { $0.union($1) }
    }
```

- [ ] **Step 4: Run tests**

All `BodyEmotionMapTests` pass.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Models/BodyEmotionMap.swift OpenFeelingsTests/BodyEmotionMapTests.swift
git commit -m "Honor UserBodyMap overrides in BodyEmotionMap.suggestedCores"
```

---

### Task 6: `LearnedBodyMap` with `dominantSecondary`

**Files:**
- Create: `OpenFeelings/Models/LearnedBodyMap.swift`
- Create: `OpenFeelingsTests/LearnedBodyMapTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/LearnedBodyMapTests.swift`:

```swift
import XCTest
@testable import OpenFeelings

final class LearnedBodyMapTests: XCTestCase {
    private func selection(_ secondary: String) -> EmotionSelection {
        // Use a synthetic selection — we only need `secondary.id` and
        // `core.id` to compute LearnedBodyMap.
        let core = EmotionTaxonomy.cores.first { $0.id == "fearful" }!
        let sec = core.secondaries.first(where: { $0.id == secondary }) ?? core.secondaries[0]
        return EmotionSelection(core: core, secondary: sec, specific: nil)
    }

    private func log(secondary: String, regions: [BodyRegion]) -> FeelingLog {
        let sel = selection(secondary)
        return FeelingLog(
            selection: sel,
            intensity: nil,
            note: "",
            healthSyncStatus: .notRequested,
            bodyRegions: regions,
            bodySensations: [],
            contextPlaces: [],
            contextPeople: [],
            triggers: [],
            coping: [],
            moodEnergy: nil,
            moodValence: nil
        )
    }

    func testEmptyLogsHasNoDominant() {
        let map = LearnedBodyMap.compute(from: [])
        XCTAssertNil(map.dominantSecondary(for: .chest))
    }

    func testDominantBelowSampleThresholdReturnsNil() {
        // Need ≥5 samples. 4 with same secondary should still return nil.
        let logs = (0..<4).map { _ in log(secondary: "anxious", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertNil(map.dominantSecondary(for: .chest))
    }

    func testDominantBelowRatioThresholdReturnsNil() {
        // 5 samples, 50/50 split — neither dominant.
        let logs = (0..<3).map { _ in log(secondary: "anxious", regions: [.chest]) }
                  + (0..<3).map { _ in log(secondary: "worried", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertNil(map.dominantSecondary(for: .chest))
    }

    func testDominantAtThreshold() {
        // 5 samples, 4 anxious (80%) — exceeds 60% and meets sample threshold.
        let logs = (0..<4).map { _ in log(secondary: "anxious", regions: [.chest]) }
                  + (0..<1).map { _ in log(secondary: "worried", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertEqual(map.dominantSecondary(for: .chest), "anxious")
    }

    func testRegionWithoutLogsIsNil() {
        let logs = (0..<5).map { _ in log(secondary: "anxious", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertNil(map.dominantSecondary(for: .hands))
    }

    func testCountAndTotalAreExposed() {
        let logs = (0..<6).map { _ in log(secondary: "anxious", regions: [.chest]) }
                  + (0..<2).map { _ in log(secondary: "worried", regions: [.chest]) }
        let map = LearnedBodyMap.compute(from: logs)
        XCTAssertEqual(map.totals[.chest], 8)
        XCTAssertEqual(map.counts[.chest]?["anxious"], 6)
    }
}
```

- [ ] **Step 2: Run, verify failures**

`LearnedBodyMap` does not exist.

- [ ] **Step 3: Implement `LearnedBodyMap`**

Create `OpenFeelings/Models/LearnedBodyMap.swift`:

```swift
import Foundation

/// Aggregated counts of secondary-emotion picks per body region, computed on
/// demand from `[FeelingLog]`. Not persisted — recomputed at the start of a
/// check-in session and cached for that session's lifetime.
struct LearnedBodyMap: Sendable {
    /// `[region: [secondary: count]]`
    let counts: [BodyRegion: [String: Int]]
    /// `[region: total log count where this region was picked]`
    let totals: [BodyRegion: Int]

    /// Threshold: ≥60% of region-tagged logs share this secondary AND
    /// ≥5 region-tagged samples. Returns nil when below either threshold.
    func dominantSecondary(for region: BodyRegion) -> String? {
        guard let total = totals[region], total >= 5 else { return nil }
        guard let perSecondary = counts[region] else { return nil }

        for (secondary, count) in perSecondary {
            let ratio = Double(count) / Double(total)
            if ratio >= 0.6 {
                return secondary
            }
        }
        return nil
    }

    static func compute(from logs: [FeelingLog]) -> LearnedBodyMap {
        var counts: [BodyRegion: [String: Int]] = [:]
        var totals: [BodyRegion: Int] = [:]

        for log in logs {
            let regions = log.bodyRegionsList
            let secondaryID = log.secondaryID
            guard !secondaryID.isEmpty else { continue }
            for region in regions {
                totals[region, default: 0] += 1
                var perSecondary = counts[region] ?? [:]
                perSecondary[secondaryID, default: 0] += 1
                counts[region] = perSecondary
            }
        }

        return LearnedBodyMap(counts: counts, totals: totals)
    }
}
```

- [ ] **Step 4: Run tests + xcodegen**

```bash
xcodegen generate
```

Tests should pass. If `FeelingLog.bodyRegionsList` or `secondaryID` doesn't exist with that name, find the equivalent property by reading `OpenFeelings/Models/FeelingLog.swift` and adjust the `for log in logs` loop accordingly.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Models/LearnedBodyMap.swift OpenFeelingsTests/LearnedBodyMapTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add LearnedBodyMap with dominant-secondary detection"
```

---

## Phase 2 — Flow engine

### Task 7: `CheckInStepKind` enum + step keys

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/CheckInStepKind.swift`
- Create: `OpenFeelingsTests/CheckInStepKindTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/CheckInStepKindTests.swift`:

```swift
import XCTest
@testable import OpenFeelings

final class CheckInStepKindTests: XCTestCase {
    func testAllKindsHaveStorageKey() {
        for kind in CheckInStepKind.allCases {
            XCTAssertFalse(kind.storageKey.isEmpty, "kind \(kind) missing storageKey")
        }
    }

    func testStorageKeysAreUnique() {
        let keys = CheckInStepKind.allCases.map(\.storageKey)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testParseListIgnoresUnknownTokens() {
        XCTAssertEqual(CheckInStepKind.parseList("strength,not-a-thing,context"),
                       [.strength, .context])
    }

    func testEncodeListRoundTrip() {
        let all: [CheckInStepKind] = [.strength, .sensations, .mood]
        let raw = CheckInStepKind.encodeList(all)
        XCTAssertEqual(CheckInStepKind.parseList(raw), all)
    }
}
```

- [ ] **Step 2: Run, fail**

- [ ] **Step 3: Create the enum**

Create `OpenFeelings/Views/CheckInWizard/CheckInStepKind.swift`:

```swift
import Foundation

/// One step in the Check In wizard. Order is fixed — see `CheckInFlowEngine`
/// for which kinds are included for a given user setting.
///
/// `body`, `feeling`, `reflect` are structural (always-or-required). The
/// rest are optional dimensions that can be promoted from "More detail"
/// to first-class steps via Settings → Check In flow.
enum CheckInStepKind: String, CaseIterable, Identifiable, Sendable {
    case body
    case feeling
    case strength
    case sensations
    case context
    case triggers
    case coping
    case mood
    case reflect

    var id: String { rawValue }

    /// Stable key used in the `checkInPromotedSteps` AppStorage CSV.
    var storageKey: String { rawValue }

    /// Whether the user can promote this kind to a first-class step.
    /// `body` is gated on `checkInBodyFirst`; the rest of the structural
    /// kinds are not user-configurable.
    var isPromotable: Bool {
        switch self {
        case .sensations, .context, .triggers, .coping, .mood, .strength:
            true
        case .body, .feeling, .reflect:
            false
        }
    }

    /// Parse a CSV of step keys into a typed list, dropping unknown tokens.
    static func parseList(_ raw: String) -> [CheckInStepKind] {
        raw.split(separator: ",").compactMap { CheckInStepKind(rawValue: String($0)) }
    }

    /// Encode a typed list back to CSV.
    static func encodeList(_ kinds: [CheckInStepKind]) -> String {
        kinds.map(\.storageKey).joined(separator: ",")
    }
}
```

- [ ] **Step 4: xcodegen + run tests**

```bash
xcodegen generate
```

Tests pass.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Views/CheckInWizard/CheckInStepKind.swift OpenFeelingsTests/CheckInStepKindTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add CheckInStepKind enum with promote/parse helpers"
```

---

### Task 8: `CheckInFlowEngine`

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/CheckInFlowEngine.swift`
- Create: `OpenFeelingsTests/CheckInFlowEngineTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/CheckInFlowEngineTests.swift`:

```swift
import XCTest
@testable import OpenFeelings

final class CheckInFlowEngineTests: XCTestCase {
    func testBodyFirstOnDefaultPromotedSteps() {
        // Default: only `strength` is promoted.
        let steps = CheckInFlowEngine.steps(
            bodyFirst: true,
            promotedSteps: [.strength]
        )
        XCTAssertEqual(steps, [.body, .feeling, .strength, .reflect])
    }

    func testBodyFirstOffDefaultPromotedSteps() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: false,
            promotedSteps: [.strength]
        )
        XCTAssertEqual(steps, [.feeling, .strength, .reflect])
    }

    func testEmptyPromotedSteps() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: true,
            promotedSteps: []
        )
        XCTAssertEqual(steps, [.body, .feeling, .reflect])
    }

    func testAllOptionalStepsPromoted() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: true,
            promotedSteps: [.sensations, .strength, .context, .triggers, .coping, .mood]
        )
        // Body → Sensations → Feeling → Context → Triggers → Coping → Strength → Mood → Reflect
        // Sensations land between Body and Feeling; the rest land between Feeling and Reflect.
        XCTAssertEqual(steps, [.body, .sensations, .feeling, .context, .triggers, .coping, .strength, .mood, .reflect])
    }

    func testReflectIsAlwaysLast() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: true,
            promotedSteps: [.context, .triggers, .coping, .mood]
        )
        XCTAssertEqual(steps.last, .reflect)
    }

    func testFeelingIsAlwaysPresent() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: false,
            promotedSteps: []
        )
        XCTAssertTrue(steps.contains(.feeling))
    }
}
```

- [ ] **Step 2: Run, fail**

- [ ] **Step 3: Implement the engine**

Create `OpenFeelings/Views/CheckInWizard/CheckInFlowEngine.swift`:

```swift
import Foundation

/// Pure value-type that decides the ordered list of `CheckInStepKind` for a
/// given user configuration. No I/O, no global state — fully testable.
enum CheckInFlowEngine {
    /// Returns the ordered list of steps the wizard renders.
    ///
    /// Layout rules:
    /// - `body` first (only when `bodyFirst` is true).
    /// - `sensations` is the only promoted kind that lands between `body` and
    ///   `feeling` — it has no meaning without regions to attach to.
    /// - `feeling` is always present.
    /// - The remaining promoted kinds (context, triggers, coping, strength, mood)
    ///   land between `feeling` and `reflect`, in that fixed order regardless of
    ///   the order they appear in `promotedSteps`.
    /// - `reflect` is always last.
    static func steps(bodyFirst: Bool, promotedSteps: Set<CheckInStepKind>) -> [CheckInStepKind] {
        var result: [CheckInStepKind] = []

        if bodyFirst {
            result.append(.body)
            if promotedSteps.contains(.sensations) {
                result.append(.sensations)
            }
        }

        result.append(.feeling)

        for kind in [CheckInStepKind.context, .triggers, .coping, .strength, .mood] {
            if promotedSteps.contains(kind) {
                result.append(kind)
            }
        }

        result.append(.reflect)
        return result
    }
}
```

- [ ] **Step 4: xcodegen + run tests**

```bash
xcodegen generate
```

Tests pass. (Note: the test that checks "sensations between body and feeling" expects the order shown in `testAllOptionalStepsPromoted`. If your implementation produces a different valid order, prefer the test's expectation — it's the spec.)

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Views/CheckInWizard/CheckInFlowEngine.swift OpenFeelingsTests/CheckInFlowEngineTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add CheckInFlowEngine for adaptive step composition"
```

---

## Phase 3 — UI components

### Task 9: Chrome (StepProgressBar, StepHeader, StepNav)

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Components/StepProgressBar.swift`
- Create: `OpenFeelings/Views/CheckInWizard/Components/StepHeader.swift`
- Create: `OpenFeelings/Views/CheckInWizard/Components/StepNav.swift`

These are pure-render UI; no TDD. Visual smoke check at the end.

- [ ] **Step 1: Create StepProgressBar**

`OpenFeelings/Views/CheckInWizard/Components/StepProgressBar.swift`:

```swift
import SwiftUI

/// Capsule progress indicator. Renders `total` capsules; the first
/// `currentIndex + 1` are filled with the accent color.
struct StepProgressBar: View {
    let currentIndex: Int
    let total: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i <= currentIndex
                          ? AnyShapeStyle(Color.OF.accent)
                          : AnyShapeStyle(Color.OF.divider))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}
```

- [ ] **Step 2: Create StepHeader**

`OpenFeelings/Views/CheckInWizard/Components/StepHeader.swift`:

```swift
import SwiftUI

/// Title + subtitle + optional selected-feeling badge above each step.
struct StepHeader: View {
    let stepIndex: Int
    let totalSteps: Int
    let title: String
    let subtitle: String
    let selectedFeeling: EmotionSelection?
    let intensity: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            StepProgressBar(currentIndex: stepIndex, total: totalSteps)
            Text("Step \(stepIndex + 1) of \(totalSteps)")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
                .padding(.top, .OF.xs)
            Text(title)
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
            Text(subtitle)
                .font(.OF.body)
                .foregroundStyle(Color.OF.textMuted)
            if let selectedFeeling {
                SelectedFeelingBadge(selection: selectedFeeling, intensity: intensity)
            }
        }
        .padding(.top, .OF.lg)
    }
}
```

- [ ] **Step 3: Create StepNav**

`OpenFeelings/Views/CheckInWizard/Components/StepNav.swift`:

```swift
import SwiftUI

/// Bottom navigation buttons for a step. Configures Back / Skip / Continue
/// or Save based on the step's position in the flow.
struct StepNav: View {
    let canGoBack: Bool
    let canSkip: Bool
    let canAdvance: Bool
    let isFinalStep: Bool
    let onBack: () -> Void
    let onSkip: () -> Void
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: .OF.md) {
            if canGoBack {
                OFButton("Back", style: .ghost, action: onBack)
            } else if canSkip {
                OFButton("Skip", style: .ghost, action: onSkip)
            }
            OFButton(isFinalStep ? "Save check-in" : "Continue", style: .primary, action: onAdvance)
                .opacity(canAdvance ? 1 : 0.4)
                .disabled(!canAdvance)
        }
    }
}
```

Note: this composition shows Back when `canGoBack` is true, otherwise Skip when `canSkip`. The orchestrator decides which is true per step (Back exists from step 2 onward; Skip exists when the step is non-required).

- [ ] **Step 4: xcodegen + build**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED. (StepHeader references `SelectedFeelingBadge` which lands in Task 10; if you build mid-task, comment out the badge line temporarily, or do Task 10 first then come back. To minimize churn, advance to Task 10 next without committing this task individually — the four components ship as one logical unit.)

- [ ] **Step 5: Defer commit**

Skip commit; proceed to Task 10 and ship the chrome + supporting components together.

---

### Task 10: SelectedFeelingBadge, MoreDetailDisclosure, PersonalizationNudge

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Components/SelectedFeelingBadge.swift`
- Create: `OpenFeelings/Views/CheckInWizard/Components/MoreDetailDisclosure.swift`
- Create: `OpenFeelings/Views/CheckInWizard/Components/PersonalizationNudge.swift`

- [ ] **Step 1: Create SelectedFeelingBadge**

`OpenFeelings/Views/CheckInWizard/Components/SelectedFeelingBadge.swift`:

```swift
import SwiftUI

/// Soft pill showing the user's chosen feeling (and intensity, if set).
struct SelectedFeelingBadge: View {
    let selection: EmotionSelection
    let intensity: Int?

    var body: some View {
        HStack(spacing: .OF.sm) {
            Circle()
                .fill(Color.OF.core(selection.core.id))
                .frame(width: 12, height: 12)
            Text(selection.title)
                .font(.OF.bodyEmphasis)
                .foregroundStyle(Color.OF.text)
            if let intensity {
                Text("·").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Text("\(intensity)").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            }
            if !selection.pathTitle.isEmpty {
                Text("·").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Text(selection.pathTitle)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, .OF.xs)
        .padding(.horizontal, .OF.md)
        .background(Color.OF.surface, in: Capsule())
        .overlay(Capsule().stroke(Color.OF.divider, lineWidth: 1))
    }
}
```

- [ ] **Step 2: Create MoreDetailDisclosure**

`OpenFeelings/Views/CheckInWizard/Components/MoreDetailDisclosure.swift`:

```swift
import SwiftUI

/// Collapsible "+ More detail" container. Holds a stack of optional cards;
/// they remain hidden until the user taps the disclosure header.
struct MoreDetailDisclosure<Content: View>: View {
    @State private var isExpanded = false
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            Button {
                withAnimation(.OF.gentle) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(isExpanded ? "− More detail" : "+ More detail")
                        .font(.OF.bodyEmphasis)
                        .foregroundStyle(Color.OF.text)
                    Spacer()
                }
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                            .stroke(Color.OF.divider, style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            }
            .buttonStyle(.plain)

            if isExpanded {
                content()
            }
        }
    }
}
```

- [ ] **Step 3: Create PersonalizationNudge**

`OpenFeelings/Views/CheckInWizard/Components/PersonalizationNudge.swift`:

```swift
import SwiftUI

/// Soft accent card shown on the Feeling step when the app spots a strong
/// personal pattern in the user's body→secondary history.
struct PersonalizationNudge: View {
    let region: BodyRegion
    let secondaryName: String
    let count: Int
    let total: Int
    let onSave: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            (
                Text("You've picked ")
                    .foregroundStyle(Color.OF.text)
                + Text(secondaryName).bold().foregroundStyle(Color.OF.text)
                + Text(" \(count) of \(total) times for ")
                    .foregroundStyle(Color.OF.text)
                + Text(region.displayName).bold().foregroundStyle(Color.OF.text)
                + Text(". Save as your default?")
                    .foregroundStyle(Color.OF.text)
            )
            .font(.OF.body)
            .multilineTextAlignment(.leading)

            HStack(spacing: .OF.sm) {
                OFButton("Not now", style: .ghost, action: onDismiss)
                OFButton("Save", style: .primary, action: onSave)
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.accentSoft,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }
}
```

- [ ] **Step 4: xcodegen + build**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit (covers Task 9 + 10)**

```bash
git add OpenFeelings/Views/CheckInWizard/Components OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add wizard chrome and supporting components"
```

---

### Task 11: BodySilhouetteView (opt-in body view)

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Components/BodySilhouetteView.swift`

Pure UI; no TDD.

- [ ] **Step 1: Create the silhouette view**

`OpenFeelings/Views/CheckInWizard/Components/BodySilhouetteView.swift`:

```swift
import SwiftUI

/// Tappable silhouette of a person. Each region maps to a tap zone overlay;
/// active regions are filled with the accent color. "Back" is not on the
/// silhouette — the parent renders it as a chip below.
struct BodySilhouetteView: View {
    @Binding var selectedRegions: Set<BodyRegion>

    private struct Zone {
        let region: BodyRegion
        let frame: CGRect      // in normalized space (0...1)
    }

    private let zones: [Zone] = [
        Zone(region: .head,      frame: CGRect(x: 0.40, y: 0.04, width: 0.20, height: 0.13)),
        Zone(region: .throat,    frame: CGRect(x: 0.45, y: 0.18, width: 0.10, height: 0.04)),
        Zone(region: .chest,     frame: CGRect(x: 0.30, y: 0.23, width: 0.40, height: 0.14)),
        Zone(region: .stomach,   frame: CGRect(x: 0.32, y: 0.38, width: 0.36, height: 0.08)),
        Zone(region: .gut,       frame: CGRect(x: 0.32, y: 0.46, width: 0.36, height: 0.08)),
        Zone(region: .shoulders, frame: CGRect(x: 0.20, y: 0.21, width: 0.60, height: 0.04)),
        Zone(region: .hands,     frame: CGRect(x: 0.04, y: 0.55, width: 0.16, height: 0.10)),
        Zone(region: .legs,      frame: CGRect(x: 0.30, y: 0.66, width: 0.40, height: 0.30))
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                outline(in: geo.size)

                ForEach(zones, id: \.region) { zone in
                    let rect = denormalize(zone.frame, in: geo.size)
                    let isOn = selectedRegions.contains(zone.region)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isOn ? Color.OF.accent.color(for: .light).opacity(0.5)
                                   : Color.OF.accentSoft.opacity(0.0))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isOn ? Color.OF.accent.color(for: .light)
                                             : Color.OF.divider,
                                        style: StrokeStyle(lineWidth: 1,
                                                           dash: isOn ? [] : [3, 3]))
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel(zone.region.displayName)
                        .accessibilityAddTraits(.isButton)
                        .onTapGesture { toggle(zone.region) }
                }
            }
        }
        .frame(height: 320)
    }

    private func outline(in size: CGSize) -> some View {
        Path { p in
            // Head
            let head = CGRect(x: size.width * 0.40, y: size.height * 0.04,
                              width: size.width * 0.20, height: size.width * 0.20)
            p.addEllipse(in: head)
            // Neck
            p.move(to: CGPoint(x: size.width * 0.50, y: size.height * 0.18))
            p.addLine(to: CGPoint(x: size.width * 0.50, y: size.height * 0.21))
            // Shoulders
            p.move(to: CGPoint(x: size.width * 0.20, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.80, y: size.height * 0.22))
            // Torso
            p.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.22, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.78, y: size.height * 0.22))
            // Arms
            p.move(to: CGPoint(x: size.width * 0.22, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.10, y: size.height * 0.60))
            p.move(to: CGPoint(x: size.width * 0.78, y: size.height * 0.22))
            p.addLine(to: CGPoint(x: size.width * 0.90, y: size.height * 0.60))
            // Legs
            p.move(to: CGPoint(x: size.width * 0.36, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.36, y: size.height * 0.96))
            p.move(to: CGPoint(x: size.width * 0.64, y: size.height * 0.66))
            p.addLine(to: CGPoint(x: size.width * 0.64, y: size.height * 0.96))
        }
        .stroke(Color.OF.textMuted, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }

    private func denormalize(_ rect: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.minX * size.width,
            y: rect.minY * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    private func toggle(_ region: BodyRegion) {
        if selectedRegions.contains(region) {
            selectedRegions.remove(region)
        } else {
            selectedRegions.insert(region)
        }
    }
}
```

- [ ] **Step 2: xcodegen + build**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add OpenFeelings/Views/CheckInWizard/Components/BodySilhouetteView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add BodySilhouetteView for the optional silhouette body view"
```

---

## Phase 4 — Step views

A shared `CheckInDraft` value type holds all in-flight wizard state. Each step view receives a binding to the draft + the global flow context.

### Task 12: `CheckInDraft` value type

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/CheckInDraft.swift`
- Create: `OpenFeelingsTests/CheckInDraftTests.swift`

- [ ] **Step 1: Write failing tests**

Create `OpenFeelingsTests/CheckInDraftTests.swift`:

```swift
import XCTest
@testable import OpenFeelings

final class CheckInDraftTests: XCTestCase {
    func testEmptyDraftCannotSave() {
        XCTAssertFalse(CheckInDraft().canSave)
    }

    func testCompleteSelectionEnablesSave() {
        let core = EmotionTaxonomy.cores[0]
        let sec = core.secondaries[0]
        var draft = CheckInDraft()
        draft.selection = EmotionSelection(core: core, secondary: sec, specific: nil)
        XCTAssertTrue(draft.canSave)
    }

    func testResetClearsEverything() {
        var draft = CheckInDraft()
        draft.note = "Hello"
        draft.includeIntensity = true
        draft.intensity = 4
        draft.bodyRegions = [.chest]
        draft.reset()
        XCTAssertEqual(draft.note, "")
        XCTAssertFalse(draft.includeIntensity)
        XCTAssertEqual(draft.intensity, 3)
        XCTAssertTrue(draft.bodyRegions.isEmpty)
    }

    func testEverywhereExclusivity() {
        var draft = CheckInDraft()
        draft.toggleRegion(.chest)
        draft.toggleRegion(.head)
        XCTAssertEqual(draft.bodyRegions, [.chest, .head])
        draft.toggleRegion(.wholeBody)
        // Picking Everywhere clears all other regions and is now exclusive.
        XCTAssertEqual(draft.bodyRegions, [.wholeBody])
    }

    func testNowhereExclusivity() {
        var draft = CheckInDraft()
        draft.toggleRegion(.chest)
        draft.toggleRegion(.nowhere)
        XCTAssertEqual(draft.bodyRegions, [.nowhere])
    }

    func testPickingNormalRegionClearsEverywhere() {
        var draft = CheckInDraft()
        draft.toggleRegion(.wholeBody)
        draft.toggleRegion(.chest)
        XCTAssertEqual(draft.bodyRegions, [.chest])
    }
}
```

- [ ] **Step 2: Run, fail**

- [ ] **Step 3: Create the draft type**

`OpenFeelings/Views/CheckInWizard/CheckInDraft.swift`:

```swift
import Foundation

/// All in-flight check-in state held by the wizard orchestrator. Pure value
/// type — testable without any SwiftUI environment.
struct CheckInDraft {
    var selection: EmotionSelection?
    var note: String = ""
    var includeIntensity: Bool = false
    var intensity: Double = 3
    var includeMoodScale: Bool = false
    var moodEnergy: Double = 0
    var moodValence: Double = 0
    var bodyRegions: Set<BodyRegion> = []
    var bodySensations: Set<BodySensation> = []
    var contextPlaces: Set<ContextPlace> = []
    var contextPeople: Set<ContextPeople> = []
    var triggers: Set<Trigger> = []
    var coping: Set<Coping> = []

    /// Whether the draft has enough state to save (just a complete emotion).
    var canSave: Bool {
        selection?.isComplete == true
    }

    /// Toggles a region with the Everywhere/Nowhere exclusivity rules:
    /// - Picking Everywhere or Nowhere replaces all selections with that one.
    /// - Picking any normal region while Everywhere/Nowhere is selected clears it.
    /// - Picking Everywhere when Nowhere is selected (or vice versa) replaces.
    mutating func toggleRegion(_ region: BodyRegion) {
        let isExclusive = (region == .wholeBody || region == .nowhere)
        let hasExclusive = bodyRegions.contains(.wholeBody) || bodyRegions.contains(.nowhere)

        if isExclusive {
            if bodyRegions == [region] {
                bodyRegions = []
            } else {
                bodyRegions = [region]
            }
            return
        }

        if hasExclusive {
            bodyRegions.remove(.wholeBody)
            bodyRegions.remove(.nowhere)
        }

        if bodyRegions.contains(region) {
            bodyRegions.remove(region)
        } else {
            bodyRegions.insert(region)
        }
    }

    mutating func reset() {
        self = CheckInDraft()
    }
}
```

- [ ] **Step 4: xcodegen + run tests**

```bash
xcodegen generate
```

Tests pass.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Views/CheckInWizard/CheckInDraft.swift OpenFeelingsTests/CheckInDraftTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add CheckInDraft value type with exclusivity rules"
```

---

### Task 13: BodyStep

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Steps/BodyStep.swift`

- [ ] **Step 1: Create the view**

```swift
import SwiftUI

/// "Where do you feel it?" — region chips with Everywhere / Nowhere as
/// italic dashed chips at the front. Optional sensations expand below
/// when at least one specific region is selected, unless Sensations is
/// promoted to its own step (controlled by the orchestrator).
struct BodyStep: View {
    @Binding var draft: CheckInDraft
    @AppStorage("checkInBodyView") private var bodyView: String = "chips"

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            switch bodyView {
            case "silhouette":
                BodySilhouetteView(selectedRegions: bindingForToggle())
                backOrSpecialChips
            default:
                regionChips
            }
        }
    }

    private var regionChips: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                specialChip(.wholeBody, label: "Everywhere")
                specialChip(.nowhere, label: "Nowhere")
                ForEach(regularRegions, id: \.self) { region in
                    OFChip(label: region.displayName, isOn: bindingFor(region))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    /// In silhouette mode, only render Back, Everywhere, Nowhere as chips
    /// (the silhouette covers the rest).
    private var backOrSpecialChips: some View {
        WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
            OFChip(label: "Back", isOn: bindingFor(.back))
            specialChip(.wholeBody, label: "Everywhere")
            specialChip(.nowhere, label: "Nowhere")
        }
    }

    private var regularRegions: [BodyRegion] {
        BodyRegion.allCases.filter { $0 != .wholeBody && $0 != .nowhere }
    }

    @ViewBuilder
    private func specialChip(_ region: BodyRegion, label: String) -> some View {
        Button {
            draft.toggleRegion(region)
        } label: {
            Text(label)
                .font(.OF.caption)
                .italic()
                .padding(.vertical, .OF.xs)
                .padding(.horizontal, .OF.md)
                .background(
                    draft.bodyRegions.contains(region)
                        ? AnyShapeStyle(Color.OF.accent)
                        : AnyShapeStyle(Color.OF.background)
                )
                .foregroundStyle(
                    draft.bodyRegions.contains(region)
                        ? Color.OF.surface
                        : Color.OF.accent
                )
                .overlay(
                    Capsule().stroke(Color.OF.accent,
                                     style: StrokeStyle(lineWidth: 1,
                                                        dash: draft.bodyRegions.contains(region) ? [] : [4, 3]))
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func bindingFor(_ region: BodyRegion) -> Binding<Bool> {
        Binding(
            get: { draft.bodyRegions.contains(region) },
            set: { _ in draft.toggleRegion(region) }
        )
    }

    /// Used by the silhouette view, which manages its own selected set.
    /// We bridge to the draft's exclusivity rules.
    private func bindingForToggle() -> Binding<Set<BodyRegion>> {
        Binding(
            get: { draft.bodyRegions },
            set: { newValue in
                // Find the diff and route through toggleRegion to preserve
                // exclusivity semantics.
                let added = newValue.subtracting(draft.bodyRegions)
                let removed = draft.bodyRegions.subtracting(newValue)
                for region in added { draft.toggleRegion(region) }
                for region in removed { draft.toggleRegion(region) }
            }
        )
    }
}
```

- [ ] **Step 2: xcodegen + build**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add OpenFeelings/Views/CheckInWizard/Steps/BodyStep.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add BodyStep view with chips + silhouette modes"
```

---

### Task 14: FeelingStep with body→core highlighting + nudge

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Steps/FeelingStep.swift`
- Modify: `OpenFeelings/Views/WizardCheckInView.swift` (add `dimmedCoreIDs` parameter)

- [ ] **Step 1: Read WizardCheckInView to understand its current API**

```bash
cat OpenFeelings/Views/WizardCheckInView.swift
```

Identify the core list rendering — that's where dimming applies.

- [ ] **Step 2: Add a `dimmedCoreIDs` initializer parameter to WizardCheckInView**

In `WizardCheckInView.swift`, add a new parameter to the struct:

```swift
struct WizardCheckInView: View {
    @Binding var selection: EmotionSelection?
    /// Cores whose IDs are NOT in this set get rendered at 40% opacity with
    /// a tiny dot below suggested cores. Empty set = no dimming (default).
    var suggestedCoreIDs: Set<String> = []
    // ... rest unchanged
}
```

In the core-row body (find the loop that renders one swatch per core), apply opacity and the dot:

```swift
ForEach(EmotionTaxonomy.cores) { core in
    let isSuggested = suggestedCoreIDs.isEmpty || suggestedCoreIDs.contains(core.id)
    coreSwatch(core)
        .opacity(isSuggested ? 1 : 0.4)
        .overlay(alignment: .bottom) {
            if !suggestedCoreIDs.isEmpty && isSuggested {
                Circle()
                    .fill(Color.OF.accent)
                    .frame(width: 5, height: 5)
                    .offset(y: 6)
            }
        }
}
```

Adapt the `coreSwatch(_:)` reference to whatever the existing rendering looks like — the goal is just opacity + dot. Don't disable interaction; even dimmed cores remain tappable.

- [ ] **Step 3: Create FeelingStep**

`OpenFeelings/Views/CheckInWizard/Steps/FeelingStep.swift`:

```swift
import SwiftData
import SwiftUI

private enum CheckInMode: String, CaseIterable, Identifiable {
    case wizard = "Wizard"
    case wheel  = "Wheel"
    var id: String { rawValue }
}

/// Picker step. Renders the Wizard or Wheel inside a top pill segment.
/// Body→core highlighting comes from `BodyEmotionMap.suggestedCores(...)`
/// (computed in the orchestrator and passed in).
/// Personalization nudge appears when learned dominant secondary exists
/// and no override is in place for the relevant region.
struct FeelingStep: View {
    @Binding var draft: CheckInDraft
    let suggestedCoreIDs: Set<String>
    let nudge: NudgePayload?
    let onSaveOverride: (BodyRegion, String) -> Void
    let onDismissNudge: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("checkInMode") private var modeRawValue = CheckInMode.wizard.rawValue

    /// Inputs needed to render the personalization nudge.
    struct NudgePayload {
        let region: BodyRegion
        let secondaryID: String
        let secondaryName: String
        let count: Int
        let total: Int
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            modeSegmented
            picker
            if let nudge {
                PersonalizationNudge(
                    region: nudge.region,
                    secondaryName: nudge.secondaryName,
                    count: nudge.count,
                    total: nudge.total,
                    onSave: { onSaveOverride(nudge.region, nudge.secondaryID) },
                    onDismiss: onDismissNudge
                )
            }
            if let selection = draft.selection {
                EmotionDefinitionCard(
                    definition: selection.definition,
                    accent: Color.OF.accent.color(for: colorScheme),
                    showsDisclaimer: true
                )
            }
        }
    }

    @ViewBuilder
    private var picker: some View {
        switch mode {
        case .wizard:
            WizardCheckInView(selection: $draft.selection, suggestedCoreIDs: suggestedCoreIDs)
        case .wheel:
            // Wheel-mode body→core highlighting is out of scope for v1.
            WheelCheckInView(selection: $draft.selection)
        }
    }

    private var mode: CheckInMode {
        CheckInMode(rawValue: modeRawValue) ?? .wizard
    }

    private var modeSegmented: some View {
        HStack(spacing: 0) {
            ForEach(CheckInMode.allCases) { m in
                Button {
                    withAnimation(.OF.quick) { modeRawValue = m.rawValue }
                } label: {
                    Text(m.rawValue)
                        .font(.OF.bodyEmphasis)
                        .foregroundStyle(mode == m ? Color.OF.text : Color.OF.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(
                            Group {
                                if mode == m {
                                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip, style: .continuous)
                                        .fill(Color.OF.surface)
                                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.OF.accentSoft.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.chip + 4, style: .continuous))
    }
}
```

- [ ] **Step 4: xcodegen + build**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Views/CheckInWizard/Steps/FeelingStep.swift OpenFeelings/Views/WizardCheckInView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add FeelingStep with body-driven core highlighting and personalization nudge"
```

---

### Task 15: StrengthStep

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Steps/StrengthStep.swift`

- [ ] **Step 1: Create the view**

```swift
import SwiftUI

/// "How strong?" — five tappable dots. Tapping a dot sets intensity to that
/// value; tapping the same dot again clears it.
struct StrengthStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            HStack(spacing: .OF.sm) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        toggle(value)
                    } label: {
                        Circle()
                            .fill(isFilled(value) ? AnyShapeStyle(Color.OF.accent)
                                                  : AnyShapeStyle(Color.OF.divider))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Intensity \(value)")
                    .accessibilityAddTraits(isFilled(value) ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            HStack {
                Text("Just noticing")
                    .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Spacer()
                Text("Strong")
                    .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            }
        }
        .padding(CGFloat.OF.lg)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func isFilled(_ value: Int) -> Bool {
        draft.includeIntensity && Int(draft.intensity.rounded()) >= value
    }

    private func toggle(_ value: Int) {
        if draft.includeIntensity && Int(draft.intensity.rounded()) == value {
            draft.includeIntensity = false
            draft.intensity = 3
        } else {
            draft.includeIntensity = true
            draft.intensity = Double(value)
        }
    }
}
```

- [ ] **Step 2: xcodegen + build + commit**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
git add OpenFeelings/Views/CheckInWizard/Steps/StrengthStep.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add StrengthStep with 5-dot intensity scale"
```

---

### Task 16: Optional steps — Sensations, Context, Triggers, Coping, Mood

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Steps/SensationsStep.swift`
- Create: `OpenFeelings/Views/CheckInWizard/Steps/ContextStep.swift`
- Create: `OpenFeelings/Views/CheckInWizard/Steps/TriggersStep.swift`
- Create: `OpenFeelings/Views/CheckInWizard/Steps/CopingStep.swift`
- Create: `OpenFeelings/Views/CheckInWizard/Steps/MoodStep.swift`

These five views are structurally similar: each renders one or two chip groups inside an `OFCard`. Pure UI; no TDD.

- [ ] **Step 1: Create SensationsStep**

```swift
import SwiftUI

struct SensationsStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("How does it feel?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(BodySensation.allCases) { s in
                    OFChip(label: s.displayName, isOn: bindingFor(s))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func bindingFor(_ s: BodySensation) -> Binding<Bool> {
        Binding(
            get: { draft.bodySensations.contains(s) },
            set: { isOn in
                if isOn { draft.bodySensations.insert(s) } else { draft.bodySensations.remove(s) }
            }
        )
    }
}
```

- [ ] **Step 2: Create ContextStep**

```swift
import SwiftUI

struct ContextStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Where were you?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(ContextPlace.allCases) { p in
                    OFChip(label: p.displayName, isOn: placeBinding(for: p))
                }
            }
            Divider().background(Color.OF.divider).padding(.vertical, CGFloat.OF.xs)
            Text("Who were you with?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(ContextPeople.allCases) { p in
                    OFChip(label: p.displayName, isOn: peopleBinding(for: p))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func placeBinding(for p: ContextPlace) -> Binding<Bool> {
        Binding(
            get: { draft.contextPlaces.contains(p) },
            set: { isOn in
                if isOn { draft.contextPlaces.insert(p) } else { draft.contextPlaces.remove(p) }
            }
        )
    }

    private func peopleBinding(for p: ContextPeople) -> Binding<Bool> {
        Binding(
            get: { draft.contextPeople.contains(p) },
            set: { isOn in
                if isOn { draft.contextPeople.insert(p) } else { draft.contextPeople.remove(p) }
            }
        )
    }
}
```

- [ ] **Step 3: Create TriggersStep**

```swift
import SwiftUI

struct TriggersStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("What brought it on?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(Trigger.allCases) { t in
                    OFChip(label: t.displayName, isOn: bindingFor(t))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func bindingFor(_ t: Trigger) -> Binding<Bool> {
        Binding(
            get: { draft.triggers.contains(t) },
            set: { isOn in
                if isOn { draft.triggers.insert(t) } else { draft.triggers.remove(t) }
            }
        )
    }
}
```

- [ ] **Step 4: Create CopingStep**

```swift
import SwiftUI

struct CopingStep: View {
    @Binding var draft: CheckInDraft

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("What helped?")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            WrapLayout(hSpacing: CGFloat.OF.sm, vSpacing: CGFloat.OF.sm) {
                ForEach(Coping.allCases) { c in
                    OFChip(label: c.displayName, isOn: bindingFor(c))
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func bindingFor(_ c: Coping) -> Binding<Bool> {
        Binding(
            get: { draft.coping.contains(c) },
            set: { isOn in
                if isOn { draft.coping.insert(c) } else { draft.coping.remove(c) }
            }
        )
    }
}
```

- [ ] **Step 5: Create MoodStep**

```swift
import SwiftUI

struct MoodStep: View {
    @Binding var draft: CheckInDraft
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            Toggle(isOn: $draft.includeMoodScale) {
                Text("Include mood scale").font(.OF.bodyEmphasis)
            }
            if draft.includeMoodScale {
                VStack(alignment: .leading, spacing: .OF.md) {
                    moodSlider(title: "Energy", left: "calm", right: "activated", value: $draft.moodEnergy)
                    moodSlider(title: "Valence", left: "unpleasant", right: "pleasant", value: $draft.moodValence)
                }
            }
        }
        .padding(CGFloat.OF.md)
        .background(Color.OF.surface,
                    in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card, style: .continuous))
    }

    private func moodSlider(title: String, left: String, right: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            HStack {
                Text(title).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Spacer()
                Text(currentLabel(title: title, value: value.wrappedValue))
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.text)
            }
            Slider(value: value, in: -1...1, step: 0.05)
                .tint(Color.OF.accent.color(for: colorScheme))
            HStack {
                Text(left).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                Spacer()
                Text(right).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    private func currentLabel(title: String, value: Double) -> String {
        title == "Energy" ? MoodScale.energyBand(value) : MoodScale.valenceBand(value)
    }
}
```

- [ ] **Step 6: xcodegen + build + commit**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
git add OpenFeelings/Views/CheckInWizard/Steps OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add Sensations, Context, Triggers, Coping, Mood step views"
```

---

### Task 17: ReflectStep

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Steps/ReflectStep.swift`

- [ ] **Step 1: Create the view**

```swift
import SwiftUI

/// Final step. Journal text + optional "+ More detail" disclosure that
/// surfaces every chip card the user did NOT promote to its own step.
struct ReflectStep: View {
    @Binding var draft: CheckInDraft
    let promotedSteps: Set<CheckInStepKind>

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            journalCard
            MoreDetailDisclosure {
                VStack(spacing: .OF.md) {
                    if !promotedSteps.contains(.sensations) && !draft.bodyRegions.isEmpty {
                        SensationsStep(draft: $draft)
                    }
                    if !promotedSteps.contains(.context) {
                        ContextStep(draft: $draft)
                    }
                    if !promotedSteps.contains(.triggers) {
                        TriggersStep(draft: $draft)
                    }
                    if !promotedSteps.contains(.coping) {
                        CopingStep(draft: $draft)
                    }
                    if !promotedSteps.contains(.mood) {
                        MoodStep(draft: $draft)
                    }
                }
            }
        }
    }

    private var journalCard: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text("Journal".uppercased())
                .font(.OF.caption).tracking(1.0).foregroundStyle(Color.OF.textMuted)
            TextEditor(text: $draft.note)
                .font(.OF.body)
                .foregroundStyle(Color.OF.text)
                .frame(minHeight: 160)
                .scrollContentBackground(.hidden)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface,
                            in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }
                .accessibilityLabel("Journal entry")
            Text("Anything you want to remember about this moment.")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
        }
    }
}
```

- [ ] **Step 2: xcodegen + build + commit**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
git add OpenFeelings/Views/CheckInWizard/Steps/ReflectStep.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ReflectStep with journal and More detail disclosure"
```

---

## Phase 5 — Orchestrator

### Task 18: Rewrite `CheckInView` as orchestrator

**Files:**
- Modify: `OpenFeelings/Views/CheckInView.swift` (full rewrite)

- [ ] **Step 1: Read the current orchestrator to capture the save behavior**

```bash
cat OpenFeelings/Views/CheckInView.swift
```

Note the `save()` method and how it constructs `FeelingLog` — preserve every field.

- [ ] **Step 2: Replace `CheckInView.swift` with the new orchestrator**

```swift
import SwiftData
import SwiftUI

/// Entry point for the Check In tab. Orchestrates a step list computed from
/// the user's settings (Body First, promoted steps) and dispatches to per-step
/// views. Holds all draft state in a `CheckInDraft`.
struct CheckInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(HealthService.self) private var healthService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("healthEnabled") private var healthEnabled = false
    @AppStorage("checkInBodyFirst") private var bodyFirst = true
    @AppStorage("checkInPromotedSteps") private var promotedRaw = "strength"
    @AppStorage("checkInLearnFromHistory") private var learnFromHistory = true

    @Query private var allLogs: [FeelingLog]
    @Query private var bodyMaps: [UserBodyMap]

    @State private var draft = CheckInDraft()
    @State private var stepIndex = 0
    @State private var dismissedNudgeRegions: Set<BodyRegion> = []

    private var promotedSteps: Set<CheckInStepKind> {
        Set(CheckInStepKind.parseList(promotedRaw))
    }

    private var stepList: [CheckInStepKind] {
        CheckInFlowEngine.steps(bodyFirst: bodyFirst, promotedSteps: promotedSteps)
    }

    private var currentStep: CheckInStepKind {
        stepList[min(stepIndex, stepList.count - 1)]
    }

    private var bodyMap: UserBodyMap {
        bodyMaps.first ?? UserBodyMap()
    }

    private var learnedMap: LearnedBodyMap {
        guard learnFromHistory else { return LearnedBodyMap(counts: [:], totals: [:]) }
        return LearnedBodyMap.compute(from: allLogs)
    }

    private var suggestedCoreIDs: Set<String> {
        BodyEmotionMap.suggestedCores(for: draft.bodyRegions, overrides: bodyMap)
    }

    private var nudgePayload: FeelingStep.NudgePayload? {
        guard let region = draft.bodyRegions.first(where: { $0 != .wholeBody && $0 != .nowhere }),
              !dismissedNudgeRegions.contains(region) else { return nil }
        // Don't nudge when an override already exists.
        if bodyMap.coreIDs(for: region) != nil { return nil }
        guard let secondaryID = learnedMap.dominantSecondary(for: region),
              let total = learnedMap.totals[region],
              let count = learnedMap.counts[region]?[secondaryID] else { return nil }
        // Resolve secondary name.
        let secondaryName = EmotionTaxonomy.cores
            .flatMap { $0.secondaries }
            .first { $0.id == secondaryID }?.title ?? secondaryID
        return FeelingStep.NudgePayload(
            region: region,
            secondaryID: secondaryID,
            secondaryName: secondaryName,
            count: count,
            total: total
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                StepHeader(
                    stepIndex: stepIndex,
                    totalSteps: stepList.count,
                    title: title(for: currentStep),
                    subtitle: subtitle(for: currentStep),
                    selectedFeeling: shouldShowBadge ? draft.selection : nil,
                    intensity: draft.includeIntensity ? Int(draft.intensity.rounded()) : nil
                )
                stepContent
                StepNav(
                    canGoBack: stepIndex > 0,
                    canSkip: !isFirstStep && currentStep != .feeling,
                    canAdvance: canAdvance,
                    isFinalStep: stepIndex == stepList.count - 1,
                    onBack: goBack,
                    onSkip: goNext,
                    onAdvance: advance
                )
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
            .animation(reduceMotion ? nil : .OF.gentle, value: stepIndex)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { ensureUserBodyMapExists() }
    }

    // MARK: - Step content dispatch

    @ViewBuilder
    private var stepContent: some View {
        switch currentStep {
        case .body:
            BodyStep(draft: $draft)
        case .feeling:
            FeelingStep(
                draft: $draft,
                suggestedCoreIDs: suggestedCoreIDs,
                nudge: nudgePayload,
                onSaveOverride: saveOverride,
                onDismissNudge: dismissNudge
            )
        case .strength:
            StrengthStep(draft: $draft)
        case .sensations:
            SensationsStep(draft: $draft)
        case .context:
            ContextStep(draft: $draft)
        case .triggers:
            TriggersStep(draft: $draft)
        case .coping:
            CopingStep(draft: $draft)
        case .mood:
            MoodStep(draft: $draft)
        case .reflect:
            ReflectStep(draft: $draft, promotedSteps: promotedSteps)
        }
    }

    // MARK: - Titles

    private func title(for kind: CheckInStepKind) -> String {
        switch kind {
        case .body:       "Where do you feel it?"
        case .feeling:    "How are you feeling?"
        case .strength:   "How strong?"
        case .sensations: "How does it feel?"
        case .context:    "What was happening?"
        case .triggers:   "What brought it on?"
        case .coping:     "What helped?"
        case .mood:       "Mood scale"
        case .reflect:    "Anything to remember?"
        }
    }

    private func subtitle(for kind: CheckInStepKind) -> String {
        switch kind {
        case .body:       "Optional."
        case .feeling:    draft.bodyRegions.isEmpty ? "Pick the feeling that fits." : "Suggestions based on your body picks."
        case .strength:   "Optional."
        case .sensations: "Optional."
        case .context:    "Optional."
        case .triggers:   "Optional."
        case .coping:     "Optional."
        case .mood:       "Optional."
        case .reflect:    "All optional."
        }
    }

    private var shouldShowBadge: Bool {
        // Show badge from feeling-step onward.
        guard let feelingIdx = stepList.firstIndex(of: .feeling) else { return false }
        return stepIndex > feelingIdx && draft.selection?.isComplete == true
    }

    private var isFirstStep: Bool { stepIndex == 0 }

    // MARK: - Advancement

    private var canAdvance: Bool {
        if currentStep == .feeling { return draft.selection?.isComplete == true }
        if stepIndex == stepList.count - 1 { return draft.canSave }
        return true
    }

    private func advance() {
        if stepIndex == stepList.count - 1 {
            save()
        } else {
            withAnimation(reduceMotion ? nil : .OF.gentle) {
                stepIndex += 1
            }
        }
    }

    private func goBack() {
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            stepIndex = max(0, stepIndex - 1)
        }
    }

    private func goNext() {
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            stepIndex = min(stepList.count - 1, stepIndex + 1)
        }
    }

    // MARK: - Body map override

    private func saveOverride(region: BodyRegion, secondaryID: String) {
        // Translate secondary → its parent core, persist as a single-core
        // override. (Spec uses core-level overrides; learned secondary is
        // promoted by adding its parent core to the override list.)
        guard let core = EmotionTaxonomy.cores.first(where: { core in
            core.secondaries.contains { $0.id == secondaryID }
        }) else { return }
        bodyMap.setOverride(for: region, coreIDs: [core.id])
        try? modelContext.save()
        dismissedNudgeRegions.insert(region)
    }

    private func dismissNudge() {
        if let region = draft.bodyRegions.first(where: { $0 != .wholeBody && $0 != .nowhere }) {
            dismissedNudgeRegions.insert(region)
        }
    }

    private func ensureUserBodyMapExists() {
        if bodyMaps.isEmpty {
            modelContext.insert(UserBodyMap())
            try? modelContext.save()
        }
    }

    // MARK: - Save (preserves the old save() exactly)

    private func save() {
        guard let selection = draft.selection, selection.isComplete else { return }

        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let log = FeelingLog(
            selection: selection,
            intensity: draft.includeIntensity ? Int(draft.intensity.rounded()) : nil,
            note: trimmedNote,
            healthSyncStatus: healthEnabled ? .pending : .notRequested,
            bodyRegions: BodyRegion.allCases.filter { draft.bodyRegions.contains($0) },
            bodySensations: BodySensation.allCases.filter { draft.bodySensations.contains($0) },
            contextPlaces: ContextPlace.allCases.filter { draft.contextPlaces.contains($0) },
            contextPeople: ContextPeople.allCases.filter { draft.contextPeople.contains($0) },
            triggers: Trigger.allCases.filter { draft.triggers.contains($0) },
            coping: Coping.allCases.filter { draft.coping.contains($0) },
            moodEnergy: draft.includeMoodScale ? draft.moodEnergy : nil,
            moodValence: draft.includeMoodScale ? draft.moodValence : nil
        )
        modelContext.insert(log)
        try? modelContext.save()
        draft.reset()
        stepIndex = 0
        dismissedNudgeRegions.removeAll()

        navigation.ribbonAfterSave()
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            navigation.select(.today)
        }

        Task { @MainActor in
            log.healthSyncStatus = await healthService.save(log: log, isEnabled: healthEnabled)
            try? modelContext.save()
        }
    }
}
```

- [ ] **Step 3: xcodegen + build**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -10
```

If the build errors, the most likely issues are:
- `EmotionSelection.title` / `pathTitle` / `definition` member access — confirm via the existing `CheckInView.swift` that these are real.
- `OFButton`, `OFChip`, `WrapLayout`, `OFCard` references — confirm these exist via `grep`.
- `FeelingLog` initializer signature — match the current call site exactly.

- [ ] **Step 4: Commit**

```bash
git add OpenFeelings/Views/CheckInView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Replace CheckInView with calm-wizard orchestrator"
```

---

### Task 19: Register `UserBodyMap` in the ModelContainer schema

**Files:**
- Modify: `OpenFeelings/OpenFeelingsApp.swift`

- [ ] **Step 1: Update the schema**

Find this line in `OpenFeelingsApp.swift`:

```swift
let schema = Schema([FeelingLog.self, Intention.self])
```

Replace with:

```swift
let schema = Schema([FeelingLog.self, Intention.self, UserBodyMap.self])
```

- [ ] **Step 2: Build**

```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

- [ ] **Step 3: Commit**

```bash
git add OpenFeelings/OpenFeelingsApp.swift
git commit -m "Register UserBodyMap in ModelContainer schema"
```

---

## Phase 6 — Settings

### Task 20: `CheckInFlowSettingsView`

**Files:**
- Create: `OpenFeelings/Views/Settings/CheckInFlowSettingsView.swift`

- [ ] **Step 1: Create the view**

```swift
import SwiftUI

/// Settings → Check In flow. Houses picker style, Body First, body view,
/// and the per-dimension promote-to-step toggles.
struct CheckInFlowSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("checkInMode") private var pickerStyle = "Wizard"
    @AppStorage("checkInBodyFirst") private var bodyFirst = true
    @AppStorage("checkInBodyView") private var bodyView = "chips"
    @AppStorage("checkInPromotedSteps") private var promotedRaw = "strength"

    var body: some View {
        Form {
            Section("Picker style") {
                Picker("Picker", selection: $pickerStyle) {
                    Text("Wizard").tag("Wizard")
                    Text("Wheel").tag("Wheel")
                }
                .pickerStyle(.segmented)
            }

            Section("Body") {
                Toggle("Body First", isOn: $bodyFirst)
                Picker("Body view", selection: $bodyView) {
                    Text("Chips").tag("chips")
                    Text("Silhouette").tag("silhouette")
                }
            }

            Section("Steps") {
                Text("Promote optional dimensions to first-class steps. Anything left off stays accessible via '+ More detail' on the final step.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                ForEach(promotableKinds, id: \.self) { kind in
                    Toggle(label(for: kind), isOn: bindingFor(kind))
                }
            }
        }
        .navigationTitle("Check In flow")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
    }

    private var promotableKinds: [CheckInStepKind] {
        [.sensations, .strength, .context, .triggers, .coping, .mood]
    }

    private func label(for kind: CheckInStepKind) -> String {
        switch kind {
        case .sensations: "Sensations"
        case .strength:   "Strength"
        case .context:    "Context"
        case .triggers:   "Triggers"
        case .coping:     "Coping"
        case .mood:       "Mood scale"
        default:          kind.storageKey.capitalized
        }
    }

    private func bindingFor(_ kind: CheckInStepKind) -> Binding<Bool> {
        Binding(
            get: { Set(CheckInStepKind.parseList(promotedRaw)).contains(kind) },
            set: { isOn in
                var current = Set(CheckInStepKind.parseList(promotedRaw))
                if isOn { current.insert(kind) } else { current.remove(kind) }
                let ordered: [CheckInStepKind] = [.sensations, .strength, .context, .triggers, .coping, .mood]
                    .filter { current.contains($0) }
                promotedRaw = CheckInStepKind.encodeList(ordered)
            }
        )
    }
}
```

- [ ] **Step 2: xcodegen + build + commit**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
git add OpenFeelings/Views/Settings/CheckInFlowSettingsView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add Settings → Check In flow screen"
```

---

### Task 21: `BodyMapSettingsView`

**Files:**
- Create: `OpenFeelings/Views/Settings/BodyMapSettingsView.swift`

- [ ] **Step 1: Create the view**

```swift
import SwiftData
import SwiftUI

/// Settings → Body map. Lists body regions with their effective cores
/// (override > learned > default) and lets users edit overrides.
struct BodyMapSettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage("checkInLearnFromHistory") private var learnFromHistory = true

    @Query private var bodyMaps: [UserBodyMap]
    @Query private var allLogs: [FeelingLog]

    @State private var editingRegion: BodyRegion?

    private var bodyMap: UserBodyMap? { bodyMaps.first }

    private var displayRegions: [BodyRegion] {
        BodyRegion.allCases.filter { $0 != .nowhere }
    }

    var body: some View {
        Form {
            Section {
                Toggle("Learn from history", isOn: $learnFromHistory)
                Text("When on, the app shifts suggestions over time based on what you've actually picked.")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }

            Section("Mappings") {
                ForEach(displayRegions, id: \.self) { region in
                    Button { editingRegion = region } label: {
                        HStack {
                            Text(region.displayName).foregroundStyle(Color.OF.text)
                            Spacer()
                            Text(coreSummary(for: region))
                                .font(.OF.caption)
                                .foregroundStyle(Color.OF.textMuted)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.OF.caption)
                                .foregroundStyle(Color.OF.textMuted)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            Section {
                Button(role: .destructive) {
                    bodyMap?.resetAll()
                    try? modelContext.save()
                } label: {
                    Text("Reset all to defaults")
                }
            }
        }
        .navigationTitle("Body map")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingRegion) { region in
            EditBodyRegionView(region: region, bodyMap: bodyMap)
                .environment(\.modelContext, modelContext)
        }
    }

    private func coreSummary(for region: BodyRegion) -> String {
        let effective: [String]
        if let overridden = bodyMap?.coreIDs(for: region), !overridden.isEmpty {
            effective = overridden
        } else {
            effective = BodyEmotionMap.defaultCores(for: region)
        }
        let names = effective.compactMap { id in
            EmotionTaxonomy.cores.first(where: { $0.id == id })?.title
        }
        let mark = bodyMap?.coreIDs(for: region) != nil ? " ★" : ""
        return names.joined(separator: ", ") + mark
    }
}

extension BodyRegion: Identifiable {
    public var idForSheet: BodyRegion { self }
}

private struct EditBodyRegionView: View {
    let region: BodyRegion
    let bodyMap: UserBodyMap?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCoreIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Cores you tend to feel here") {
                    ForEach(EmotionTaxonomy.cores) { core in
                        Toggle(core.title, isOn: bindingFor(core.id))
                    }
                }
            }
            .navigationTitle(region.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        bodyMap?.setOverride(for: region, coreIDs: Array(selectedCoreIDs))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(selectedCoreIDs.isEmpty)
                }
            }
            .onAppear {
                if let existing = bodyMap?.coreIDs(for: region) {
                    selectedCoreIDs = Set(existing)
                } else {
                    selectedCoreIDs = Set(BodyEmotionMap.defaultCores(for: region))
                }
            }
        }
    }

    private func bindingFor(_ id: String) -> Binding<Bool> {
        Binding(
            get: { selectedCoreIDs.contains(id) },
            set: { isOn in
                if isOn { selectedCoreIDs.insert(id) } else { selectedCoreIDs.remove(id) }
            }
        )
    }
}
```

- [ ] **Step 2: xcodegen + build + commit**

```bash
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
git add OpenFeelings/Views/Settings/BodyMapSettingsView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add Settings → Body map screen with override editor"
```

---

### Task 22: Wire Settings nav links

**Files:**
- Modify: `OpenFeelings/Views/SettingsView.swift`

- [ ] **Step 1: Replace the inline `checkInSection` with two NavigationLinks**

In `SettingsView.swift`, find `private var checkInSection: some View { ... }` (the one that renders the Body First / Feeling First pill segment) and replace it with:

```swift
    private var checkInSection: some View {
        section(title: "Check In") {
            NavigationLink {
                CheckInFlowSettingsView()
            } label: {
                OFListRow.chevron(
                    title: "Check In flow",
                    subtitle: "Picker style, Body First, steps",
                    systemImage: "checklist"
                )
            }
            .buttonStyle(.plain)
            divider
            NavigationLink {
                BodyMapSettingsView()
            } label: {
                OFListRow.chevron(
                    title: "Body map",
                    subtitle: "Where you feel each emotion",
                    systemImage: "figure.stand"
                )
            }
            .buttonStyle(.plain)
        }
    }
```

Also remove the now-unused `checkInOrderButton(...)` helper and `@AppStorage("checkInBodyFirst") private var bodyFirst = true` line in `SettingsView.swift` (since it lives one screen deeper now).

- [ ] **Step 2: Build**

```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
```

If the build fails because `OFListRow.chevron` doesn't accept `systemImage`, fall back to the existing pattern used elsewhere in `SettingsView.swift` for nav rows.

- [ ] **Step 3: Commit**

```bash
git add OpenFeelings/Views/SettingsView.swift
git commit -m "Wire Settings → Check In flow and Body map nav links"
```

---

## Phase 7 — Verify and ship

### Task 23: Full build + test

- [ ] **Step 1: Run the full test suite**

```bash
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -30
```

Expected: TEST SUCCEEDED. ~125+ tests pass (existing ~99 + new ~26 from this plan).

- [ ] **Step 2: Manual sim verification**

Boot the iPad sim. Walk through:

1. With Body First on (default): Where → Feeling → Strength → Reflect, exactly 4 steps.
2. Settings → Check In flow → flip Body First off → Wizard becomes Feeling → Strength → Reflect.
3. Promote Context and Triggers in Settings → flow becomes Body → Feeling → Context → Triggers → Strength → Reflect.
4. On the body step, pick Chest. Continue to Feeling. Confirm Angry / Happy / Fearful are at full opacity, Sad / Disgusted are dimmed.
5. Pick Stomach + Legs. Continue to Feeling. Confirm only Fearful is highlighted.
6. Tap Everywhere on body step. Confirm regular regions clear and become unselectable. Continue to Feeling. Confirm no dimming.
7. Tap Nowhere. Continue to Feeling. Confirm Sad has the small accent dot, others remain at full opacity (special case).
8. Settings → Body map → confirm rows render with current effective cores. Edit Chest → pick Sad only → Save. Back to Check In: pick Chest → Step 2 confirms only Sad is highlighted.
9. Settings → Body map → Reset all to defaults. Confirm Chest reverts to Angry/Happy/Fearful.
10. Settings → Check In flow → switch Body view to Silhouette. Body step now shows the silhouette with tap zones. Tap Chest zone — fills with accent.

If any step fails, file a follow-up and address before ship.

- [ ] **Step 3: Commit any fixes from manual verification**

If issues found, fix and commit individually.

---

### Task 24: Release to TestFlight

- [ ] **Step 1: Merge to main**

```bash
git checkout main
git merge --ff-only checkin-wizard-redesign-v2
git branch -d checkin-wizard-redesign-v2
```

If fast-forward isn't possible, `git merge --no-ff` is fine.

- [ ] **Step 2: Run release script**

```bash
./scripts/release.sh
```

Expected: bumps build number in `project.yml`, archives, exports, uploads to App Store Connect, commits the bump.

- [ ] **Step 3: Push**

```bash
git push origin main
```

- [ ] **Step 4: Notify the user**

Report:
- Build number that uploaded to TestFlight.
- Manual verification status from Task 23 step 2.
- Any deferred items observed in the simulator that need follow-up.

---

## Self-Review Notes

**Spec coverage:**

| Spec section | Covered by |
|---|---|
| Calm wizard, one-question-per-step | Tasks 7, 8, 18 |
| Body First as extra step | Tasks 7, 8 (in `CheckInFlowEngine`) |
| Everywhere/Nowhere as italic dashed chips | Task 13 (`BodyStep`) |
| Body view chips/silhouette opt-in | Tasks 11, 13, 20 |
| Body→core highlighting on Step 2 | Tasks 5, 14, 18 |
| Personalization (defaults + learning + override + nudge) | Tasks 4, 5, 6, 18, 21 |
| Adaptive step list | Tasks 7, 8, 20 |
| Picker mode pill segment retained | Task 14 (`FeelingStep`) |
| `BodyRegion.nowhere` | Task 1 |
| `BodyEmotionMap` | Tasks 2, 3, 5 |
| `UserBodyMap` SwiftData model | Tasks 4, 19 |
| `LearnedBodyMap` | Task 6 |
| Settings → Check In flow | Task 20 |
| Settings → Body map | Task 21 |
| Tests (CheckInFlowEngine, BodyEmotionMap, UserBodyMap, LearnedBodyMap, BodyTaxonomy) | Tasks 1–8 |

**Type consistency:** `CheckInDraft.bodyRegions: Set<BodyRegion>`, `BodyEmotionMap.suggestedCores(for: Set<BodyRegion>, overrides: UserBodyMap?) -> Set<String>`, `LearnedBodyMap.dominantSecondary(for: BodyRegion) -> String?` — consistent across tasks.

**Out of scope (unchanged from spec):** Wheel-mode body→core highlighting, region-specific sensation modifiers, secondary-level explicit overrides, in-flight migration, localization of mappings, deep VoiceOver rotor polish on silhouette zones.
