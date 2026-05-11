# Spec: Wizard chip accessibility identifiers + a smoke UI test

> **Tier hint:** Haiku. Single small change to `OFChip` (auto-deriving an
> identifier from the label), unlocking robust UI-test selectors for every
> wizard step that uses chips. One smoke UI test added to exercise the
> new identifiers.

## Context

The Check In wizard's chip-driven steps (Body, Sensations, Context,
Triggers, Coping) all render their pickers via `OFChip(label:isOn:)`.
None of the chips currently expose an `.accessibilityIdentifier`, which
means UI tests can't target them by ID — only by label, which is fragile
(localization, font scaling) and ambiguous (two chips with the same label
in different sections).

We already added `emotion.<name>` identifiers to the FeelingStep's
core/secondary/specific buttons (used by `testWizardHappyPathReachesEnabledSaveButton`).
This spec extends the same idea to every `OFChip` so the rest of the
wizard's steps become reachable for UI tests.

## Goals

- Every `OFChip` in the app exposes an `.accessibilityIdentifier` derived
  predictably from its `label` (e.g. label `"Chest"` → identifier
  `"chip.chest"`).
- The identifier is set automatically in `OFChip`'s body — no per-call-
  site edits required.
- One new UI smoke test taps a chip in the Body wizard step and confirms
  the chip's selected state via the existing `.isSelected` AX trait.
- No visible UI change.

## Non-goals

- New chip-row pickers or new chip styles.
- Renaming chips or changing their visible labels.
- Per-step identifiers (e.g. `"body.chest"` vs `"context.chest"`). For
  v1, the same label across two steps produces the same identifier — UI
  tests should disambiguate via their navigation context (step they're
  on), not the identifier.

## Approach

### `OpenFeelings/Design/Components/OFChip.swift`

Add a small static helper that normalizes a label into an identifier
suffix and pass it through `.accessibilityIdentifier(...)`:

```swift
struct OFChip: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.OF.quick) { isOn.toggle() }
        } label: {
            // ...existing label rendering unchanged...
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityIdentifier(Self.identifier(for: label))   // NEW
    }

    /// Predictable identifier derived from the chip's visible label.
    /// e.g. "Chest" → "chip.chest", "Whole body" → "chip.whole-body",
    /// "Stuck/heavy" → "chip.stuck-heavy". Non-alphanumeric characters
    /// collapse to "-"; consecutive separators collapse to one; leading
    /// and trailing separators are trimmed.
    nonisolated static func identifier(for label: String) -> String {
        var out = ""
        var lastWasSeparator = true   // suppresses leading "-"
        for char in label.lowercased() {
            if char.isLetter || char.isNumber {
                out.append(char)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                out.append("-")
                lastWasSeparator = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return "chip.\(out)"
    }
}
```

The transform is intentionally simple — no Unicode-aware normalization,
no locale considerations. All chip labels in this app are ASCII or
near-ASCII English strings; if that ever changes, revisit.

### Tests

#### Unit tests for the identifier transform

`OpenFeelingsTests/OFChipIdentifierTests.swift` (new):

```swift
import XCTest
@testable import OpenFeelings

final class OFChipIdentifierTests: XCTestCase {

    func testSingleWordLabelLowercased() {
        XCTAssertEqual(OFChip.identifier(for: "Chest"), "chip.chest")
    }

    func testMultiWordLabelSeparatedByDash() {
        XCTAssertEqual(OFChip.identifier(for: "Whole body"), "chip.whole-body")
    }

    func testSlashAndOtherSeparatorsCollapseToDash() {
        XCTAssertEqual(OFChip.identifier(for: "Stuck/heavy"), "chip.stuck-heavy")
        XCTAssertEqual(OFChip.identifier(for: "Hot · prickly"), "chip.hot-prickly")
    }

    func testLeadingAndTrailingSeparatorsAreTrimmed() {
        XCTAssertEqual(OFChip.identifier(for: " spaced "), "chip.spaced")
        XCTAssertEqual(OFChip.identifier(for: "—hyphenated—"), "chip.hyphenated")
    }

    func testEmptyLabelProducesNoSuffix() {
        XCTAssertEqual(OFChip.identifier(for: ""), "chip.")
    }

    func testNumericLabelPreserved() {
        XCTAssertEqual(OFChip.identifier(for: "Top 3"), "chip.top-3")
    }
}
```

#### UI test — wizard body step chip selection

`OpenFeelingsUITests/OpenFeelingsUITests.swift` — add to the existing
test class:

```swift
func testWizardBodyChipBecomesSelectedAfterTap() {
    tab("checkIn").tap()

    // Default flow is Body first. The "Everywhere" chip is always present
    // on the Body step and is a stable target.
    let chip = app.descendants(matching: .any)
        .matching(identifier: "chip.everywhere").firstMatch
    XCTAssertTrue(chip.waitForExistence(timeout: 3),
                  "Body step Everywhere chip should expose chip.everywhere identifier")

    XCTAssertFalse(chip.isSelected, "Chip starts unselected")
    chip.tap()
    XCTAssertTrue(chip.isSelected, "Chip should become selected after tap")
}
```

(`XCUIElement.isSelected` reflects `accessibilityAddTraits(.isSelected)`.)

## Verification

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -3
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED + 210 + 6 unit + 1 UI = ~217 passing tests.

## Implementation order

1. Add `OFChip.identifier(for:)` and the `.accessibilityIdentifier(...)`
   call in `OFChip.swift`.
2. Add `OFChipIdentifierTests.swift`. Run unit tests.
3. Add `testWizardBodyChipBecomesSelectedAfterTap` to the UI tests file.
   Run UI tests.
4. Single feature commit.

## Out of scope

- Per-step disambiguation (`"body.chest"` vs `"context.chest"`).
- Localization-aware identifiers.
- Identifiers on non-OFChip wizard widgets (Strength dots, mood sliders,
  Wizard/Wheel mode picker — that one already has labels via the AX pass).
- Changes to the FeelingStep emotion grid buttons — they already have
  `emotion.<name>` identifiers from build 15.
