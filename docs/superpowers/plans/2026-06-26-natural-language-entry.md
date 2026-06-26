# Natural-Language Check-In Entry — Implementation Plan (Phase 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users save a check-in by typing or speaking one plain-language sentence, on two surfaces — an in-app quick-entry screen and a Siri/App Shortcut — filling emotion + intensity + note.

**Architecture:** One pure `FeelingParser` seam turns a `String` into a `ParsedFeeling`, which maps to the existing `CheckInDraft` and persists through a new shared `FeelingLogService`. Phase 1 ships the deterministic `KeywordFeelingParser` (also the permanent fallback). The in-app `QuickEntryView` and an in-process `LogFeelingIntent` both consume the seam via a non-SwiftUI `FeelingParserProvider`.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, AppIntents (all first-party). iOS 26 target. XCTest. xcodegen project generation.

**Spec:** `docs/superpowers/specs/2026-06-26-natural-language-entry-design.md` — read it before starting.

## Global Constraints

- **No third-party SDKs, no network, no analytics** — everything on-device/first-party. The synonym table is **original authored content, MIT** — do **not** import any emotion lexicon (NRC EmoLex / WordNet-Affect / LIWC).
- **iOS deployment target 26.0**, Swift 6 (`project.yml:4-5,10`).
- **Test framework is XCTest** (no Swift Testing). In-memory SwiftData via `ModelConfiguration(isStoredInMemoryOnly: true)`.
- **New source files** go anywhere under `OpenFeelings/` (the main target globs that path, `project.yml:17-18`) — **no `project.yml` edits needed** — but you **must run `xcodegen generate`** before the new files compile. Keep new parser/synonym/lookup files **out of `EmotionTaxonomy.swift`** (that file is compiled into the watchOS target, `project.yml:47`); new standalone files are iOS-only by default.
- **Intensity scale is 1...5** (`Int?`), optional. Emotion **stops at any level** (`EmotionSelection.isComplete == true` at core).
- **Capture sources:** existing `"phone"` (wizard/wheel) + `"watch"`; this plan adds `"siri"` and `"quickentry"`.
- **Emotion cores are:** Happy, Sad, Angry, Fearful, Disgusted (5 cores / 25 secondaries / 50 specifics, names globally unique). "Anxious" is a *secondary* under Fearful; "Nervous" is a *specific* under "Threatened".
- **Commit after every task.** Branch is `feat/natural-language-entry`.

---

## Task 1: `ParsedFeeling` value type + `toDraft()`

**Files:**
- Create: `OpenFeelings/NaturalLanguage/ParsedFeeling.swift`
- Test: `OpenFeelingsTests/ParsedFeelingTests.swift`

**Interfaces:**
- Consumes: `EmotionCore`, `EmotionSecondary`, `EmotionSpecific`, `EmotionSelection` (from `EmotionTaxonomy.swift`); `CheckInDraft` (`OpenFeelings/Views/CheckInWizard/CheckInDraft.swift`).
- Produces: `struct ParsedFeeling` with `core/secondary/specific/intensity/note/confidence/rawUtterance`, `enum Confidence { case high, low, none }`, and `func toDraft() -> CheckInDraft`.

- [ ] **Step 1: Write the failing test**

```swift
// OpenFeelingsTests/ParsedFeelingTests.swift
import XCTest
@testable import OpenFeelings

final class ParsedFeelingTests: XCTestCase {
    private var fearful: EmotionCore { EmotionTaxonomy.cores.first { $0.name == "Fearful" }! }
    private var anxious: EmotionSecondary { fearful.secondaries.first { $0.name == "Anxious" }! }

    func testToDraftMapsCoreOnlyWithNote() {
        let parsed = ParsedFeeling(
            core: fearful, secondary: nil, specific: nil,
            intensity: nil, note: "work is a lot",
            confidence: .low, rawUtterance: "work is a lot"
        )
        let draft = parsed.toDraft()
        XCTAssertEqual(draft.selection?.core.name, "Fearful")
        XCTAssertNil(draft.selection?.secondary)
        XCTAssertEqual(draft.note, "work is a lot")
        XCTAssertFalse(draft.includeIntensity)
    }

    func testToDraftThreadsSecondaryAndIntensity() {
        let parsed = ParsedFeeling(
            core: fearful, secondary: anxious, specific: nil,
            intensity: 4, note: "before the demo",
            confidence: .high, rawUtterance: "anxious before the demo 4/5"
        )
        let draft = parsed.toDraft()
        XCTAssertEqual(draft.selection?.secondary?.name, "Anxious")
        XCTAssertTrue(draft.includeIntensity)
        XCTAssertEqual(Int(draft.intensity.rounded()), 4)
    }

    func testToDraftWithNoCoreLeavesSelectionNil() {
        let parsed = ParsedFeeling(
            core: nil, secondary: nil, specific: nil,
            intensity: nil, note: "asdf",
            confidence: .none, rawUtterance: "asdf"
        )
        XCTAssertNil(parsed.toDraft().selection)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/ParsedFeelingTests 2>&1 | tail -20`
Expected: FAIL — "cannot find 'ParsedFeeling' in scope".

(If `iPhone 16` is unavailable, run `xcrun simctl list devices available` and substitute any available iPhone sim.)

- [ ] **Step 3: Write minimal implementation**

```swift
// OpenFeelings/NaturalLanguage/ParsedFeeling.swift
import Foundation

/// The result of parsing one natural-language utterance into a (possibly
/// partial) feeling. Pure value type — no SwiftData / SwiftUI / Siri / FM.
/// `core == nil` means nothing in the taxonomy matched; `rawUtterance` is
/// always preserved so the user's words are never lost.
struct ParsedFeeling: Equatable {
    enum Confidence { case high, low, none }

    var core: EmotionCore?
    var secondary: EmotionSecondary?
    var specific: EmotionSpecific?
    var intensity: Int?
    var note: String
    var confidence: Confidence
    var rawUtterance: String

    /// Map into the existing wizard draft so both surfaces reuse the same
    /// persistence + review UI. Leaves `selection` nil when no core resolved.
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

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/ParsedFeelingTests 2>&1 | tail -20`
Expected: PASS (3 tests). You will need `xcodegen generate` first if the new files aren't in the project yet — run it, then test.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/NaturalLanguage/ParsedFeeling.swift OpenFeelingsTests/ParsedFeelingTests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Add ParsedFeeling value type + toDraft mapping"
```

---

## Task 2: Taxonomy name-lookup helpers

**Files:**
- Create: `OpenFeelings/NaturalLanguage/EmotionTaxonomy+Lookup.swift`
- Test: `OpenFeelingsTests/EmotionTaxonomyLookupTests.swift`

**Why a new file (not in `EmotionTaxonomy.swift`):** `EmotionTaxonomy.swift` is compiled into the watchOS target; this extension is iOS-only and the parser needs it. Keep it separate.

**Interfaces:**
- Produces: `EmotionTaxonomy.node(named:)` → resolves a case-insensitive name to a `Resolved` location; `struct ResolvedNode { let core; let secondary?; let specific? }`. Also `EmotionTaxonomy.allNodeNames` for the synonym invariant test.

- [ ] **Step 1: Write the failing test**

```swift
// OpenFeelingsTests/EmotionTaxonomyLookupTests.swift
import XCTest
@testable import OpenFeelings

final class EmotionTaxonomyLookupTests: XCTestCase {
    func testResolvesCoreNameCaseInsensitively() {
        let node = EmotionTaxonomy.node(named: "fearful")
        XCTAssertEqual(node?.core.name, "Fearful")
        XCTAssertNil(node?.secondary)
        XCTAssertNil(node?.specific)
    }

    func testResolvesSecondaryNameToItsCore() {
        let node = EmotionTaxonomy.node(named: "Anxious")
        XCTAssertEqual(node?.core.name, "Fearful")
        XCTAssertEqual(node?.secondary?.name, "Anxious")
        XCTAssertNil(node?.specific)
    }

    func testResolvesSpecificNameWithFullPath() {
        let node = EmotionTaxonomy.node(named: "Nervous")
        XCTAssertEqual(node?.core.name, "Fearful")
        XCTAssertEqual(node?.secondary?.name, "Threatened")
        XCTAssertEqual(node?.specific?.name, "Nervous")
    }

    func testUnknownNameReturnsNil() {
        XCTAssertNil(EmotionTaxonomy.node(named: "banana"))
    }

    func testAllNodeNamesAreGloballyUnique() {
        let names = EmotionTaxonomy.allNodeNames.map { $0.lowercased() }
        XCTAssertEqual(names.count, Set(names).count, "Taxonomy node names must be globally unique")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/EmotionTaxonomyLookupTests 2>&1 | tail -20`
Expected: FAIL — "type 'EmotionTaxonomy' has no member 'node'".

- [ ] **Step 3: Write minimal implementation**

```swift
// OpenFeelings/NaturalLanguage/EmotionTaxonomy+Lookup.swift
import Foundation

extension EmotionTaxonomy {
    /// A taxonomy location resolved from a name: always a core, with the
    /// secondary/specific path filled in when the name was a deeper node.
    struct ResolvedNode: Equatable {
        let core: EmotionCore
        let secondary: EmotionSecondary?
        let specific: EmotionSpecific?
    }

    /// Every core/secondary/specific name in the tree, for uniqueness checks.
    static var allNodeNames: [String] {
        cores.flatMap { core -> [String] in
            [core.name] + core.secondaries.flatMap { sec -> [String] in
                [sec.name] + sec.specifics.map { $0.name }
            }
        }
    }

    /// Case-insensitive exact-name resolution to the deepest node bearing
    /// that name. Returns nil when no node matches.
    static func node(named query: String) -> ResolvedNode? {
        let needle = query.lowercased()
        for core in cores {
            if core.name.lowercased() == needle {
                return ResolvedNode(core: core, secondary: nil, specific: nil)
            }
            for secondary in core.secondaries {
                if secondary.name.lowercased() == needle {
                    return ResolvedNode(core: core, secondary: secondary, specific: nil)
                }
                for specific in secondary.specifics where specific.name.lowercased() == needle {
                    return ResolvedNode(core: core, secondary: secondary, specific: specific)
                }
            }
        }
        return nil
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/EmotionTaxonomyLookupTests 2>&1 | tail -20`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/NaturalLanguage/EmotionTaxonomy+Lookup.swift OpenFeelingsTests/EmotionTaxonomyLookupTests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Add taxonomy name-lookup helpers (iOS-only)"
```

---

## Task 3: Synonym table (`FeelingSynonyms`)

**Files:**
- Create: `OpenFeelings/NaturalLanguage/FeelingSynonyms.swift`
- Test: `OpenFeelingsTests/FeelingSynonymsTests.swift`

**Interfaces:**
- Consumes: `EmotionTaxonomy.node(named:)`, `EmotionTaxonomy.cores`.
- Produces: `struct FeelingSynonym { let phrase: String; let targetName: String; let strength: Strength }`, `enum Strength { case strong, weak }`, `enum FeelingSynonyms { static let entries: [FeelingSynonym] }`.

**Content rule:** original authored content (MIT). `targetName` must equal a real taxonomy node name. `strength` is authored: a confident vernacular mapping (`anxious → Anxious`) is `.strong`; a broad/fuzzy one (`off → Sad`) is `.weak`. The seed below covers all 5 cores and many secondaries — **extend with additional everyday vernacular**; the invariant test guarantees validity.

- [ ] **Step 1: Write the failing test**

```swift
// OpenFeelingsTests/FeelingSynonymsTests.swift
import XCTest
@testable import OpenFeelings

final class FeelingSynonymsTests: XCTestCase {
    func testEveryEntryResolvesToARealNode() {
        for entry in FeelingSynonyms.entries {
            XCTAssertNotNil(
                EmotionTaxonomy.node(named: entry.targetName),
                "Synonym '\(entry.phrase)' targets unknown node '\(entry.targetName)'"
            )
        }
    }

    func testEveryCoreIsReachableBySomeSynonymOrItsOwnName() {
        for core in EmotionTaxonomy.cores {
            let reachable = EmotionTaxonomy.node(named: core.name) != nil
                || FeelingSynonyms.entries.contains {
                    EmotionTaxonomy.node(named: $0.targetName)?.core.name == core.name
                }
            XCTAssertTrue(reachable, "Core '\(core.name)' has no synonym path")
        }
    }

    func testPhrasesAreLowercasedAndNonEmpty() {
        for entry in FeelingSynonyms.entries {
            XCTAssertFalse(entry.phrase.isEmpty)
            XCTAssertEqual(entry.phrase, entry.phrase.lowercased())
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/FeelingSynonymsTests 2>&1 | tail -20`
Expected: FAIL — "cannot find 'FeelingSynonyms' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// OpenFeelings/NaturalLanguage/FeelingSynonyms.swift
//
// Original authored content. Licensed MIT (same as source code). This is a
// hand-authored mapping of everyday vernacular onto Open Feelings' own
// taxonomy node names — NOT a reproduction or adaptation of the Open Emotion
// Wheel taxonomy text/arrangement, and NOT derived from any third-party
// emotion lexicon. Do not import NRC EmoLex / WordNet-Affect / LIWC.
import Foundation

enum Strength { case strong, weak }

struct FeelingSynonym {
    let phrase: String     // lowercased vernacular
    let targetName: String // must equal a real EmotionTaxonomy node name
    let strength: Strength
}

enum FeelingSynonyms {
    static let entries: [FeelingSynonym] = [
        // Fearful
        .init(phrase: "anxious", targetName: "Anxious", strength: .strong),
        .init(phrase: "nervous", targetName: "Nervous", strength: .strong),
        .init(phrase: "on edge", targetName: "Anxious", strength: .strong),
        .init(phrase: "stressed", targetName: "Anxious", strength: .strong),
        .init(phrase: "scared", targetName: "Fearful", strength: .strong),
        .init(phrase: "afraid", targetName: "Fearful", strength: .strong),
        .init(phrase: "worried", targetName: "Worried", strength: .strong),
        .init(phrase: "overwhelmed", targetName: "Overwhelmed", strength: .strong),
        .init(phrase: "insecure", targetName: "Insecure", strength: .strong),
        // Sad
        .init(phrase: "sad", targetName: "Sad", strength: .strong),
        .init(phrase: "down", targetName: "Sad", strength: .strong),
        .init(phrase: "blue", targetName: "Sad", strength: .weak),
        .init(phrase: "low", targetName: "Sad", strength: .weak),
        .init(phrase: "lonely", targetName: "Lonely", strength: .strong),
        .init(phrase: "hurt", targetName: "Hurt", strength: .strong),
        .init(phrase: "disappointed", targetName: "Disappointed", strength: .strong),
        .init(phrase: "guilty", targetName: "Guilty", strength: .strong),
        .init(phrase: "ashamed", targetName: "Ashamed", strength: .strong),
        .init(phrase: "grief", targetName: "Grief", strength: .strong),
        // Angry
        .init(phrase: "angry", targetName: "Angry", strength: .strong),
        .init(phrase: "mad", targetName: "Angry", strength: .strong),
        .init(phrase: "pissed", targetName: "Angry", strength: .strong),
        .init(phrase: "furious", targetName: "Infuriated", strength: .strong),
        .init(phrase: "frustrated", targetName: "Frustrated", strength: .strong),
        .init(phrase: "annoyed", targetName: "Annoyed", strength: .strong),
        .init(phrase: "bitter", targetName: "Bitter", strength: .strong),
        .init(phrase: "humiliated", targetName: "Humiliated", strength: .strong),
        .init(phrase: "numb", targetName: "Numb", strength: .strong),
        // Happy
        .init(phrase: "happy", targetName: "Happy", strength: .strong),
        .init(phrase: "good", targetName: "Happy", strength: .weak),
        .init(phrase: "great", targetName: "Happy", strength: .weak),
        .init(phrase: "hopeful", targetName: "Hopeful", strength: .strong),
        .init(phrase: "grateful", targetName: "Thankful", strength: .strong),
        .init(phrase: "thankful", targetName: "Thankful", strength: .strong),
        .init(phrase: "loved", targetName: "Loved", strength: .strong),
        .init(phrase: "proud", targetName: "Proud", strength: .strong),
        .init(phrase: "confident", targetName: "Confident", strength: .strong),
        .init(phrase: "excited", targetName: "Excited", strength: .strong),
        .init(phrase: "energetic", targetName: "Energetic", strength: .strong),
        .init(phrase: "peaceful", targetName: "Peaceful", strength: .strong),
        .init(phrase: "calm", targetName: "Peaceful", strength: .weak),
        // Disgusted
        .init(phrase: "disgusted", targetName: "Disgusted", strength: .strong),
        .init(phrase: "grossed out", targetName: "Disgusted", strength: .strong),
        .init(phrase: "repelled", targetName: "Repelled", strength: .strong),
        .init(phrase: "horrified", targetName: "Horrified", strength: .strong),
        .init(phrase: "embarrassed", targetName: "Embarrassed", strength: .strong),
        .init(phrase: "shocked", targetName: "Shocked", strength: .strong),
        .init(phrase: "judgemental", targetName: "Judgemental", strength: .strong),
        // Broad / fuzzy fallbacks (weak)
        .init(phrase: "off", targetName: "Sad", strength: .weak),
        .init(phrase: "meh", targetName: "Sad", strength: .weak),
        .init(phrase: "tense", targetName: "Anxious", strength: .weak),
    ]
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/FeelingSynonymsTests 2>&1 | tail -20`
Expected: PASS (3 tests). If `testEveryEntryResolvesToARealNode` fails, the named target isn't a real node — fix the `targetName` to an exact taxonomy name (see Global Constraints node list / `EmotionTaxonomy.swift:72-158`).

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/NaturalLanguage/FeelingSynonyms.swift OpenFeelingsTests/FeelingSynonymsTests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Add original-MIT feeling synonym table + invariants"
```

---

## Task 4: `FeelingParser` protocol + `KeywordFeelingParser` + `FeelingParserProvider`

**Files:**
- Create: `OpenFeelings/NaturalLanguage/FeelingParser.swift`
- Test: `OpenFeelingsTests/FeelingParserTests.swift`

**Interfaces:**
- Consumes: `EmotionTaxonomy.node(named:)`, `FeelingSynonyms.entries`, `ParsedFeeling`.
- Produces: `protocol FeelingParser { func parse(_ text: String) async -> ParsedFeeling }`; `struct KeywordFeelingParser: FeelingParser` (declared `nonisolated`-friendly — pure, no actor state); `enum FeelingParserProvider { static func current() -> any FeelingParser }`.

**Resolution rules (from spec):** deepest match wins (specific > secondary > core); exact node-name hit or `.strong` synonym → `.high`; `.weak` synonym → `.low`; nothing → `.none`. Intensity: `n/5`, `n out of 5`, a bare `1-5`, or a word ladder (`a little→2`, `really/very→4`, `extremely→5`). Note: cleaned utterance (strip a leading "I feel/I'm/I am/feeling"); `rawUtterance` kept verbatim.

- [ ] **Step 1: Write the failing test (table-driven; one method per case)**

```swift
// OpenFeelingsTests/FeelingParserTests.swift
import XCTest
@testable import OpenFeelings

final class FeelingParserTests: XCTestCase {
    private let parser = KeywordFeelingParser()

    private func parse(_ s: String) async -> ParsedFeeling { await parser.parse(s) }

    func testExactSecondaryNameIsHigh() async {
        let r = await parse("I feel anxious about the demo")
        XCTAssertEqual(r.core?.name, "Fearful")
        XCTAssertEqual(r.secondary?.name, "Anxious")
        XCTAssertEqual(r.confidence, .high)
    }

    func testSpecificNameResolvesDeepest() async {
        let r = await parse("pretty nervous right now")
        XCTAssertEqual(r.specific?.name, "Nervous")
        XCTAssertEqual(r.confidence, .high)
    }

    func testStrongSynonymIsHigh() async {
        let r = await parse("I'm so mad")
        XCTAssertEqual(r.core?.name, "Angry")
        XCTAssertEqual(r.confidence, .high)
    }

    func testWeakSynonymIsLow() async {
        let r = await parse("feeling kind of off today")
        XCTAssertEqual(r.core?.name, "Sad")
        XCTAssertEqual(r.confidence, .low)
    }

    func testIntensitySlashForm() async {
        let r = await parse("anxious 4/5")
        XCTAssertEqual(r.intensity, 4)
    }

    func testIntensityWordLadder() async {
        let r = await parse("really sad")
        XCTAssertEqual(r.intensity, 4)
    }

    func testNoIntensityStatedIsNil() async {
        let r = await parse("a bit lonely")
        XCTAssertNil(r.intensity)
    }

    func testGarbageIsNoneButKeepsNote() async {
        let r = await parse("asdf qwer")
        XCTAssertNil(r.core)
        XCTAssertEqual(r.confidence, .none)
        XCTAssertEqual(r.rawUtterance, "asdf qwer")
        XCTAssertFalse(r.note.isEmpty)
    }

    func testNoteStripsLeadingIFeel() async {
        let r = await parse("I feel hopeful about next week")
        XCTAssertFalse(r.note.lowercased().hasPrefix("i feel"))
        XCTAssertEqual(r.core?.name, "Happy")
    }

    func testProviderReturnsKeywordParserInPhase1() {
        XCTAssertTrue(FeelingParserProvider.current() is KeywordFeelingParser)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/FeelingParserTests 2>&1 | tail -20`
Expected: FAIL — "cannot find 'KeywordFeelingParser' in scope".

- [ ] **Step 3: Write minimal implementation**

```swift
// OpenFeelings/NaturalLanguage/FeelingParser.swift
import Foundation

/// Turns one natural-language utterance into a ParsedFeeling. Async so the
/// Phase 2 Foundation Models parser conforms without changing call sites.
protocol FeelingParser {
    func parse(_ text: String) async -> ParsedFeeling
}

/// Phase 1 deterministic engine — also the permanent fallback. Pure value
/// type, no actor isolation, so `await parse(...)` is callable from anywhere.
struct KeywordFeelingParser: FeelingParser {
    func parse(_ text: String) async -> ParsedFeeling {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = raw.lowercased()

        let (core, secondary, specific, confidence) = resolveEmotion(in: lower)
        let intensity = scanIntensity(in: lower)
        let note = cleanedNote(from: raw)

        return ParsedFeeling(
            core: core, secondary: secondary, specific: specific,
            intensity: intensity, note: note,
            confidence: confidence, rawUtterance: raw
        )
    }

    // MARK: Emotion

    private func resolveEmotion(in lower: String)
        -> (EmotionCore?, EmotionSecondary?, EmotionSpecific?, ParsedFeeling.Confidence) {
        var best: (EmotionTaxonomy.ResolvedNode, depth: Int, ParsedFeeling.Confidence)?

        func consider(_ node: EmotionTaxonomy.ResolvedNode, _ confidence: ParsedFeeling.Confidence) {
            let depth = node.specific != nil ? 3 : (node.secondary != nil ? 2 : 1)
            if best == nil || depth > best!.depth {
                best = (node, depth, confidence)
            }
        }

        // Exact node-name hits (highest trust). Scan all names; longest-first
        // so "nervous" beats a bare core mention.
        for name in EmotionTaxonomy.allNodeNames.sorted(by: { $0.count > $1.count }) {
            if containsWord(name.lowercased(), in: lower), let node = EmotionTaxonomy.node(named: name) {
                consider(node, .high)
            }
        }
        // Synonyms.
        for entry in FeelingSynonyms.entries {
            if containsWord(entry.phrase, in: lower), let node = EmotionTaxonomy.node(named: entry.targetName) {
                consider(node, entry.strength == .strong ? .high : .low)
            }
        }

        guard let best else { return (nil, nil, nil, .none) }
        return (best.0.core, best.0.secondary, best.0.specific, best.2)
    }

    /// Word/phrase containment on token boundaries so "mad" doesn't match
    /// "nomad". Multi-word phrases ("on edge") match as substrings.
    private func containsWord(_ needle: String, in haystack: String) -> Bool {
        if needle.contains(" ") { return haystack.contains(needle) }
        let tokens = haystack.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return tokens.contains(needle)
    }

    // MARK: Intensity

    private func scanIntensity(in lower: String) -> Int? {
        // n/5 or "n out of 5"
        if let m = lower.range(of: #"([1-5])\s*(?:/|out of)\s*5"#, options: .regularExpression) {
            if let v = Int(lower[m].prefix(1)) { return v }
        }
        // bare standalone 1-5
        let tokens = lower.components(separatedBy: CharacterSet.alphanumerics.inverted)
        if let token = tokens.first(where: { ["1", "2", "3", "4", "5"].contains($0) }), let v = Int(token) {
            return v
        }
        // word ladder
        if lower.contains("extremely") || lower.contains("unbearabl") { return 5 }
        if lower.contains("really") || lower.contains("very") || lower.contains("so ") { return 4 }
        if lower.contains("a little") || lower.contains("a bit") || lower.contains("kind of") || lower.contains("slightly") { return 2 }
        return nil
    }

    // MARK: Note

    private func cleanedNote(from raw: String) -> String {
        let prefixes = ["i feel like ", "i feel ", "i'm feeling ", "im feeling ", "feeling ", "i am ", "i'm ", "im "]
        let lower = raw.lowercased()
        for p in prefixes where lower.hasPrefix(p) {
            return String(raw.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
        }
        return raw
    }
}

/// The single composition point both surfaces call. Phase 1 returns the
/// keyword parser; Phase 2 returns the Foundation Models parser (with the
/// keyword parser as its fallback).
enum FeelingParserProvider {
    static func current() -> any FeelingParser {
        KeywordFeelingParser()
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/FeelingParserTests 2>&1 | tail -20`
Expected: PASS (10 tests). If a case fails, adjust the synonym table or the scan — do **not** weaken the assertions.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/NaturalLanguage/FeelingParser.swift OpenFeelingsTests/FeelingParserTests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Add KeywordFeelingParser + FeelingParserProvider seam"
```

---

## Task 5: Shared `ModelContainer` hoist

**Files:**
- Create: `OpenFeelings/Services/OpenFeelingsModelContainer.swift`
- Modify: `OpenFeelings/OpenFeelingsApp.swift:44-48,57-134`
- Test: `OpenFeelingsTests/OpenFeelingsModelContainerTests.swift`

**Why:** `makeModelContainer()` builds a fresh CloudKit container per call; an AppIntent calling it again would create a **second** container over the same store — corruption risk. Hoist to one process-level instance both the app and the intent consume.

**Interfaces:**
- Produces: `enum OpenFeelingsModelContainer { static var shared: ModelContainer { get } }` — exactly one instance per process.

- [ ] **Step 1: Write the failing test**

```swift
// OpenFeelingsTests/OpenFeelingsModelContainerTests.swift
import SwiftData
import XCTest
@testable import OpenFeelings

final class OpenFeelingsModelContainerTests: XCTestCase {
    func testSharedReturnsSameInstance() {
        let a = OpenFeelingsModelContainer.shared
        let b = OpenFeelingsModelContainer.shared
        XCTAssertTrue(a === b, "Shared container must be a single instance")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/OpenFeelingsModelContainerTests 2>&1 | tail -20`
Expected: FAIL — "cannot find 'OpenFeelingsModelContainer' in scope".

- [ ] **Step 3: Write the implementation — move the factory body into the holder**

Create `OpenFeelings/Services/OpenFeelingsModelContainer.swift` with the **exact body** currently in `OpenFeelingsApp.makeModelContainer()` (`OpenFeelingsApp.swift:57-134`), wrapped as a lazy `static let`:

```swift
// OpenFeelings/Services/OpenFeelingsModelContainer.swift
import SwiftData
import Foundation

/// The single SwiftData container for the whole process. The app scene and
/// any AppIntent both read `shared` — never construct another container, or
/// two stores point at the same CloudKit zone.
enum OpenFeelingsModelContainer {
    static let shared: ModelContainer = make()

    private static func make() -> ModelContainer {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self,
            ThoughtRecord.self
        ])

        #if DEBUG
        if CommandLine.arguments.contains("-screenshotMode") {
            let screenshotConfiguration = ModelConfiguration(
                "OpenFeelingsScreenshots", schema: schema,
                isStoredInMemoryOnly: true, cloudKitDatabase: .none
            )
            do {
                let container = try ModelContainer(for: schema, configurations: [screenshotConfiguration])
                ScreenshotDemoSeeder.seed(into: container.mainContext)
                return container
            } catch {
                fatalError("Unable to create Open Feelings screenshot model container: \(error)")
            }
        }
        #endif

        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let testConfiguration = ModelConfiguration(
                "OpenFeelingsTests", schema: schema,
                isStoredInMemoryOnly: true, cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [testConfiguration])
            } catch {
                fatalError("Unable to create Open Feelings test model container: \(error)")
            }
        }

        #if targetEnvironment(simulator)
        let simulatorConfiguration = ModelConfiguration(
            "OpenFeelingsSimulator", schema: schema, cloudKitDatabase: .none
        )
        do {
            return try ModelContainer(for: schema, configurations: [simulatorConfiguration])
        } catch {
            fatalError("Unable to create Open Feelings simulator model container: \(error)")
        }
        #else
        let cloudConfiguration = ModelConfiguration(
            "OpenFeelingsCloud", schema: schema,
            cloudKitDatabase: .private("iCloud.dev.finklea.openfeelings")
        )
        do {
            return try ModelContainer(for: schema, configurations: [cloudConfiguration])
        } catch {
            let localConfiguration = ModelConfiguration(
                "OpenFeelingsLocal", schema: schema, cloudKitDatabase: .none
            )
            do {
                return try ModelContainer(for: schema, configurations: [localConfiguration])
            } catch {
                fatalError("Unable to create Open Feelings model container: \(error)")
            }
        }
        #endif
    }
}
```

Then in `OpenFeelingsApp.swift`, **delete** the `private static func makeModelContainer()` method (lines 57-134) and change the `.task` body (lines 44-48) to consume the shared instance:

```swift
// OpenFeelingsApp.swift — replace the `if modelContainer == nil { ... }` block
                if modelContainer == nil {
                    let container = OpenFeelingsModelContainer.shared
                    modelContainer = container
                    watchSyncService?.attach(modelContainer: container)
                }
```

- [ ] **Step 4: Run test + build to verify**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/OpenFeelingsModelContainerTests 2>&1 | tail -20`
Expected: PASS (1 test). Confirm the app still builds: `xcodebuild build -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5` → `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/Services/OpenFeelingsModelContainer.swift OpenFeelings/OpenFeelingsApp.swift OpenFeelingsTests/OpenFeelingsModelContainerTests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Hoist SwiftData container to single shared instance"
```

---

## Task 6: `FeelingLogService` + `CheckInView.save()` refactor

**Files:**
- Create: `OpenFeelings/Services/FeelingLogService.swift`
- Modify: `OpenFeelings/Views/CheckInView.swift:234-270`
- Test: `OpenFeelingsTests/FeelingLogServiceTests.swift`

**Interfaces:**
- Consumes: `CheckInDraft`, `FeelingLog`, `HealthService.save(log:isEnabled:) async -> HealthSyncStatus`.
- Produces: `enum FeelingLogService` with `@MainActor static func persist(draft:captureSource:into:healthEnabled:) -> FeelingLog?` and `@MainActor static func syncHealth(_:healthService:healthEnabled:into:) async`.

- [ ] **Step 1: Write the failing test**

```swift
// OpenFeelingsTests/FeelingLogServiceTests.swift
import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class FeelingLogServiceTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([FeelingLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private var draft: CheckInDraft {
        var d = CheckInDraft()
        d.selection = EmotionTaxonomy.selection(coreID: "fearful", secondaryID: "anxious", specificID: nil)
        d.note = "  before the demo  "
        d.includeIntensity = true
        d.intensity = 4
        d.customBodyRegionIDs = [UUID()]
        return d
    }

    func testPersistInsertsOneLogWithCaptureSourceAndTrimmedNote() throws {
        let ctx = try makeContext()
        let log = FeelingLogService.persist(draft: draft, captureSource: "siri", into: ctx, healthEnabled: false)
        XCTAssertNotNil(log)
        XCTAssertEqual(log?.captureSource, "siri")
        XCTAssertEqual(log?.note, "before the demo")
        XCTAssertEqual(log?.intensity, 4)
        XCTAssertEqual(log?.healthSyncStatus, .notRequested)
        let all = try ctx.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(all.count, 1)
    }

    func testPersistRoundTripsCustomBodyRegionIDs() throws {
        let ctx = try makeContext()
        let d = draft
        let log = FeelingLogService.persist(draft: d, captureSource: "quickentry", into: ctx, healthEnabled: false)
        XCTAssertEqual(Set(log!.customBodyRegionIDs), d.customBodyRegionIDs)
    }

    func testPersistPendingWhenHealthEnabled() throws {
        let ctx = try makeContext()
        let log = FeelingLogService.persist(draft: draft, captureSource: "phone", into: ctx, healthEnabled: true)
        XCTAssertEqual(log?.healthSyncStatus, .pending)
    }

    func testPersistReturnsNilForIncompleteSelection() throws {
        let ctx = try makeContext()
        let log = FeelingLogService.persist(draft: CheckInDraft(), captureSource: "phone", into: ctx, healthEnabled: false)
        XCTAssertNil(log)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FeelingLog>()).count, 0)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/FeelingLogServiceTests 2>&1 | tail -20`
Expected: FAIL — "cannot find 'FeelingLogService' in scope".

- [ ] **Step 3a: Write the service** (mirrors `CheckInView.save()` field mapping at `CheckInView.swift:237-256` exactly, plus `captureSource` via the existing init param and the `customBodyRegionIDs` post-construction line)

```swift
// OpenFeelings/Services/FeelingLogService.swift
import SwiftData
import Foundation

/// One shared new-entry persistence path for every surface (wizard, quick
/// entry, Siri). Pure persistence: builds + inserts + first-saves the log and
/// returns it with `.pending`/`.notRequested`. Navigation and the (slow,
/// possibly permission-bound) HealthKit write are the caller's to schedule —
/// `syncHealth` is provided for that second phase.
enum FeelingLogService {
    @MainActor
    @discardableResult
    static func persist(
        draft: CheckInDraft,
        captureSource: String,
        into context: ModelContext,
        healthEnabled: Bool
    ) -> FeelingLog? {
        guard let selection = draft.selection, selection.isComplete else { return nil }
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
            moodValence: draft.includeMoodScale ? draft.moodValence : nil,
            captureSource: captureSource
        )
        // The main init builds from an EmotionSelection and has no slot for raw
        // custom-region IDs, so set them after construction (mirrors CheckInView).
        log.customBodyRegionIDs = Array(draft.customBodyRegionIDs)
        context.insert(log)
        try? context.save()
        return log
    }

    @MainActor
    static func syncHealth(
        _ log: FeelingLog,
        healthService: HealthService,
        healthEnabled: Bool,
        into context: ModelContext
    ) async {
        log.healthSyncStatus = await healthService.save(log: log, isEnabled: healthEnabled)
        try? context.save()
    }
}
```

- [ ] **Step 3b: Refactor `CheckInView.save()`** — replace the whole method body (`CheckInView.swift:234-270`) with:

```swift
    private func save() {
        guard let log = FeelingLogService.persist(
            draft: draft, captureSource: "phone",
            into: modelContext, healthEnabled: healthEnabled
        ) else { return }
        draft.reset()
        stepIndex = 0
        dismissedNudgeRegions.removeAll()

        navigation.ribbonAfterSave()
        withAnimation(reduceMotion ? nil : .OF.gentle) {
            navigation.select(.today)
        }

        Task { @MainActor in
            await FeelingLogService.syncHealth(
                log, healthService: healthService,
                healthEnabled: healthEnabled, into: modelContext
            )
        }
    }
```

- [ ] **Step 4: Run tests + the existing check-in tests to verify behavior preserved**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/FeelingLogServiceTests -only-testing:OpenFeelingsTests/CheckInDraftEditTests 2>&1 | tail -20`
Expected: PASS (4 new + existing CheckInDraftEdit tests). Confirm a full build too.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/Services/FeelingLogService.swift OpenFeelings/Views/CheckInView.swift OpenFeelingsTests/FeelingLogServiceTests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Extract FeelingLogService; refactor CheckInView.save (behavior-preserving)"
```

---

## Task 7: `captureSource` glyph + AX for `"siri"` and `"quickentry"`

**Files:**
- Modify: `OpenFeelings/Views/TodayView.swift:151-157,266-268`
- Modify: `OpenFeelings/Views/HistoryView.swift:316-322,367-369`
- Modify: `OpenFeelings/Views/CheckInEditView.swift:87-91`
- Test: `OpenFeelingsTests/TodayViewAXTests.swift`, `OpenFeelingsTests/HistoryViewAXTests.swift`

**Glyphs:** `"siri"` → `"mic.fill"` / "From Siri"; `"quickentry"` → `"text.bubble.fill"` / "From quick entry".

- [ ] **Step 1: Write the failing AX tests** (append to existing files; mirror the `"watch"` cases at `TodayViewAXTests.swift:38-42` / `HistoryViewAXTests.swift:32-40`)

```swift
// Append to OpenFeelingsTests/TodayViewAXTests.swift inside the test class
    func testTodayAXLabelIncludesSiriSource() {
        let log = FeelingLog(selection: EmotionTaxonomy.selection(coreID: "happy", secondaryID: nil, specificID: nil)!,
                             intensity: nil, note: "", captureSource: "siri")
        XCTAssertTrue(TodayView.todayLogAXLabel(for: log).contains("from Siri"))
    }

    func testTodayAXLabelIncludesQuickEntrySource() {
        let log = FeelingLog(selection: EmotionTaxonomy.selection(coreID: "happy", secondaryID: nil, specificID: nil)!,
                             intensity: nil, note: "", captureSource: "quickentry")
        XCTAssertTrue(TodayView.todayLogAXLabel(for: log).contains("from quick entry"))
    }
```

```swift
// Append to OpenFeelingsTests/HistoryViewAXTests.swift inside the test class.
// Helper is `nonisolated static func cardAXLabel(for:)` (HistoryView.swift:357).
    func testHistoryAXLabelIncludesSiriSource() {
        let log = FeelingLog(selection: EmotionTaxonomy.selection(coreID: "happy", secondaryID: nil, specificID: nil)!,
                             intensity: nil, note: "", captureSource: "siri")
        XCTAssertTrue(HistoryView.cardAXLabel(for: log).contains("from Siri"))
    }
```

- [ ] **Step 2: Run to verify they fail**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/TodayViewAXTests 2>&1 | tail -20`
Expected: FAIL on the two new assertions ("from Siri" not found).

- [ ] **Step 3: Add the source branches.** In each of the three visual sites, extend the `if log.captureSource == "watch" { ... }` block with `else if` arms. Example for `TodayView.swift:151-157`:

```swift
                if log.captureSource == "watch" {
                    Label("Apple Watch", systemImage: "applewatch")
                        .labelStyle(.iconOnly).font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                        .accessibilityLabel("From Apple Watch")
                } else if log.captureSource == "siri" {
                    Label("Siri", systemImage: "mic.fill")
                        .labelStyle(.iconOnly).font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                        .accessibilityLabel("From Siri")
                } else if log.captureSource == "quickentry" {
                    Label("Quick entry", systemImage: "text.bubble.fill")
                        .labelStyle(.iconOnly).font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                        .accessibilityLabel("From quick entry")
                }
```

Mirror the same three-way shape at `HistoryView.swift:316-322` and (without `.labelStyle(.iconOnly)`, matching the existing code) `CheckInEditView.swift:87-91`. In the two AX-label helpers (`TodayView.swift:266-268`, `HistoryView.swift:367-369`) extend:

```swift
        if log.captureSource == "watch" {
            parts.append("from Apple Watch")
        } else if log.captureSource == "siri" {
            parts.append("from Siri")
        } else if log.captureSource == "quickentry" {
            parts.append("from quick entry")
        }
```

- [ ] **Step 4: Run to verify they pass**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/TodayViewAXTests -only-testing:OpenFeelingsTests/HistoryViewAXTests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add OpenFeelings/Views/TodayView.swift OpenFeelings/Views/HistoryView.swift OpenFeelings/Views/CheckInEditView.swift OpenFeelingsTests/TodayViewAXTests.swift OpenFeelingsTests/HistoryViewAXTests.swift
git commit -m "Render siri + quickentry capture sources (glyph + AX)"
```

---

## Task 8: `PendingQuickEntryStore`

**Files:**
- Create: `OpenFeelings/NaturalLanguage/PendingQuickEntryStore.swift`
- Test: `OpenFeelingsTests/PendingQuickEntryStoreTests.swift`

**Interfaces:**
- Produces: `struct PendingQuickEntryStore { init(defaults:); func stash(_ note: String); func take() -> String? }` — durable across processes (the Siri intent writes; the app reads on launch).

- [ ] **Step 1: Write the failing test**

```swift
// OpenFeelingsTests/PendingQuickEntryStoreTests.swift
import XCTest
@testable import OpenFeelings

final class PendingQuickEntryStoreTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let d = UserDefaults(suiteName: "pending-test-\(UUID().uuidString)")!
        return d
    }

    func testStashThenTakeReturnsNoteOnce() {
        let store = PendingQuickEntryStore(defaults: freshDefaults())
        store.stash("anxious about nothing in particular")
        XCTAssertEqual(store.take(), "anxious about nothing in particular")
        XCTAssertNil(store.take(), "take() must clear after reading")
    }

    func testTakeWhenEmptyIsNil() {
        XCTAssertNil(PendingQuickEntryStore(defaults: freshDefaults()).take())
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/PendingQuickEntryStoreTests 2>&1 | tail -20`
Expected: FAIL — "cannot find 'PendingQuickEntryStore' in scope".

- [ ] **Step 3: Write the implementation**

```swift
// OpenFeelings/NaturalLanguage/PendingQuickEntryStore.swift
import Foundation

/// Hands a pending utterance from the Siri intent (when it couldn't resolve a
/// feeling) to the app, which consumes it on launch/foreground and opens
/// QuickEntry pre-filled. Durable (UserDefaults) because the Shortcut may run
/// in a different process / cold-launch the app.
struct PendingQuickEntryStore {
    private let defaults: UserDefaults
    private let key = "pendingQuickEntryNote"

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

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/PendingQuickEntryStoreTests 2>&1 | tail -20`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/NaturalLanguage/PendingQuickEntryStore.swift OpenFeelingsTests/PendingQuickEntryStoreTests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Add PendingQuickEntryStore for Siri→app hand-off"
```

---

## Task 9: Extract `IntensityDots` from `StrengthStep`

**Files:**
- Create: `OpenFeelings/Views/CheckInWizard/Steps/IntensityDots.swift`
- Modify: `OpenFeelings/Views/CheckInWizard/Steps/StrengthStep.swift`

**Why:** The Quick Entry review needs the 1-5 dots without `StrengthStep`'s caption row + card chrome. Extract the dots into a reusable subview; `StrengthStep` embeds it (no behavior change).

- [ ] **Step 1: Create `IntensityDots`** — move the dots row + helpers verbatim from `StrengthStep`:

```swift
// OpenFeelings/Views/CheckInWizard/Steps/IntensityDots.swift
import SwiftUI

/// The five tappable intensity circles (1...5), bound to a CheckInDraft.
/// Tapping a circle sets intensity to that value; tapping the selected circle
/// again clears it. Extracted from StrengthStep so QuickEntry can reuse it.
struct IntensityDots: View {
    @Binding var draft: CheckInDraft

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let sizes: [CGFloat] = [28, 33, 38, 43, 48]

    private var coreColor: Color {
        if let id = draft.selection?.core.id {
            return EmotionColorPalette.color(coreID: id, depth: .core, scheme: colorScheme)
        }
        return Color.OF.accent.color(for: colorScheme)
    }

    var body: some View {
        HStack(spacing: .OF.sm) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    toggle(value)
                } label: {
                    circle(for: value)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Intensity \(value)")
                .accessibilityAddTraits(isFilled(value) ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func circle(for value: Int) -> some View {
        let size = sizes[value - 1]
        ZStack {
            if isSelectedLevel(value) {
                Circle()
                    .fill(coreColor.opacity(reduceTransparency ? 0 : 0.18))
                    .frame(width: size + 10, height: size + 10)
                Circle()
                    .stroke(coreColor.opacity(reduceTransparency ? 0.9 : 0.4), lineWidth: 2)
                    .frame(width: size + 10, height: size + 10)
            }
            Circle()
                .fill(isFilled(value) ? AnyShapeStyle(coreColor) : AnyShapeStyle(Color.OF.divider))
                .frame(width: size, height: size)
        }
    }

    private func isFilled(_ value: Int) -> Bool {
        draft.includeIntensity && Int(draft.intensity.rounded()) >= value
    }

    private func isSelectedLevel(_ value: Int) -> Bool {
        draft.includeIntensity && Int(draft.intensity.rounded()) == value
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

- [ ] **Step 2: Slim `StrengthStep`** — replace its `body` and delete the now-moved helpers (`sizes`, `coreColor`, `circle(for:)`, `isFilled`, `isSelectedLevel`, `toggle`):

```swift
// StrengthStep.swift — new body; keep the struct + @Binding var draft
    var body: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            IntensityDots(draft: $draft)
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
```

After this, `StrengthStep` no longer needs `@Environment(\.colorScheme)` / `@Environment(\.accessibilityReduceTransparency)` — remove them.

- [ ] **Step 3: Verify the build + existing UI**

Run: `xcodebuild build -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`. (StrengthStep is view code; the dots logic is unchanged — covered by the existing wizard UI tests and verified visually in Task 11's UI test.)

- [ ] **Step 4: Run the full wizard UI smoke to confirm no regression**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsUITests/OpenFeelingsUITests 2>&1 | tail -20`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/Views/CheckInWizard/Steps/IntensityDots.swift OpenFeelings/Views/CheckInWizard/Steps/StrengthStep.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Extract reusable IntensityDots from StrengthStep"
```

---

## Task 10: `QuickEntryView` + navigation wiring + Today entry point

**Files:**
- Create: `OpenFeelings/Views/QuickEntryView.swift`
- Modify: `OpenFeelings/Design/AppNavigation.swift:74` (add state)
- Modify: `OpenFeelings/Views/RootView.swift:54-56` (present + consume pending)
- Modify: `OpenFeelings/Views/TodayView.swift` (entry button)
- Test: `OpenFeelingsUITests/QuickEntryUITests.swift`

**Interfaces:**
- Consumes: `FeelingParserProvider.current()`, `ParsedFeeling.toDraft()`, `FeelingLogService`, `FeelingStep`, `IntensityDots`, `PendingQuickEntryStore`, `AppNavigation`.
- Produces: `QuickEntryView(seededNote: String? = nil)`; `AppNavigation.showingQuickEntry: Bool`, `AppNavigation.quickEntrySeed: String?`.

- [ ] **Step 1: Add navigation state** — in `AppNavigation` (after `showingSettings`, line 74):

```swift
    /// Drives the modal Quick Entry sheet (natural-language check-in).
    var showingQuickEntry = false
    /// When set, Quick Entry opens straight into Review seeded with this note
    /// (used by the Siri hand-off when no feeling could be resolved).
    var quickEntrySeed: String?
```

- [ ] **Step 2: Write the QuickEntryView** (capture → review). Reuses `FeelingStep` with no-op closures (matching `CheckInEditView.swift:103-109`) and `IntensityDots`.

```swift
// OpenFeelings/Views/QuickEntryView.swift
import SwiftData
import SwiftUI

/// Natural-language quick entry. Type or dictate one sentence → parse → a
/// compact Review of the three core fields → save. Seeded mode (from the Siri
/// hand-off) parses an incoming note and opens straight into Review.
struct QuickEntryView: View {
    let seededNote: String?

    @Environment(\.modelContext) private var modelContext
    @Environment(HealthService.self) private var healthService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss
    @AppStorage("healthEnabled") private var healthEnabled = false

    @State private var phase: Phase = .capture
    @State private var text = ""
    @State private var draft = CheckInDraft()

    private enum Phase { case capture, review }

    init(seededNote: String? = nil) {
        self.seededNote = seededNote
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                switch phase {
                case .capture: captureView
                case .review: reviewView
                }
            }
            .padding(.horizontal, .OF.lg)
            .padding(.vertical, .OF.lg)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .navigationTitle("Quick entry")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("quickentry.view")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        }
        .task {
            if let seededNote { await runParse(on: seededNote) }
        }
    }

    // MARK: Capture

    private var captureView: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            Text("Say how you feel")
                .ofTitle().foregroundStyle(Color.OF.text)
            Text("Type or tap the mic — e.g. \u{201C}anxious about the demo, 4/5\u{201D}.")
                .font(.OF.caption).foregroundStyle(Color.OF.textMuted)
            TextEditor(text: $text)
                .font(.OF.body).foregroundStyle(Color.OF.text)
                .frame(minHeight: 140)
                .scrollContentBackground(.hidden)
                .padding(CGFloat.OF.md)
                .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card).stroke(Color.OF.divider, lineWidth: 1)
                }
                .accessibilityIdentifier("quickentry.field")
            Button {
                Task { await runParse(on: text) }
            } label: {
                Text("Continue").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("quickentry.continue")
        }
    }

    // MARK: Review

    private var reviewView: some View {
        VStack(alignment: .leading, spacing: .OF.xl) {
            Text("Does this look right?")
                .ofTitle().foregroundStyle(Color.OF.text)
            FeelingStep(draft: $draft, suggestedCoreIDs: [], nudge: nil, onSaveOverride: { _, _ in }, onDismissNudge: {})
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("How strong?").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                IntensityDots(draft: $draft)
            }
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Note").font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                TextEditor(text: $draft.note)
                    .font(.OF.body).foregroundStyle(Color.OF.text)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(CGFloat.OF.md)
                    .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                    .accessibilityLabel("Note")
            }
            Button {
                save()
            } label: {
                Text("Save").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!draft.canSave)
            .accessibilityIdentifier("quickentry.save")
        }
    }

    // MARK: Actions

    private func runParse(on input: String) async {
        let parsed = await FeelingParserProvider.current().parse(input)
        draft = parsed.toDraft()
        phase = .review
    }

    private func save() {
        guard let log = FeelingLogService.persist(
            draft: draft, captureSource: "quickentry",
            into: modelContext, healthEnabled: healthEnabled
        ) else { return }
        navigation.ribbonAfterSave()
        navigation.select(.today)
        Task { @MainActor in
            await FeelingLogService.syncHealth(log, healthService: healthService, healthEnabled: healthEnabled, into: modelContext)
        }
        dismiss()
    }
}
```

- [ ] **Step 3: Present + consume pending in RootView** — replace the `.sheet(isPresented: $navigation.showingSettings)` block (`RootView.swift:54-56`) tail with both sheets + pending consumption:

```swift
        .sheet(isPresented: $navigation.showingSettings) {
            NavigationStack { SettingsView() }
        }
        .sheet(isPresented: $navigation.showingQuickEntry) {
            NavigationStack { QuickEntryView(seededNote: navigation.quickEntrySeed) }
                .onDisappear { navigation.quickEntrySeed = nil }
        }
        .task { consumePendingQuickEntry() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumePendingQuickEntry() }
        }
```

Add at the top of `RootView` (after the existing `@Environment(AppNavigation.self)`):

```swift
    @Environment(\.scenePhase) private var scenePhase

    private func consumePendingQuickEntry() {
        if let note = PendingQuickEntryStore().take() {
            navigation.quickEntrySeed = note
            navigation.showingQuickEntry = true
        }
    }
```

- [ ] **Step 4: Add the Today entry button** — in `TodayView.body`, insert a button right after `header` (line 25), so it shows in both empty and populated states:

```swift
                header
                Button {
                    navigation.quickEntrySeed = nil
                    navigation.showingQuickEntry = true
                } label: {
                    HStack(spacing: .OF.sm) {
                        Image(systemName: "text.bubble.fill")
                        Text("Say how you feel")
                        Spacer()
                    }
                    .font(.OF.body).foregroundStyle(Color.OF.text)
                    .padding(CGFloat.OF.md)
                    .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: CGFloat.OF.Radius.card))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("today.quickEntry")
```

- [ ] **Step 5: Write the UI smoke test**

```swift
// OpenFeelingsUITests/QuickEntryUITests.swift
import XCTest

final class QuickEntryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTestingMode", "1"]
        app.launch()
    }

    private func el(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    func testQuickEntryCaptureToReviewToSave() {
        let button = el("today.quickEntry")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()

        let field = el("quickentry.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("really anxious about the demo")

        el("quickentry.continue").tap()

        let save = el("quickentry.save")
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        // Lands back on Today; the saved ribbon or the new entry is visible.
        XCTAssertTrue(el("today.quickEntry").waitForExistence(timeout: 5))
    }
}
```

- [ ] **Step 6: Run the UI test**

Run: `xcodegen generate && xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsUITests/QuickEntryUITests 2>&1 | tail -25`
Expected: PASS. (If the Today tab's AX tree needs a tap first per the Liquid-Glass quirk noted in `current-state.md`, the test already starts on Today so `today.quickEntry` is reachable.)

- [ ] **Step 7: Commit**

```bash
git add OpenFeelings/Views/QuickEntryView.swift OpenFeelings/Design/AppNavigation.swift OpenFeelings/Views/RootView.swift OpenFeelings/Views/TodayView.swift OpenFeelingsUITests/QuickEntryUITests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Add QuickEntryView + Today entry point + Siri-seed consumption"
```

---

## Task 11: `LogFeelingIntent` + `AppShortcutsProvider`

**Files:**
- Create: `OpenFeelings/AppIntents/LogFeelingIntent.swift`
- Create: `OpenFeelings/AppIntents/OpenFeelingsShortcuts.swift`
- Test: `OpenFeelingsTests/LogFeelingIntentTests.swift`

**Interfaces:**
- Consumes: `FeelingParserProvider`, `ParsedFeeling`, `FeelingLogService`, `OpenFeelingsModelContainer.shared`, `HealthService`, `PendingQuickEntryStore`, `EmotionSelection.title`.
- Produces: `struct LogFeelingIntent: AppIntent` with an injectable context seam for tests; `struct OpenFeelingsShortcuts: AppShortcutsProvider`.

> **VERIFY-AGAINST-DOCS (the one uncertain API):** how an `AppIntent` conditionally opens the app from `perform()` for the `.none` branch. Recommended pattern below uses a second tiny intent forwarded via `opensIntent:`. Confirm the `opensIntent:`/`openAppWhenRun` surface against current AppIntents docs for iOS 26 before relying on it, and cover the open behavior with the manual check in Task 13 (it cannot be unit-tested).

- [ ] **Step 1: Write the failing test** (injects an in-memory context; covers save + the `.none` no-save path)

```swift
// OpenFeelingsTests/LogFeelingIntentTests.swift
import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class LogFeelingIntentTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([FeelingLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testHighConfidenceSavesSiriLog() async throws {
        let ctx = try makeContext()
        let outcome = await LogFeelingIntent.run(phrase: "anxious about the demo 4/5", context: ctx, healthEnabled: false)
        let logs = try ctx.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.captureSource, "siri")
        XCTAssertEqual(logs.first?.intensity, 4)
        if case .saved = outcome {} else { XCTFail("expected .saved, got \(outcome)") }
    }

    func testNoneSavesNothingAndStashesPending() async throws {
        let ctx = try makeContext()
        let defaults = UserDefaults(suiteName: "intent-test-\(UUID().uuidString)")!
        let outcome = await LogFeelingIntent.run(phrase: "asdf qwer", context: ctx, healthEnabled: false,
                                                 pending: PendingQuickEntryStore(defaults: defaults))
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FeelingLog>()).count, 0)
        XCTAssertEqual(PendingQuickEntryStore(defaults: defaults).take(), "asdf qwer")
        if case .handedOff = outcome {} else { XCTFail("expected .handedOff, got \(outcome)") }
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/LogFeelingIntentTests 2>&1 | tail -20`
Expected: FAIL — "cannot find 'LogFeelingIntent' in scope".

- [ ] **Step 3: Write the intent.** The testable core is the static `run(...)`; `perform()` wires it to the shared container + Siri dialog/app-open.

```swift
// OpenFeelings/AppIntents/LogFeelingIntent.swift
import AppIntents
import SwiftData

struct LogFeelingIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a feeling"
    static var description = IntentDescription("Save how you're feeling in plain language.")
    // Default: do not open the app. The .none branch opens it via opensIntent.
    static var openAppWhenRun = false

    @Parameter(title: "How are you feeling?")
    var phrase: String

    /// Pure, testable core. Parses, and either saves a "siri" log or stashes
    /// the utterance for the in-app hand-off. Returns what happened + a line.
    enum Outcome: Equatable {
        case saved(spoken: String)
        case handedOff(spoken: String)
    }

    @MainActor
    static func run(
        phrase: String,
        context: ModelContext,
        healthEnabled: Bool,
        healthService: HealthService? = nil,
        pending: PendingQuickEntryStore = PendingQuickEntryStore()
    ) async -> Outcome {
        let parsed = await FeelingParserProvider.current().parse(phrase)
        guard parsed.core != nil else {
            pending.stash(parsed.rawUtterance)
            return .handedOff(spoken: "Let's finish this in the app.")
        }
        let draft = parsed.toDraft()
        guard let log = FeelingLogService.persist(
            draft: draft, captureSource: "siri", into: context, healthEnabled: healthEnabled
        ) else {
            // Defensive: a resolved core should always yield a complete selection.
            pending.stash(parsed.rawUtterance)
            return .handedOff(spoken: "Let's finish this in the app.")
        }
        if let healthService {
            await FeelingLogService.syncHealth(log, healthService: healthService, healthEnabled: healthEnabled, into: context)
        }
        let title = draft.selection?.title ?? log.emotionTitle
        let spoken: String
        if parsed.confidence == .high {
            let level = parsed.intensity.map { ", intensity \($0)" } ?? ""
            spoken = "Logged: \(title)\(level). Open the app to add more."
        } else {
            spoken = "Saved your note under \(title) — open the app to pin down the feeling."
        }
        return .saved(spoken: spoken)
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContext(OpenFeelingsModelContainer.shared)
        let healthEnabled = UserDefaults.standard.bool(forKey: "healthEnabled")
        let outcome = await Self.run(
            phrase: phrase, context: context, healthEnabled: healthEnabled,
            healthService: HealthService()
        )
        switch outcome {
        case .saved(let spoken):
            return .result(dialog: IntentDialog(stringLiteral: spoken))
        case .handedOff(let spoken):
            // Open the app to QuickEntry (it consumes PendingQuickEntryStore on
            // foreground). VERIFY opensIntent against current AppIntents docs.
            return .result(opensIntent: OpenQuickEntryIntent(), dialog: IntentDialog(stringLiteral: spoken))
        }
    }
}

/// Tiny app-opening intent the .none branch forwards to. Opening the app lets
/// RootView consume the pending utterance and present QuickEntry pre-filled.
struct OpenQuickEntryIntent: AppIntent {
    static var title: LocalizedStringResource = "Finish a feeling in the app"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // No-op: opening the app triggers RootView's pending consumption.
        .result()
    }
}
```

```swift
// OpenFeelings/AppIntents/OpenFeelingsShortcuts.swift
import AppIntents

struct OpenFeelingsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFeelingIntent(),
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

> If the `.result(opensIntent:dialog:)` combined overload doesn't exist in the SDK, fall back to: stash pending, `return .result(opensIntent: OpenQuickEntryIntent())` (drop the dialog), and let `OpenQuickEntryIntent` carry the spoken line. Keep `Self.run(...)` unchanged — only `perform()` adapts.

- [ ] **Step 4: Run the test**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:OpenFeelingsTests/LogFeelingIntentTests 2>&1 | tail -25`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
xcodegen generate
git add OpenFeelings/AppIntents OpenFeelingsTests/LogFeelingIntentTests.swift project.pbxproj OpenFeelings.xcodeproj
git commit -m "Add LogFeelingIntent + AppShortcuts (Siri natural-language entry)"
```

---

## Task 12: Privacy disclosure pass

**Files:**
- Modify: `PRIVACY.md:27`
- Modify: `OpenFeelings/Views/PrivacyPolicyView.swift:47`
- Modify: `web/src/routes/privacy/+page.svelte:44`
- Modify: `docs/release/privacy-policy-draft.md:27`
- Modify: `docs/release/app-store-privacy-answers.md` (re-verification note)

**Why:** All four surfaces claim the app accesses no microphone. Adding a Siri/dictation surface needs a one-line clarification that voice is handled by Apple's Siri / keyboard dictation, not the app (which still calls no microphone/Speech API). The "Data Not Collected" posture is unchanged.

- [ ] **Step 1: Read the current "no microphone" sentence** in each of the four files (around the cited lines) so the new clarifying sentence matches each one's voice/format.

Run: `rg -n "microphone" PRIVACY.md OpenFeelings/Views/PrivacyPolicyView.swift web/src/routes/privacy/+page.svelte docs/release/privacy-policy-draft.md`

- [ ] **Step 2: Add a clarifying sentence** to each surface near the "no microphone" claim, in that file's existing style, conveying:

> "Open Feelings never records audio. If you use Siri or keyboard dictation to enter a check-in, your speech is processed by Apple's system services (Siri/dictation), not by Open Feelings — the app receives only the resulting text and still uses no microphone or speech-recognition APIs."

Keep each surface's wording consistent with its siblings (per the repo's lockstep privacy convention — see `reference_privacy_artifacts`).

- [ ] **Step 3: Update the re-verification doc** — in `docs/release/app-store-privacy-answers.md`, add a dated line under the trigger list noting the Siri/dictation surface was reviewed on 2026-06-26 and "Data Not Collected" still holds (the app receives text only; no new data category is collected).

- [ ] **Step 4: Verify the four prose surfaces match**

Run: `rg -n "Siri" PRIVACY.md OpenFeelings/Views/PrivacyPolicyView.swift web/src/routes/privacy/+page.svelte docs/release/privacy-policy-draft.md`
Expected: each file now contains the clarifying Siri/dictation sentence.

- [ ] **Step 5: Commit**

```bash
git add PRIVACY.md OpenFeelings/Views/PrivacyPolicyView.swift web/src/routes/privacy/+page.svelte docs/release/privacy-policy-draft.md docs/release/app-store-privacy-answers.md
git commit -m "Privacy: disclose Siri/dictation is OS-handled, app records no audio"
```

---

## Task 13: Integration gate — full suite + manual Siri/container checks

**Files:** none (verification only).

- [ ] **Step 1: Regenerate + full build**

Run: `xcodegen generate && xcodebuild build -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -5`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 2: Full unit + UI suite**

Run: `xcodebuild test -scheme OpenFeelings -destination 'platform=iOS Simulator,name=iPhone 16' 2>&1 | tail -30`
Expected: all tests PASS (the existing suite + all new tests from Tasks 1-11). Investigate any failure before proceeding — do not weaken assertions.

- [ ] **Step 3: Manual check — in-app quick entry (real container).** Launch the app in the simulator. Today → "Say how you feel" → type "really anxious about the demo, 4/5" → Continue → Review shows Fearful/Anxious, intensity 4, the note → Save → entry appears on Today with the "Quick entry" glyph.

- [ ] **Step 4: Manual check — Siri hand-off + shared container (cannot be unit-tested).** With the app installed on a device/sim that supports App Shortcuts:
  - Run the "Log a feeling in Open Feelings" shortcut with "I'm so frustrated, 3 out of 5" → it saves a `"siri"` entry and speaks the read-back; open the app → the entry is on Today/History (proves the shared container is the same one the UI reads).
  - Run the shortcut with unrecognizable input ("asdf qwer") → the app opens to Quick Entry Review with the note pre-filled and no emotion (proves the `.none` hand-off + `opensIntent` open behavior).
  - If the open-app behavior doesn't fire, apply the `perform()` fallback noted in Task 11 Step 3 and re-verify.

- [ ] **Step 5: Update handoff docs + final commit.** Mark this feature's roadmap item, add a `current-state.md` summary, and note any Phase-2 follow-up. Commit.

```bash
git add .docs/ai
git commit -m "Handoff: natural-language entry Phase 1 complete"
```

---

## Phase 2 (separate plan, later)

`FoundationModelsFeelingParser` behind the same `FeelingParser` protocol, returned by `FeelingParserProvider.current()` when `SystemLanguageModel` is available + Apple Intelligence is on + hardware supports it, else the keyword parser. Must pass `FeelingParserTests` (tolerating equally-valid node choices) plus a fallback-delegation test. iOS 26 target already supports it — no deployment bump. Not prescribed here; read Apple's current `FoundationModels` API at implementation time.
