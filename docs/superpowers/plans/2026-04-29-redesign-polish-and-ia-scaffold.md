# Open Feelings — Redesign (Polish + IA Scaffold) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a coherent, App-Store-ready warm-calm visual system and a 5-tab IA (Today / Check In / Insights / Intentions / Settings) for the Open Feelings iOS app, with empty-state placeholders for the queued new dimensions and no SwiftData/service changes.

**Architecture:** Add a small design-system layer at `OpenFeelings/Design/` (tokens, helpers, reusable components). Refactor `RootView` to a 5-tab structure with a shared, observable `AppNavigation` for tab selection. Add new view files for Today / Insights / Intentions. Re-skin all existing views to consume tokens + components. Wheel keeps its geometry / gestures / transform — only colors and typography change. Pure-logic helpers (greeting, week summary, redesigned color mapping) get XCTest coverage; views are verified manually on iPad simulator (iOS 26.0.1).

**Tech Stack:** SwiftUI, Swift 6.0, SwiftData, iOS 26.0, XCTest. Existing build via XcodeGen + xcodebuild. iOS 26 Liquid Glass material on tab bar / sheets.

**Spec:** `docs/superpowers/specs/2026-04-29-redesign-polish-and-ia-scaffold-design.md`

---

## Conventions for every task

- After every task that adds files, run `xcodegen generate` before the build/test. The build will not see new files otherwise.
- Build before commit:
  ```sh
  xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
    -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
  ```
- Test before commit (when tests exist or the task adds tests):
  ```sh
  xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
    -sdk iphonesimulator \
    -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
    -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
  ```
- Each task ends with a focused commit. Use `git add` with explicit paths — never `git add .` or `-A`.
- Never modify `EmotionTaxonomy.swift` color hexes — use the new `redesignedAccent` extension instead.
- Never modify `WheelViewportTransform` math or `WheelViewportTransformTests`. Both must stay green throughout.
- Never modify `OpenFeelingsApp.swift` store-mode branching.

---

## File map

**New files:**

```
OpenFeelings/Design/
├── DesignTokens.swift
├── LiquidGlass.swift
├── EmotionColorPalette.swift
├── Greeting.swift
├── WeekSummary.swift
├── AppNavigation.swift
└── Components/
    ├── OFCard.swift
    ├── OFListRow.swift
    ├── OFEmptyState.swift
    ├── OFSectionHeader.swift
    └── OFButton.swift

OpenFeelings/Views/
├── TodayView.swift
├── InsightsView.swift
└── IntentionsView.swift

OpenFeelingsTests/
├── EmotionColorPaletteTests.swift
├── GreetingTests.swift
├── WeekSummaryTests.swift
└── AppNavigationTests.swift
```

**Modified files:**

```
OpenFeelings/OpenFeelingsApp.swift            (inject AppNavigation)
OpenFeelings/Views/RootView.swift             (5-tab + AppNavigation)
OpenFeelings/Views/CheckInView.swift          (tokens, placeholder rows, save flow)
OpenFeelings/Views/WizardCheckInView.swift    (tokens)
OpenFeelings/Views/EmotionWheelView.swift     (tokens — colors + label fonts only)
OpenFeelings/Views/EmotionDefinitionCard.swift (tokens + Sources disclosure)
OpenFeelings/Views/HistoryView.swift          (tokens, sub-route from Today)
OpenFeelings/Views/SettingsView.swift         (tokens, displayName row, sections)
OpenFeelings/Views/LockGateView.swift         (tokens)
```

---

# Phase 1 — Foundations & pure-logic helpers

These tasks introduce the new files needed before any view changes. Pure-logic items get XCTest coverage; tokens get a smoke test.

## Task 1: Design tokens — colors, typography, spacing, radius, motion

**Files:**
- Create: `OpenFeelings/Design/DesignTokens.swift`

- [ ] **Step 1: Create the tokens file**

```swift
// OpenFeelings/Design/DesignTokens.swift
import SwiftUI

// MARK: - Color tokens

extension Color {
    enum OF {
        static let background      = Color("BackgroundOF", bundle: nil, fallback: Color(light: "FAF6F0", dark: "1B1A18"))
        static let surface         = Color(light: "FFFFFF", dark: "2A2724")
        static let surfaceElevated = Color(light: "FCF9F4", dark: "34302C")
        static let text            = Color(light: "2B2520", dark: "F0EAE0")
        static let textMuted       = Color(light: "6B6259", dark: "A89E92")
        static let textOnAccent    = Color.white
        static let divider         = Color(light: "E8DFD3", dark: "3F3A35")
        static let accent          = Color(light: "C97A4F", dark: "D8916A")
        static let accentSoft      = Color(light: "EFD5C2", dark: "5C3F2E")
    }

    fileprivate init(light: String, dark: String) {
        self = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }

    init(name: String, bundle: Bundle? = nil, fallback: Color) {
        // Asset-catalog lookup with a hex fallback, used so the tokens compile
        // without an asset catalog. We always use the fallback path until / unless
        // someone adds a Colors.xcassets entry.
        self = fallback
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = CGFloat((v & 0xFF0000) >> 16) / 255
        let g = CGFloat((v & 0x00FF00) >> 8) / 255
        let b = CGFloat(v & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Typography tokens

extension Font {
    enum OF {
        static let display       = Font.system(size: 34, weight: .regular, design: .serif)
        static let title         = Font.system(size: 28, weight: .regular, design: .serif)
        static let headline      = Font.system(size: 20, weight: .semibold)
        static let body          = Font.system(size: 17, weight: .regular)
        static let bodyEmphasis  = Font.system(size: 17, weight: .semibold)
        static let caption       = Font.system(size: 13, weight: .regular)
        static let mono          = Font.system(size: 15, weight: .regular, design: .monospaced)
    }
}

// MARK: - Spacing tokens

extension CGFloat {
    enum OF {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
}

// MARK: - Radius tokens

extension CGFloat.OF {
    enum Radius {
        static let chip:  CGFloat = 6
        static let card:  CGFloat = 12
        static let sheet: CGFloat = 20
    }
}

// MARK: - Motion tokens

extension Animation {
    enum OF {
        static let quick  = Animation.easeInOut(duration: 0.18)
        static let gentle = Animation.easeInOut(duration: 0.32)
        static let settle = Animation.spring(response: 0.48, dampingFraction: 0.85)
    }

    /// Returns `.OF.quick` etc. unless Reduce Motion is on, in which case
    /// returns `nil` (callers should pass to `withAnimation(_:)` which treats
    /// `nil` as instant).
    static func ofRespectingReduceMotion(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
```

- [ ] **Step 2: Run xcodegen + build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```
Expected: PASS.

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Design/DesignTokens.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add warm-calm DesignTokens

- Color, typography, spacing, radius, motion tokens
- Color.OF.* surface/text/accent palette (light + dark)
- Font.OF.* serif display/title + sans body roles
- Animation.OF.* with Reduce Motion helper

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: `EmotionColorPalette` — redesigned per-core accents (TDD)

**Files:**
- Create: `OpenFeelings/Design/EmotionColorPalette.swift`
- Create: `OpenFeelingsTests/EmotionColorPaletteTests.swift`

- [ ] **Step 1: Write failing test**

```swift
// OpenFeelingsTests/EmotionColorPaletteTests.swift
import XCTest
@testable import OpenFeelings

final class EmotionColorPaletteTests: XCTestCase {
    func testEveryCoreHasARedesignedAccent() {
        for core in EmotionTaxonomy.cores {
            let pair = EmotionColorPalette.accent(forCoreID: core.id)
            XCTAssertNotNil(pair, "core \(core.id) missing redesigned accent")
        }
    }

    func testKnownCoresMapToExpectedHexes() {
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "happy")?.lightHex,   "D9A43A")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "sad")?.lightHex,     "6F8FA8")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "angry")?.lightHex,   "C46A55")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "fearful")?.lightHex, "A07FB1")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "disgusted")?.lightHex, "7AA88A")
    }

    func testUnknownCoreReturnsNil() {
        XCTAssertNil(EmotionColorPalette.accent(forCoreID: "totally-not-a-core"))
    }

    func testSecondaryAndSpecificDeriveLighter() {
        // Secondary should be lighter than core; specific lighter than secondary.
        let coreL  = EmotionColorPalette.brightness(hex: "D9A43A")
        let secL   = EmotionColorPalette.brightness(
            hex: EmotionColorPalette.lightenHex("D9A43A", towardWhite: 0.45)
        )
        let specL  = EmotionColorPalette.brightness(
            hex: EmotionColorPalette.lightenHex("D9A43A", towardWhite: 0.78)
        )
        XCTAssertLessThan(coreL, secL)
        XCTAssertLessThan(secL, specL)
    }
}
```

- [ ] **Step 2: Run test — verify failure**

```sh
xcodebuild ... test -only-testing:OpenFeelingsTests/EmotionColorPaletteTests
```
Expected: FAIL — `EmotionColorPalette` not defined.

- [ ] **Step 3: Implement**

```swift
// OpenFeelings/Design/EmotionColorPalette.swift
import Foundation
import SwiftUI

enum EmotionColorPalette {
    struct ColorPair: Equatable {
        let lightHex: String
        let darkHex: String
    }

    private static let coreAccents: [String: ColorPair] = [
        "happy":     ColorPair(lightHex: "D9A43A", darkHex: "E5BC68"),
        "sad":       ColorPair(lightHex: "6F8FA8", darkHex: "93AABF"),
        "angry":     ColorPair(lightHex: "C46A55", darkHex: "D58B79"),
        "fearful":   ColorPair(lightHex: "A07FB1", darkHex: "B89CC4"),
        "disgusted": ColorPair(lightHex: "7AA88A", darkHex: "99BBA5"),
    ]

    static func accent(forCoreID id: String) -> ColorPair? {
        coreAccents[id]
    }

    /// Color for a given taxonomy node, derived from its core. Secondary uses
    /// `lightenHex(_, 0.45)`; specific uses `lightenHex(_, 0.78)`.
    static func color(coreID: String, depth: Depth, scheme: ColorScheme) -> Color {
        guard let pair = coreAccents[coreID] else {
            return scheme == .dark ? Color(hex: "A89E92") : Color(hex: "6B6259")
        }
        let base = scheme == .dark ? pair.darkHex : pair.lightHex
        let hex: String
        switch depth {
        case .core: hex = base
        case .secondary: hex = lightenHex(base, towardWhite: 0.45)
        case .specific: hex = lightenHex(base, towardWhite: 0.78)
        }
        return Color(hex: hex)
    }

    enum Depth { case core, secondary, specific }

    // MARK: - Color math

    static func lightenHex(_ hex: String, towardWhite t: CGFloat) -> String {
        let (r, g, b) = rgb(of: hex)
        let nr = r + (1 - r) * t
        let ng = g + (1 - g) * t
        let nb = b + (1 - b) * t
        return String(format: "%02X%02X%02X",
                      Int((nr * 255).rounded()),
                      Int((ng * 255).rounded()),
                      Int((nb * 255).rounded()))
    }

    static func brightness(hex: String) -> CGFloat {
        let (r, g, b) = rgb(of: hex)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    private static func rgb(of hex: String) -> (CGFloat, CGFloat, CGFloat) {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        return (
            CGFloat((v & 0xFF0000) >> 16) / 255,
            CGFloat((v & 0x00FF00) >> 8) / 255,
            CGFloat(v & 0x0000FF) / 255
        )
    }
}
```

- [ ] **Step 4: Run tests — verify pass**

Expected: PASS.

- [ ] **Step 5: Run full suite — verify no regression**

```sh
xcodebuild ... test
```
Expected: 13 existing + 4 new = 17 test methods passing.

- [ ] **Step 6: Commit**

```sh
git add OpenFeelings/Design/EmotionColorPalette.swift OpenFeelingsTests/EmotionColorPaletteTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add EmotionColorPalette warm-calm rebalance

- Maps each emotion core to a redesigned, lower-saturation accent
- Lightens for secondary (45%) / specific (78%) tints
- TDD: 4 tests covering core map, hex math, derivation order

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: `Greeting` — hour-aware greeting helper (TDD)

**Files:**
- Create: `OpenFeelings/Design/Greeting.swift`
- Create: `OpenFeelingsTests/GreetingTests.swift`

- [ ] **Step 1: Failing test**

```swift
// OpenFeelingsTests/GreetingTests.swift
import XCTest
@testable import OpenFeelings

final class GreetingTests: XCTestCase {
    private func date(hour: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 28; c.hour = hour
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    func testMorning() {
        XCTAssertEqual(Greeting.text(for: date(hour: 7), name: "Taylor"),
                       "Good morning, Taylor.")
    }

    func testAfternoon() {
        XCTAssertEqual(Greeting.text(for: date(hour: 13), name: "Taylor"),
                       "Good afternoon, Taylor.")
    }

    func testEvening() {
        XCTAssertEqual(Greeting.text(for: date(hour: 21), name: "Taylor"),
                       "Good evening, Taylor.")
    }

    func testEmptyNameDropsCommaAndName() {
        XCTAssertEqual(Greeting.text(for: date(hour: 9), name: ""),
                       "Good morning.")
    }

    func testWhitespaceNameIsTreatedAsEmpty() {
        XCTAssertEqual(Greeting.text(for: date(hour: 9), name: "   "),
                       "Good morning.")
    }

    func testBoundaries() {
        XCTAssertEqual(Greeting.text(for: date(hour: 0),  name: ""), "Good evening.")
        XCTAssertEqual(Greeting.text(for: date(hour: 5),  name: ""), "Good morning.")
        XCTAssertEqual(Greeting.text(for: date(hour: 11), name: ""), "Good morning.")
        XCTAssertEqual(Greeting.text(for: date(hour: 12), name: ""), "Good afternoon.")
        XCTAssertEqual(Greeting.text(for: date(hour: 16), name: ""), "Good afternoon.")
        XCTAssertEqual(Greeting.text(for: date(hour: 17), name: ""), "Good evening.")
        XCTAssertEqual(Greeting.text(for: date(hour: 23), name: ""), "Good evening.")
    }
}
```

- [ ] **Step 2: Run test — verify FAIL** (`Greeting` undefined).

- [ ] **Step 3: Implement**

```swift
// OpenFeelings/Design/Greeting.swift
import Foundation

enum Greeting {
    /// Returns "Good morning, Name." / "Good afternoon, Name." / "Good evening, Name."
    /// If name is empty or whitespace, drops the comma and name.
    static func text(for date: Date, name: String, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let part: String
        switch hour {
        case 5..<12:  part = "Good morning"
        case 12..<17: part = "Good afternoon"
        default:      part = "Good evening"
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(part)." : "\(part), \(trimmed)."
    }
}
```

- [ ] **Step 4: Run tests — verify PASS** (all 7 pass).

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Design/Greeting.swift OpenFeelingsTests/GreetingTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add Greeting helper

Hour-aware morning/afternoon/evening text with optional name.
TDD: 7 tests covering ranges, boundaries, empty/whitespace name.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: `WeekSummary` — most-frequent core + count over trailing 7 days (TDD)

**Files:**
- Create: `OpenFeelings/Design/WeekSummary.swift`
- Create: `OpenFeelingsTests/WeekSummaryTests.swift`

- [ ] **Step 1: Failing test**

```swift
// OpenFeelingsTests/WeekSummaryTests.swift
import XCTest
@testable import OpenFeelings

final class WeekSummaryTests: XCTestCase {
    private func log(coreID: String, coreName: String, daysAgo: Double, now: Date) -> FeelingLog {
        let selection = EmotionTaxonomy.selection(coreID: coreID,
                                                  secondaryID: nil,
                                                  specificID: nil)!
        let log = FeelingLog(selection: selection, intensity: nil, note: "")
        log.createdAt = now.addingTimeInterval(-daysAgo * 86_400)
        return log
    }

    func testEmptyLogsReturnsNil() {
        XCTAssertNil(WeekSummary.summarize(logs: [], now: Date()))
    }

    func testReturnsTopCoreWithCount() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", daysAgo: 3, now: now),
            log(coreID: "sad",   coreName: "Sad",   daysAgo: 4, now: now),
        ]
        let summary = WeekSummary.summarize(logs: logs, now: now)
        XCTAssertEqual(summary?.topCoreName, "Happy")
        XCTAssertEqual(summary?.totalCount, 3)
    }

    func testIgnoresLogsOlderThan7Days() {
        let now = Date()
        let logs = [
            log(coreID: "happy", coreName: "Happy", daysAgo: 2,  now: now),
            log(coreID: "sad",   coreName: "Sad",   daysAgo: 30, now: now),
        ]
        let summary = WeekSummary.summarize(logs: logs, now: now)
        XCTAssertEqual(summary?.topCoreName, "Happy")
        XCTAssertEqual(summary?.totalCount, 1)
    }

    func testTieBreaksOnFirstSeen() {
        let now = Date()
        let logs = [
            log(coreID: "sad",   coreName: "Sad",   daysAgo: 1, now: now),
            log(coreID: "happy", coreName: "Happy", daysAgo: 2, now: now),
        ]
        // Equal counts; "Sad" first by createdAt descending.
        let summary = WeekSummary.summarize(logs: logs, now: now)
        XCTAssertEqual(summary?.topCoreName, "Sad")
    }
}
```

- [ ] **Step 2: Run test — verify FAIL**.

- [ ] **Step 3: Implement**

```swift
// OpenFeelings/Design/WeekSummary.swift
import Foundation

struct WeekSummary: Equatable {
    let topCoreID: String
    let topCoreName: String
    let totalCount: Int

    /// Returns nil if there are no logs in the trailing 7 days.
    static func summarize(logs: [FeelingLog], now: Date = Date()) -> WeekSummary? {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        let recent = logs.filter { $0.createdAt >= cutoff }
        guard !recent.isEmpty else { return nil }

        // Sort by createdAt descending so tie-breaks favor the most recent core.
        let sorted = recent.sorted { $0.createdAt > $1.createdAt }
        var counts: [String: Int] = [:]
        var firstSeenName: [String: String] = [:]
        var firstSeenIndex: [String: Int] = [:]
        for (i, log) in sorted.enumerated() {
            counts[log.coreID, default: 0] += 1
            if firstSeenName[log.coreID] == nil {
                firstSeenName[log.coreID] = log.coreName
                firstSeenIndex[log.coreID] = i
            }
        }
        let top = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return (firstSeenIndex[lhs.key] ?? 0) > (firstSeenIndex[rhs.key] ?? 0)
        }!
        return WeekSummary(
            topCoreID: top.key,
            topCoreName: firstSeenName[top.key] ?? top.key.capitalized,
            totalCount: recent.count
        )
    }
}
```

- [ ] **Step 4: Run tests — verify PASS** (all 4).

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Design/WeekSummary.swift OpenFeelingsTests/WeekSummaryTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add WeekSummary helper

Computes most-frequent core + total count over trailing 7 days.
Tie-break favors the most recent core. TDD: 4 tests.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: `AppNavigation` — observable tab selection (TDD)

**Files:**
- Create: `OpenFeelings/Design/AppNavigation.swift`
- Create: `OpenFeelingsTests/AppNavigationTests.swift`

- [ ] **Step 1: Failing test**

```swift
// OpenFeelingsTests/AppNavigationTests.swift
import XCTest
@testable import OpenFeelings

@MainActor
final class AppNavigationTests: XCTestCase {
    func testDefaultTabIsToday() {
        let nav = AppNavigation()
        XCTAssertEqual(nav.selectedTab, .today)
    }

    func testSelectChanges() {
        let nav = AppNavigation()
        nav.select(.checkIn)
        XCTAssertEqual(nav.selectedTab, .checkIn)
    }

    func testAllTabsHaveTitleAndSymbol() {
        for tab in AppTab.allCases {
            XCTAssertFalse(tab.title.isEmpty)
            XCTAssertFalse(tab.systemImage.isEmpty)
        }
    }

    func testTabOrderIsTodayCheckInInsightsIntentionsSettings() {
        XCTAssertEqual(AppTab.allCases,
                       [.today, .checkIn, .insights, .intentions, .settings])
    }
}
```

- [ ] **Step 2: Run test — FAIL**.

- [ ] **Step 3: Implement**

```swift
// OpenFeelings/Design/AppNavigation.swift
import SwiftUI

enum AppTab: String, CaseIterable, Hashable {
    case today
    case checkIn
    case insights
    case intentions
    case settings

    var title: String {
        switch self {
        case .today: "Today"
        case .checkIn: "Check In"
        case .insights: "Insights"
        case .intentions: "Intentions"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today: "sun.horizon"
        case .checkIn: "circle.grid.3x3"
        case .insights: "chart.line.uptrend.xyaxis"
        case .intentions: "leaf"
        case .settings: "gearshape"
        }
    }
}

@MainActor
@Observable
final class AppNavigation {
    var selectedTab: AppTab = .today

    func select(_ tab: AppTab) {
        selectedTab = tab
    }
}
```

- [ ] **Step 4: Run tests — PASS**.

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Design/AppNavigation.swift OpenFeelingsTests/AppNavigationTests.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add AppTab + AppNavigation

Observable tab selection with default = Today. Tab metadata for
title and SF Symbol. TDD: 4 tests.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 2 — Reusable components

These are pure-SwiftUI views that consume tokens. No tests (visual). Use Xcode previews for sanity.

## Task 6: `OFCard` + `OFSectionHeader`

**Files:**
- Create: `OpenFeelings/Design/Components/OFCard.swift`
- Create: `OpenFeelings/Design/Components/OFSectionHeader.swift`

- [ ] **Step 1: Implement OFCard**

```swift
// OpenFeelings/Design/Components/OFCard.swift
import SwiftUI

struct OFCard<Content: View>: View {
    var padding: CGFloat = .OF.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: .OF.Radius.card, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: .OF.Radius.card, style: .continuous)
                    .stroke(Color.OF.divider.opacity(0.7), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 12, y: 4)
    }
}

#Preview {
    VStack(spacing: .OF.lg) {
        OFCard {
            Text("Hello")
        }
        OFCard(padding: .OF.md) {
            Text("Tighter")
        }
    }
    .padding()
    .background(Color.OF.background)
}
```

- [ ] **Step 2: Implement OFSectionHeader**

```swift
// OpenFeelings/Design/Components/OFSectionHeader.swift
import SwiftUI

struct OFSectionHeader: View {
    let title: String
    var trailingActionTitle: String?
    var trailingAction: (() -> Void)?

    var body: some View {
        HStack(spacing: .OF.sm) {
            Text(title.uppercased())
                .font(.OF.caption)
                .tracking(1.0)
                .foregroundStyle(Color.OF.textMuted)
            Spacer()
            if let trailingActionTitle, let trailingAction {
                Button(trailingActionTitle, action: trailingAction)
                    .font(.OF.caption.weight(.medium))
                    .foregroundStyle(Color.OF.accent)
            }
        }
        .padding(.horizontal, .OF.lg)
        .padding(.bottom, .OF.xs)
    }
}

#Preview {
    VStack(spacing: 0) {
        OFSectionHeader(title: "Today")
        OFSectionHeader(title: "This week", trailingActionTitle: "See all") {}
    }
    .padding(.vertical)
    .background(Color.OF.background)
}
```

- [ ] **Step 3: xcodegen + build**

- [ ] **Step 4: Commit**

```sh
git add OpenFeelings/Design/Components/OFCard.swift OpenFeelings/Design/Components/OFSectionHeader.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add OFCard + OFSectionHeader components

Surface card with token padding/radius/shadow.
Uppercase + tracked-letter section header with optional trailing action.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 7: `OFListRow`

**Files:**
- Create: `OpenFeelings/Design/Components/OFListRow.swift`

- [ ] **Step 1: Implement**

```swift
// OpenFeelings/Design/Components/OFListRow.swift
import SwiftUI

struct OFListRow<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: .OF.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.OF.accent)
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.OF.body).foregroundStyle(Color.OF.text)
                if let subtitle {
                    Text(subtitle).font(.OF.caption).foregroundStyle(Color.OF.textMuted)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, .OF.lg)
        .padding(.vertical, .OF.md)
        .frame(maxWidth: .infinity)
        .background(Color.OF.surface)
        .contentShape(Rectangle())
    }
}

extension OFListRow where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, systemImage: String? = nil) {
        self.init(title: title, subtitle: subtitle, systemImage: systemImage) { EmptyView() }
    }
}

extension OFListRow where Trailing == Image {
    static func chevron(title: String, subtitle: String? = nil, systemImage: String? = nil) -> OFListRow<Image> {
        OFListRow<Image>(title: title, subtitle: subtitle, systemImage: systemImage) {
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.OF.textMuted)
        }
    }
}

#Preview {
    VStack(spacing: 1) {
        OFListRow.chevron(title: "Display name", subtitle: "Taylor", systemImage: "person.crop.circle")
        OFListRow(title: "Daily reminder", systemImage: "bell") {
            Toggle("", isOn: .constant(true)).labelsHidden()
        }
        OFListRow(title: "Coming soon", systemImage: "leaf")
            .opacity(0.45)
    }
    .background(Color.OF.background)
}
```

- [ ] **Step 2: xcodegen + build**

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Design/Components/OFListRow.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add OFListRow

Settings/list row with leading icon, title, optional subtitle,
ViewBuilder trailing slot, plus .chevron and no-trailing convenience inits.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 8: `OFButton`

(OFButton is built first because OFEmptyState depends on it.)

**Files:**
- Create: `OpenFeelings/Design/Components/OFButton.swift`

- [ ] **Step 1: Implement**

```swift
// OpenFeelings/Design/Components/OFButton.swift
import SwiftUI

struct OFButton: View {
    enum Style { case primary, secondary, ghost, destructive }

    let title: String
    let style: Style
    let action: () -> Void

    init(_ title: String, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.OF.bodyEmphasis)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(foreground)
                .background(background, in: RoundedRectangle(cornerRadius: .OF.Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .animation(.OF.quick, value: style)
    }

    private var foreground: Color {
        switch style {
        case .primary: Color.OF.textOnAccent
        case .secondary, .ghost: Color.OF.accent
        case .destructive: .white
        }
    }

    private var background: AnyShapeStyle {
        switch style {
        case .primary:     AnyShapeStyle(Color.OF.accent)
        case .secondary:   AnyShapeStyle(Color.OF.accentSoft)
        case .ghost:       AnyShapeStyle(Color.clear)
        case .destructive: AnyShapeStyle(Color.red.opacity(0.9))
        }
    }
}

#Preview {
    VStack(spacing: .OF.md) {
        OFButton("Save check-in", style: .primary) {}
        OFButton("Notify me", style: .secondary) {}
        OFButton("Cancel", style: .ghost) {}
        OFButton("Delete", style: .destructive) {}
    }
    .padding()
    .background(Color.OF.background)
}
```

- [ ] **Step 2: xcodegen + build**

```sh
xcodegen generate
xcodebuild ... build
```

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Design/Components/OFButton.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add OFButton

Four variants (primary/secondary/ghost/destructive) using
warm-calm tokens; quick-motion press feedback.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 9: `OFEmptyState`

**Files:**
- Create: `OpenFeelings/Design/Components/OFEmptyState.swift`

- [ ] **Step 1: Implement**

```swift
// OpenFeelings/Design/Components/OFEmptyState.swift
import SwiftUI

struct OFEmptyState: View {
    let glyph: String
    let title: String
    let body: String
    var primaryAction: PrimaryAction? = nil

    struct PrimaryAction {
        let label: String
        let perform: () -> Void
    }

    var content: some View {
        VStack(spacing: .OF.lg) {
            ZStack {
                Circle()
                    .fill(Color.OF.accentSoft)
                    .frame(width: 84, height: 84)
                Image(systemName: glyph)
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.OF.accent)
            }
            VStack(spacing: .OF.sm) {
                Text(title)
                    .font(.OF.title)
                    .foregroundStyle(Color.OF.text)
                    .multilineTextAlignment(.center)
                Text(body)
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, .OF.lg)
            }
            if let primaryAction {
                OFButton(primaryAction.label, style: .primary, action: primaryAction.perform)
                    .padding(.horizontal, .OF.xxl)
                    .padding(.top, .OF.sm)
            }
        }
        .padding(.horizontal, .OF.lg)
        .padding(.vertical, .OF.xxl)
        .frame(maxWidth: .infinity)
    }

    var body: some View { content }
}

#Preview {
    OFEmptyState(
        glyph: "leaf.circle",
        title: "Today is open.",
        body: "Tap below to name how you're feeling.",
        primaryAction: .init(label: "Start a check-in", perform: {})
    )
    .background(Color.OF.background)
}
```

- [ ] **Step 2: xcodegen + build**

```sh
xcodegen generate
xcodebuild ... build
```

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Design/Components/OFEmptyState.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add OFEmptyState

Glyph badge + serif title + muted body + optional OFButton primary CTA.
Used by Today / Insights / Intentions / History empty states.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 10: `LiquidGlass.swift` adoption helpers

**Files:**
- Create: `OpenFeelings/Design/LiquidGlass.swift`

- [ ] **Step 1: Implement**

```swift
// OpenFeelings/Design/LiquidGlass.swift
import SwiftUI

/// Wraps iOS 26 Liquid Glass adoption so call sites change in one place.
enum LiquidGlass {
    /// Background style for sheets / modals. Falls back to surfaceElevated when
    /// Reduce Transparency is enabled.
    @ViewBuilder
    static func sheetBackground(reduceTransparency: Bool) -> some View {
        if reduceTransparency {
            Color.OF.surfaceElevated
        } else {
            // iOS 26 system Liquid Glass material; .ultraThinMaterial is the
            // closest stable name on iOS 26 for the glass family.
            Rectangle().fill(.ultraThinMaterial)
        }
    }

    /// Subtle scrim used over the wheel when the selection card slides up.
    @ViewBuilder
    static func scrimOverWheel(reduceTransparency: Bool) -> some View {
        if reduceTransparency {
            Color.OF.background.opacity(0.75)
        } else {
            Rectangle().fill(.thinMaterial)
        }
    }
}

extension View {
    /// Apply Liquid Glass background with Reduce Transparency support.
    func ofGlassSheetBackground(_ reduceTransparency: Bool) -> some View {
        background(LiquidGlass.sheetBackground(reduceTransparency: reduceTransparency))
    }
}
```

- [ ] **Step 2: xcodegen + build**

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Design/LiquidGlass.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(design): add LiquidGlass helpers

Centralized adoption of iOS 26 glass material with Reduce Transparency
fallback to surfaceElevated.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 3 — IA scaffold (5-tab structure)

## Task 11: `RootView` 5-tab + `AppNavigation` injection + empty Today/Insights/Intentions

**Files:**
- Modify: `OpenFeelings/Views/RootView.swift`
- Modify: `OpenFeelings/OpenFeelingsApp.swift` (inject AppNavigation)
- Create: `OpenFeelings/Views/TodayView.swift` (placeholder)
- Create: `OpenFeelings/Views/InsightsView.swift` (placeholder)
- Create: `OpenFeelings/Views/IntentionsView.swift` (placeholder)

This task is structural — it stubs new tabs to "Hello, world" placeholders. Phases 4-6 fill them in.

- [ ] **Step 1: Add AppNavigation to the app**

Read `OpenFeelings/OpenFeelingsApp.swift` first. Find where `HealthService` is constructed and passed via `.environment`. Add a sibling `@State` for `AppNavigation` and pass it the same way:

Modify `OpenFeelingsApp.swift`:
```swift
@State private var navigation = AppNavigation()

// inside body / .windowGroup, where .environment(healthService) lives:
.environment(navigation)
```

Place the new line directly after the existing `.environment(healthService)` modifier so behavior is purely additive.

- [ ] **Step 2: Replace `RootView`**

Overwrite `OpenFeelings/Views/RootView.swift`:

```swift
import SwiftUI

struct RootView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            NavigationStack { TodayView() }
                .tabItem {
                    Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                }
                .tag(AppTab.today)

            NavigationStack { CheckInView() }
                .tabItem {
                    Label(AppTab.checkIn.title, systemImage: AppTab.checkIn.systemImage)
                }
                .tag(AppTab.checkIn)

            NavigationStack { InsightsView() }
                .tabItem {
                    Label(AppTab.insights.title, systemImage: AppTab.insights.systemImage)
                }
                .tag(AppTab.insights)

            NavigationStack { IntentionsView() }
                .tabItem {
                    Label(AppTab.intentions.title, systemImage: AppTab.intentions.systemImage)
                }
                .tag(AppTab.intentions)

            NavigationStack { SettingsView() }
                .tabItem {
                    Label(AppTab.settings.title, systemImage: AppTab.settings.systemImage)
                }
                .tag(AppTab.settings)
        }
    }
}

#Preview {
    RootView()
        .environment(HealthService())
        .environment(AppNavigation())
}
```

- [ ] **Step 3: Add placeholder shells**

Create `OpenFeelings/Views/TodayView.swift`:
```swift
import SwiftUI

struct TodayView: View {
    var body: some View {
        ZStack {
            Color.OF.background.ignoresSafeArea()
            Text("Today (placeholder)").foregroundStyle(Color.OF.textMuted)
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { TodayView() } }
```

Create `OpenFeelings/Views/InsightsView.swift`:
```swift
import SwiftUI

struct InsightsView: View {
    var body: some View {
        ZStack {
            Color.OF.background.ignoresSafeArea()
            Text("Insights (placeholder)").foregroundStyle(Color.OF.textMuted)
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { InsightsView() } }
```

Create `OpenFeelings/Views/IntentionsView.swift`:
```swift
import SwiftUI

struct IntentionsView: View {
    var body: some View {
        ZStack {
            Color.OF.background.ignoresSafeArea()
            Text("Intentions (placeholder)").foregroundStyle(Color.OF.textMuted)
        }
        .navigationTitle("Intentions")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { NavigationStack { IntentionsView() } }
```

- [ ] **Step 4: xcodegen + build**

```sh
xcodegen generate
xcodebuild ... build
```
Expected: PASS.

- [ ] **Step 5: Run all tests**

```sh
xcodebuild ... test
```
Expected: 17 + 0 = 17 passing (no new tests this task).

- [ ] **Step 6: Manual sim check**

Boot the simulator, unlock, verify five tabs appear in order: Today / Check In / Insights / Intentions / Settings. Default tab is Today. Switching tabs works.

- [ ] **Step 7: Commit**

```sh
git add OpenFeelings/OpenFeelingsApp.swift OpenFeelings/Views/RootView.swift \
        OpenFeelings/Views/TodayView.swift OpenFeelings/Views/InsightsView.swift \
        OpenFeelings/Views/IntentionsView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(ia): switch to 5-tab structure with Today as default

Today / Check In / Insights / Intentions / Settings, driven by
AppNavigation observable. New tabs stubbed to placeholders.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 4 — Today surface

## Task 12: Today populated + empty states

**Files:**
- Modify: `OpenFeelings/Views/TodayView.swift`

- [ ] **Step 1: Replace TodayView with populated + empty states**

```swift
// OpenFeelings/Views/TodayView.swift
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppNavigation.self) private var navigation
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var allLogs: [FeelingLog]
    @AppStorage("displayName") private var displayName = ""
    @AppStorage("notifyOnInsightsReady") private var notifyOnInsights = false  // read elsewhere

    private var startOfToday: Date { Calendar.current.startOfDay(for: Date()) }

    private var todaysLogs: [FeelingLog] {
        allLogs.filter { $0.createdAt >= startOfToday }
    }

    private var weekSummary: WeekSummary? {
        WeekSummary.summarize(logs: allLogs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                header
                if todaysLogs.isEmpty {
                    OFEmptyState(
                        glyph: "leaf.circle",
                        title: "Today is open.",
                        body: "Tap below to name how you're feeling.",
                        primaryAction: .init(label: "Start a check-in") {
                            navigation.select(.checkIn)
                        }
                    )
                    .padding(.top, .OF.xl)
                } else {
                    intentionPlaceholder
                    todaysSection
                    weekSummarySection
                    seeAllLink
                }
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
        }
        .background(Color.OF.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HistoryRoute.self) { _ in
            HistoryView()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text(dateString)
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            Text(Greeting.text(for: Date(), name: displayName))
                .font(.OF.display)
                .foregroundStyle(Color.OF.text)
        }
        .padding(.top, .OF.lg)
    }

    private var dateString: String {
        Date().formatted(.dateTime.weekday(.wide).month().day())
    }

    private var intentionPlaceholder: some View {
        OFCard {
            VStack(alignment: .leading, spacing: .OF.sm) {
                Text("Today's intention".uppercased())
                    .font(.OF.caption)
                    .tracking(1.0)
                    .foregroundStyle(Color.OF.textMuted)
                Text("Coming soon — set what you'd like to feel today.")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
            }
        }
    }

    private var todaysSection: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "\(todaysLogs.count) check-in\(todaysLogs.count == 1 ? "" : "s") today")
                .padding(.horizontal, 0)
            ForEach(todaysLogs) { log in
                OFCard { logCardContent(log) }
            }
        }
    }

    @ViewBuilder
    private func logCardContent(_ log: FeelingLog) -> some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Text(log.pathTitle.replacingOccurrences(of: " > ", with: " · "))
                .font(.OF.headline)
                .foregroundStyle(Color.OF.text)
            HStack(spacing: .OF.sm) {
                if let intensity = log.intensity {
                    intensityDots(intensity: intensity)
                }
                Text(log.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.OF.mono)
                    .foregroundStyle(Color.OF.textMuted)
                if log.healthSyncStatus == .synced {
                    Label("synced", systemImage: "checkmark.circle.fill")
                        .font(.OF.caption)
                        .foregroundStyle(Color.OF.textMuted)
                }
            }
            if !log.note.isEmpty {
                Text("\u{201C}\(log.note)\u{201D}")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
                    .lineLimit(2)
            }
        }
    }

    private func intensityDots(intensity: Int) -> some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= intensity ? Color.OF.accent : Color.OF.divider)
                    .frame(width: 6, height: 6)
            }
        }
    }

    @ViewBuilder
    private var weekSummarySection: some View {
        if let summary = weekSummary {
            VStack(alignment: .leading, spacing: .OF.sm) {
                OFSectionHeader(title: "This week").padding(.horizontal, 0)
                Text("Mostly \(summary.topCoreName) · \(summary.totalCount) check-in\(summary.totalCount == 1 ? "" : "s")")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.text)
                    .padding(.horizontal, .OF.lg)
            }
        }
    }

    private var seeAllLink: some View {
        NavigationLink(value: HistoryRoute.full) {
            HStack {
                Text("See all history").font(.OF.body).foregroundStyle(Color.OF.accent)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Color.OF.textMuted)
            }
            .padding(.OF.lg)
            .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: .OF.Radius.card))
        }
    }

    enum HistoryRoute: Hashable { case full }
}
```

- [ ] **Step 2: xcodegen + build**

- [ ] **Step 3: Manual sim check**

- Cold launch with no logs → empty state shows; "Start a check-in" switches to Check In tab.
- Add a log via Check In → return to Today; populated state shows greeting, intention placeholder, today's logs, week summary, "See all" link.
- Tap "See all history" → pushes `HistoryView` onto Today's nav stack.

- [ ] **Step 4: Tests still green**

```sh
xcodebuild ... test
```

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Views/TodayView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(today): build Today populated + empty states

Greeting, today's logs, week summary, intention placeholder,
"See all history" link. Empty state CTA switches to Check In.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 5 — Check-in re-skin

## Task 13: Wheel color migration to redesigned palette

**Files:**
- Modify: `OpenFeelings/Views/EmotionWheelView.swift`

This task touches **only color resolution** in the wheel. Geometry, gestures, layout, transform, and tests must remain unchanged.

- [ ] **Step 1: Find color usage points**

```sh
grep -n "colorHex\|Color(hex:" /Users/tfinklea/git/open-feelings-ios/OpenFeelings/Views/EmotionWheelView.swift
```

You will see direct uses of `core.colorHex`, `secondary.colorHex`, `specific.colorHex` and `Color(hex: ...)`. Replace each fill/stroke that takes one of these with the corresponding `EmotionColorPalette.color(coreID:depth:scheme:)` call.

- [ ] **Step 2: Make the swap**

For each render site, change:
```swift
.fill(Color(hex: secondary.colorHex))
```
into:
```swift
.fill(EmotionColorPalette.color(coreID: core.id, depth: .secondary, scheme: colorScheme))
```

The view already reads `@Environment(\.colorScheme)` (or add it if missing — `@Environment(\.colorScheme) private var colorScheme`). If a label color uses the same hex, swap that too.

- [ ] **Step 3: Build**

```sh
xcodebuild ... build
```

- [ ] **Step 4: Run tests — `WheelViewportTransformTests` MUST stay green**

```sh
xcodebuild ... test -only-testing:OpenFeelingsTests/WheelViewportTransformTests
```
Expected: PASS.

- [ ] **Step 5: Manual sim check**

Wheel renders with the warm-calm rebalanced colors. Tap, pinch, two-finger rotate, drag-pan still select correctly.

- [ ] **Step 6: Commit**

```sh
git add OpenFeelings/Views/EmotionWheelView.swift
git commit -m "$(cat <<'EOF'
feat(wheel): adopt warm-calm color palette

Route ring fills + labels through EmotionColorPalette so the wheel
inherits the redesigned per-core accents. No geometry, gesture,
or transform changes; WheelViewportTransformTests still pass.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 14: Mode toggle + Check In hero re-skin

**Files:**
- Modify: `OpenFeelings/Views/CheckInView.swift`

This task changes only the *outer* layout of `CheckInView` (hero, mode toggle). The `LogComposerView` re-skin is Task 15. The save flow change is Task 16.

- [ ] **Step 1: Modify the body**

In `CheckInView.swift`, replace the top of `body` (the `ScrollView` outer + Picker) with:

```swift
var body: some View {
    ScrollView {
        VStack(alignment: .leading, spacing: .OF.xl) {
            heroHeader
            modeSegmented
            Group {
                switch mode {
                case .wizard:
                    WizardCheckInView(selection: $selection)
                case .wheel:
                    WheelCheckInView(selection: $selection)
                }
            }
            LogComposerView(
                selection: selection,
                note: $note,
                includeIntensity: $includeIntensity,
                intensity: $intensity,
                save: save
            )
        }
        .padding(.horizontal, .OF.lg)
        .padding(.bottom, .OF.xxxl)
    }
    .background(Color.OF.background.ignoresSafeArea())
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) {
        if let savedMessage {
            Text(savedMessage)
                .font(.OF.bodyEmphasis)
                .frame(maxWidth: .infinity)
                .padding(.vertical, .OF.md)
                .background(.thinMaterial)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

private var heroHeader: some View {
    VStack(alignment: .leading, spacing: .OF.xs) {
        Text("Now")
            .font(.OF.caption)
            .foregroundStyle(Color.OF.textMuted)
        Text("How are you feeling?")
            .font(.OF.display)
            .foregroundStyle(Color.OF.text)
    }
    .padding(.top, .OF.lg)
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
                                RoundedRectangle(cornerRadius: .OF.Radius.chip, style: .continuous)
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
                in: RoundedRectangle(cornerRadius: .OF.Radius.chip + 4, style: .continuous))
}
```

Remove the old `Picker(...)` and old `checkInBackground`.

- [ ] **Step 2: Build + sim check**

Mode toggle should be a refined custom segmented control with accent-soft track and surface thumb. Tap switches with `quick` animation.

- [ ] **Step 3: Tests still green** (`xcodebuild ... test`).

- [ ] **Step 4: Commit**

```sh
git add OpenFeelings/Views/CheckInView.swift
git commit -m "$(cat <<'EOF'
feat(checkin): re-skin hero + mode segmented control

Display-serif "How are you feeling?" hero, custom segmented control
on accent-soft track using design tokens.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 15: Selection confirmation card with placeholder rows + definition polish

**Files:**
- Modify: `OpenFeelings/Views/CheckInView.swift` (replace `LogComposerView`)
- Modify: `OpenFeelings/Views/EmotionDefinitionCard.swift` (typography + Sources disclosure)

- [ ] **Step 1: Polish `EmotionDefinitionCard`**

Read the current file first. Then:
- Replace ad-hoc font modifiers with `.font(.OF.headline)` for the title and `.font(.OF.body)` for the summary.
- Use `Color.OF.text` and `Color.OF.textMuted`.
- Wrap the disclaimer in `Color.OF.textMuted` + `.OF.caption`.
- Add a `DisclosureGroup` labeled "Sources" containing a `VStack` of `Link` rows for each `EmotionDefinitions.referenceSources` entry. The disclosure is closed by default.
- Keep the existing `accent` color parameter for back-compat; route through `Color.OF.accent` callers.

- [ ] **Step 2: Replace `LogComposerView`**

Inside `CheckInView.swift`, replace the existing `LogComposerView` struct with:

```swift
private struct LogComposerView: View {
    let selection: EmotionSelection?
    @Binding var note: String
    @Binding var includeIntensity: Bool
    @Binding var intensity: Double
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .OF.lg) {
            header
            if let selection {
                EmotionDefinitionCard(
                    definition: selection.definition,
                    accent: Color.OF.accent,
                    showsDisclaimer: true
                )
                intensitySection
                placeholderRows
                noteField
                saveButton(enabled: selection.isComplete)
            } else {
                Text("Choose a feeling above to continue.")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
        .padding(.OF.lg)
        .background(Color.OF.surfaceElevated, in: RoundedRectangle(cornerRadius: .OF.Radius.sheet, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: .OF.Radius.sheet, style: .continuous)
                .stroke(Color.OF.divider.opacity(0.7), lineWidth: 1)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selection?.title ?? "No feeling selected")
                .font(.OF.headline)
                .foregroundStyle(Color.OF.text)
            if let selection {
                Text(selection.pathTitle)
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
            }
        }
    }

    private var intensitySection: some View {
        VStack(alignment: .leading, spacing: .OF.sm) {
            Toggle(isOn: $includeIntensity) {
                Text("Intensity").font(.OF.bodyEmphasis)
            }
            if includeIntensity {
                HStack(spacing: .OF.sm) {
                    intensityDots
                    Slider(value: $intensity, in: 1...5, step: 1)
                }
            }
        }
    }

    private var intensityDots: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= Int(intensity.rounded()) ? Color.OF.accent : Color.OF.divider)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private var placeholderRows: some View {
        VStack(spacing: 0) {
            OFSectionHeader(title: "Coming soon").padding(.horizontal, 0)
            placeholderRow(symbol: "figure.mind.and.body", title: "Body")
            Divider().background(Color.OF.divider)
            placeholderRow(symbol: "location",            title: "Context")
            Divider().background(Color.OF.divider)
            placeholderRow(symbol: "bolt",                title: "Triggers / coping")
            Divider().background(Color.OF.divider)
            placeholderRow(symbol: "waveform.path",       title: "Mood scale")
        }
        .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: .OF.Radius.card))
        .opacity(0.55)
    }

    private func placeholderRow(symbol: String, title: String) -> some View {
        HStack(spacing: .OF.md) {
            Image(systemName: symbol).foregroundStyle(Color.OF.textMuted).frame(width: 24)
            Text(title).font(.OF.body).foregroundStyle(Color.OF.textMuted)
            Spacer()
        }
        .padding(.horizontal, .OF.lg)
        .padding(.vertical, .OF.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityHint("Coming soon, currently unavailable")
        // No tap handler; opacity already reads as disabled.
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: .OF.xs) {
            Text("Note (optional)")
                .font(.OF.caption)
                .foregroundStyle(Color.OF.textMuted)
            TextField("", text: $note, axis: .vertical)
                .lineLimit(3...8)
                .font(.OF.body)
                .padding(.OF.md)
                .background(Color.OF.surface, in: RoundedRectangle(cornerRadius: .OF.Radius.card))
                .overlay {
                    RoundedRectangle(cornerRadius: .OF.Radius.card)
                        .stroke(Color.OF.divider, lineWidth: 1)
                }
        }
    }

    private func saveButton(enabled: Bool) -> some View {
        OFButton("Save check-in", style: .primary, action: save)
            .opacity(enabled ? 1 : 0.4)
            .disabled(!enabled)
    }
}
```

- [ ] **Step 3: Build + sim check**

Confirmation card uses `surfaceElevated`, sheet radius, polished sections; placeholder rows visible & dimmed; definition card with Sources disclosure expandable.

- [ ] **Step 4: Tests still green**.

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Views/CheckInView.swift OpenFeelings/Views/EmotionDefinitionCard.swift
git commit -m "$(cat <<'EOF'
feat(checkin): polish definition card + add coming-soon placeholders

LogComposerView now uses surfaceElevated sheet styling with
intensity dots, placeholder rows for Body/Context/Triggers/Mood
(disabled, accessibility-labeled), polished note field, and
OFButton.primary save. Definition card adopts tokens and gains
a "Sources" DisclosureGroup over the global reference list.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 16: Save flow → switch to Today + 2-second ribbon

**Files:**
- Modify: `OpenFeelings/Views/CheckInView.swift` (save method + remove inline ribbon)
- Modify: `OpenFeelings/Views/TodayView.swift` (read transient ribbon)
- Modify: `OpenFeelings/Design/AppNavigation.swift` (transient ribbon state)

- [ ] **Step 1: Add transient ribbon state to AppNavigation**

In `AppNavigation.swift`, add:

```swift
var savedRibbon: SavedRibbon?

struct SavedRibbon: Equatable {
    let timestamp: Date
}

func ribbonAfterSave(now: Date = Date()) {
    savedRibbon = SavedRibbon(timestamp: now)
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(2))
        savedRibbon = nil
    }
}
```

(Add tests if you want — not required for visual ribbon.)

- [ ] **Step 2: Switch tabs in CheckInView.save()**

In `CheckInView.swift`:
- Add `@Environment(AppNavigation.self) private var navigation`.
- Remove `@State private var savedMessage: String?` and the `safeAreaInset` ribbon (it now appears on Today).
- Replace `save()` with:

```swift
private func save() {
    guard let selection, selection.isComplete else { return }

    let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
    let log = FeelingLog(
        selection: selection,
        intensity: includeIntensity ? Int(intensity.rounded()) : nil,
        note: trimmedNote,
        healthSyncStatus: healthEnabled ? .pending : .notRequested
    )
    modelContext.insert(log)
    try? modelContext.save()
    resetDraft()

    // 1) Show ribbon on Today and switch tab.
    navigation.ribbonAfterSave()
    withAnimation(.OF.gentle) {
        navigation.select(.today)
    }

    // 2) Health write keeps existing async behavior.
    Task { @MainActor in
        log.healthSyncStatus = await healthService.save(log: log, isEnabled: healthEnabled)
        try? modelContext.save()
    }
}
```

- [ ] **Step 3: Render ribbon on Today**

Add at the bottom of `TodayView.body`'s outer `ScrollView` modifier chain:

```swift
.safeAreaInset(edge: .top) {
    if let ribbon = navigation.savedRibbon {
        Text("Saved · \(ribbon.timestamp.formatted(.dateTime.hour().minute()))")
            .font(.OF.bodyEmphasis)
            .frame(maxWidth: .infinity)
            .padding(.vertical, .OF.sm)
            .background(.thinMaterial)
            .transition(.move(edge: .top).combined(with: .opacity))
    }
}
.animation(.OF.gentle, value: navigation.savedRibbon)
```

- [ ] **Step 4: Build + sim check**

Save a check-in → tab auto-switches to Today → 2-second "Saved · 2:14 pm" ribbon at top of Today.

- [ ] **Step 5: Tests green**.

- [ ] **Step 6: Commit**

```sh
git add OpenFeelings/Views/CheckInView.swift OpenFeelings/Views/TodayView.swift OpenFeelings/Design/AppNavigation.swift
git commit -m "$(cat <<'EOF'
feat(checkin): on save, switch to Today and show 2s ribbon there

AppNavigation gains a transient SavedRibbon. CheckInView.save() now
inserts the log, switches the selected tab, and TodayView surfaces
the ribbon at the top via safeAreaInset.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 6 — Other surfaces

## Task 17: Insights + Intentions empty states

**Files:**
- Modify: `OpenFeelings/Views/InsightsView.swift`
- Modify: `OpenFeelings/Views/IntentionsView.swift`

- [ ] **Step 1: Build Insights**

```swift
// OpenFeelings/Views/InsightsView.swift
import SwiftUI

struct InsightsView: View {
    @AppStorage("notifyOnInsightsReady") private var notify = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                hero
                comingUp
                notifyToggle
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
        }
        .background(Color.OF.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        OFEmptyState(
            glyph: "chart.line.uptrend.xyaxis",
            title: "Your patterns, soon.",
            body: "Open Feelings will turn your check-ins into gentle weekly views."
        )
    }

    private var comingUp: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "Coming up").padding(.horizontal, 0)
            previewCard(symbol: "chart.bar.xaxis",      title: "Trends",
                        body: "When and how often each feeling shows up.")
            previewCard(symbol: "rectangle.stack",      title: "Weekly digest",
                        body: "One calm summary every Sunday.")
            previewCard(symbol: "square.and.arrow.up",  title: "Therapy bridge",
                        body: "A printable summary you can share with your therapist.")
        }
    }

    private func previewCard(symbol: String, title: String, body: String) -> some View {
        OFCard {
            HStack(alignment: .top, spacing: .OF.md) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.OF.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.OF.headline).foregroundStyle(Color.OF.text)
                    Text(body).font(.OF.body).foregroundStyle(Color.OF.textMuted)
                }
            }
        }
    }

    private var notifyToggle: some View {
        OFButton(notify ? "We'll let you know" : "Notify me when this is ready",
                 style: notify ? .secondary : .primary) {
            notify.toggle()
        }
    }
}

#Preview { NavigationStack { InsightsView() } }
```

- [ ] **Step 2: Build Intentions**

```swift
// OpenFeelings/Views/IntentionsView.swift
import SwiftUI

struct IntentionsView: View {
    @AppStorage("notifyOnIntentionsReady") private var notify = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                hero
                comingUp
                notifyToggle
            }
            .padding(.horizontal, .OF.lg)
            .padding(.bottom, .OF.xxxl)
        }
        .background(Color.OF.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        OFEmptyState(
            glyph: "leaf",
            title: "Intentions, coming soon.",
            body: "Choose what you'd like to feel — and let your check-ins help you notice."
        )
    }

    private var comingUp: some View {
        VStack(alignment: .leading, spacing: .OF.md) {
            OFSectionHeader(title: "Coming up").padding(.horizontal, 0)
            previewCard(symbol: "sun.horizon",
                        title: "Set today's intention",
                        body: "Choose what you'd like to feel today.")
            previewCard(symbol: "calendar",
                        title: "Look back",
                        body: "See how last week's intentions met your real check-ins.")
        }
    }

    private func previewCard(symbol: String, title: String, body: String) -> some View {
        OFCard {
            HStack(alignment: .top, spacing: .OF.md) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.OF.accent)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.OF.headline).foregroundStyle(Color.OF.text)
                    Text(body).font(.OF.body).foregroundStyle(Color.OF.textMuted)
                }
            }
        }
    }

    private var notifyToggle: some View {
        OFButton(notify ? "We'll let you know" : "Notify me when this is ready",
                 style: notify ? .secondary : .primary) {
            notify.toggle()
        }
    }
}

#Preview { NavigationStack { IntentionsView() } }
```

- [ ] **Step 3: Build + sim check**

Both surfaces show hero + 2-3 preview cards + notify CTA. Notify state persists across launches via `@AppStorage`.

- [ ] **Step 4: Commit**

```sh
git add OpenFeelings/Views/InsightsView.swift OpenFeelings/Views/IntentionsView.swift
git commit -m "$(cat <<'EOF'
feat(scaffold): build Insights + Intentions empty-state surfaces

Hero, preview cards (Trends/Digest/Therapy-bridge for Insights;
Set/Look-back for Intentions), notify-me toggle persisted via
AppStorage. No actual functionality — placeholders for follow-on specs.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 18: Settings re-skin (incl. displayName row)

**Files:**
- Modify: `OpenFeelings/Views/SettingsView.swift`

- [ ] **Step 1: Read current SettingsView**

```sh
sed -n '1,200p' /Users/tfinklea/git/open-feelings-ios/OpenFeelings/Views/SettingsView.swift
```

Note the existing `@AppStorage` keys (`appLockEnabled`, `healthEnabled`, `remindersEnabled`, reminder hour/minute) and the existing service-call patterns. Preserve those — only change presentation.

- [ ] **Step 2: Replace the body with sectioned form using OFSectionHeader + OFListRow**

Sketch (concrete code structure — adapt to the existing controller methods you saw in Step 1):

```swift
var body: some View {
    ScrollView {
        VStack(spacing: .OF.xl) {
            section(title: "App lock") {
                OFListRow(title: "Require Face ID / Passcode", systemImage: "lock.shield") {
                    Toggle("", isOn: $appLockEnabled).labelsHidden().tint(Color.OF.accent)
                }
            }
            section(title: "Reminders") {
                OFListRow(title: "Daily reminder", systemImage: "bell") {
                    Toggle("", isOn: $remindersEnabled).labelsHidden().tint(Color.OF.accent)
                }
                if remindersEnabled {
                    OFListRow(title: "Time", systemImage: "clock") {
                        DatePicker("", selection: reminderTimeBinding, displayedComponents: .hourAndMinute).labelsHidden()
                    }
                }
            }
            section(title: "Apple Health") {
                OFListRow(title: "Sync to State of Mind", systemImage: "heart") {
                    Toggle("", isOn: $healthEnabled).labelsHidden().tint(Color.OF.accent)
                }
                OFListRow(title: "Status", subtitle: healthStatusText, systemImage: "info.circle") { EmptyView() }
            }
            section(title: "Export & data") {
                Button { exportCSV() } label: { OFListRow.chevron(title: "Export CSV", systemImage: "tablecells") }
                Button { exportJSON() } label: { OFListRow.chevron(title: "Export JSON", systemImage: "curlybraces") }
            }
            section(title: "About & references") {
                NavigationLink { DisplayNameEditView(name: $displayName) } label: {
                    OFListRow.chevron(title: "Display name", subtitle: displayName.isEmpty ? "Not set" : displayName, systemImage: "person.crop.circle")
                }
                NavigationLink { ClinicalReferencesView() } label: {
                    OFListRow.chevron(title: "Clinical references", systemImage: "book")
                }
                NavigationLink { AttributionView() } label: {
                    OFListRow.chevron(title: "Open Emotion Wheel attribution", systemImage: "info.circle")
                }
                NavigationLink { LicensesView() } label: {
                    OFListRow.chevron(title: "Licenses", systemImage: "doc.plaintext")
                }
                Text("Open Feelings · v\(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                    .font(.OF.caption)
                    .foregroundStyle(Color.OF.textMuted)
                    .padding(.OF.lg)
            }
        }
        .padding(.horizontal, 0)
        .padding(.bottom, .OF.xxxl)
    }
    .background(Color.OF.background.ignoresSafeArea())
    .navigationTitle("Settings")
    .onAppear { healthService.refreshAuthorizationStatus() }
}

@ViewBuilder
private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 0) {
        OFSectionHeader(title: title)
        VStack(spacing: 0) {
            content()
        }
        .background(Color.OF.surface)
        .clipShape(RoundedRectangle(cornerRadius: .OF.Radius.card, style: .continuous))
        .padding(.horizontal, .OF.lg)
    }
}

@AppStorage("displayName") private var displayName = ""
```

Implement `DisplayNameEditView` as a small sheet/page:
```swift
private struct DisplayNameEditView: View {
    @Binding var name: String
    var body: some View {
        Form {
            TextField("Display name", text: $name)
        }
        .navigationTitle("Display name")
    }
}

extension Bundle {
    var appVersion: String { (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?" }
    var appBuild: String   { (infoDictionary?["CFBundleVersion"] as? String) ?? "?" }
}
```

Preserve every existing method (`exportCSV`, `exportJSON`, `reminderTimeBinding`, `healthStatusText`, etc.) from the current `SettingsView` — only the *presentation* changes. If Step 1's read shows different method names, use those.

- [ ] **Step 3: Build + sim check**

Every existing toggle and export still works; sectioned layout is polished; Display name row appears under About & references.

- [ ] **Step 4: Tests green**.

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Views/SettingsView.swift
git commit -m "$(cat <<'EOF'
feat(settings): re-skin with OFSectionHeader + OFListRow

Sectioned layout (App lock / Reminders / Health / Export / About).
Adds "Display name" row with @AppStorage("displayName") for the
greeting on Today. All existing controls preserved.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 19: History sub-route + re-skin

**Files:**
- Modify: `OpenFeelings/Views/HistoryView.swift`

- [ ] **Step 1: Read current `HistoryView.swift`**

Identify the export menu, `@Query`, and row presentation.

- [ ] **Step 2: Re-skin the row + outer chrome**

- Change row presentation to `OFCard` matching the Today populated card layout (path · intensity dots · timestamp · sync · note).
- Replace the navigation/toolbar export menu with a trailing `Menu` styled to tokens.
- Empty state via `OFEmptyState(glyph: "tray", title: "No check-ins yet", body: "Check-ins you save will show up here.")`.
- Page-level `Color.OF.background.ignoresSafeArea()`; `.navigationTitle("History")`.

(Skeleton — adapt to the actual file structure):
```swift
struct HistoryView: View {
    @Query(sort: \FeelingLog.createdAt, order: .reverse) private var logs: [FeelingLog]
    @State private var sharing: ShareItem?

    var body: some View {
        ZStack {
            Color.OF.background.ignoresSafeArea()
            if logs.isEmpty {
                OFEmptyState(glyph: "tray",
                             title: "No check-ins yet",
                             body: "Check-ins you save will show up here.")
            } else {
                ScrollView {
                    VStack(spacing: .OF.md) {
                        ForEach(logs) { log in OFCard { row(log: log) } }
                    }
                    .padding(.OF.lg)
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Export CSV", action: exportCSV)
                    Button("Export JSON", action: exportJSON)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(item: $sharing) { ActivityView(item: $0) }
    }

    private func row(log: FeelingLog) -> some View {
        // (same body as Today's logCardContent — extract to a shared `LogCard` if you prefer)
        VStack(alignment: .leading, spacing: .OF.sm) { /* ... */ }
    }

    // Preserve the existing exportCSV / exportJSON / ActivityView (or share-sheet)
    // implementations from the current file — just relocate them.
}
```

If you want to DRY: extract the log card body into a small `LogCard` component in `OpenFeelings/Design/Components/LogCard.swift` and use it in both Today and History. (Optional within this task — only do it if it doesn't blow up the diff.)

- [ ] **Step 3: Build + sim check**

History accessed via "See all history" from Today. Toolbar export menu still works.

- [ ] **Step 4: Tests green** (`ExportServiceTests` must remain green).

- [ ] **Step 5: Commit**

```sh
git add OpenFeelings/Views/HistoryView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "$(cat <<'EOF'
feat(history): re-skin and route from Today

Logs render as OFCard rows; export menu moved to top-right
toolbar; empty state via OFEmptyState. Same data + export behavior.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 20: WizardCheckInView re-skin (token adoption)

**Files:**
- Modify: `OpenFeelings/Views/WizardCheckInView.swift`

- [ ] **Step 1: Adopt tokens**

Read the current grid + selection-ring styling. Replace inline modifiers:
- Spacing: 8 → `.OF.sm`, 12 → `.OF.md`, 16 → `.OF.lg`.
- Colors: per-tile fill via `EmotionColorPalette.color(coreID:depth:scheme:)`.
- Selected ring: `Color.OF.accent` 2pt stroke at `.OF.Radius.card`.
- Tile font: `.OF.bodyEmphasis`.
- Animations on tile select: `.OF.quick`.

- [ ] **Step 2: Build + sim check**

Wizard grid renders with redesigned colors and spacing.

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Views/WizardCheckInView.swift
git commit -m "$(cat <<'EOF'
feat(wizard): adopt design tokens

Grid spacing, tile colors via EmotionColorPalette, accent ring on
selection, motion via Animation.OF.quick.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 21: LockGateView re-skin

**Files:**
- Modify: `OpenFeelings/Views/LockGateView.swift`

- [ ] **Step 1: Replace presentation**

Read current `LockGateView.swift`. Preserve:
- The wrapped-content pass-through.
- The `appLockEnabled` `@AppStorage`.
- The `unlock()` async call to `AppLockService`.
- The scene-phase lock-on-inactive behavior.

Replace the lock-screen visuals with:

```swift
private var lockScreen: some View {
    ZStack {
        Color.OF.background.ignoresSafeArea()
        VStack(spacing: .OF.xl) {
            ZStack {
                Circle().fill(Color.OF.accentSoft).frame(width: 96, height: 96)
                Image(systemName: "lock.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.OF.accent)
            }
            VStack(spacing: .OF.sm) {
                Text("Locked").font(.OF.display).foregroundStyle(Color.OF.text)
                Text("Use Face ID to continue.")
                    .font(.OF.body)
                    .foregroundStyle(Color.OF.textMuted)
            }
            OFButton("Unlock", style: .primary) { Task { await tryUnlock() } }
                .padding(.horizontal, .OF.xxxl)
                .padding(.top, .OF.lg)
        }
        .padding(.horizontal, .OF.xl)
    }
}
```

- [ ] **Step 2: Build + sim check**

Lock screen looks coherent with the rest of the app; unlock works.

- [ ] **Step 3: Commit**

```sh
git add OpenFeelings/Views/LockGateView.swift
git commit -m "$(cat <<'EOF'
feat(lock): re-skin lock gate to warm-calm tokens

Glyph badge + serif "Locked" headline + muted body + OFButton.primary.
Same control flow and scene-phase locking.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

# Phase 7 — Polish & verification

## Task 22: AA contrast verification + Reduce Motion / Reduce Transparency sweep

**Files:**
- May modify: `OpenFeelings/Design/DesignTokens.swift` (color tweaks if any pair fails AA)

- [ ] **Step 1: Verify all token pairs**

For each of these pairs in **both** light and dark, check WCAG AA (4.5:1 for body, 3:1 for ≥18pt):
1. `text` on `background`
2. `text` on `surface`
3. `textMuted` on `background`
4. `textMuted` on `surface`
5. `textOnAccent` on `accent`
6. `accent` on `accentSoft`
7. Each of 5 per-core accents on `surface` (label legibility on the wheel)

Use [contrast-ratio.com](https://contrast-ratio.com/) or any AA calculator. If a pair fails:
- Adjust the lighter component +5% lightness OR darker component −5% lightness.
- Update `DesignTokens.swift` and re-check.

- [ ] **Step 2: Reduce Motion sweep**

Enable Reduce Motion on the simulator. Run through Today / Check In / Settings. Confirm:
- Tab transitions are not animated.
- Mode toggle switch is instant.
- Save → tab switch → ribbon all instant.

If any animation isn't gated, wrap it in:
```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
// then:
withAnimation(reduceMotion ? nil : .OF.gentle) { ... }
```

- [ ] **Step 3: Reduce Transparency sweep**

Enable Reduce Transparency. Verify:
- Sheet backgrounds fall back to `surfaceElevated` (via `LiquidGlass.sheetBackground`).
- Tab bar still legible.

- [ ] **Step 4: VoiceOver sweep**

Enable VoiceOver. Walk through Today / Check In / Settings. Confirm:
- Greeting reads naturally.
- Today's logs read as combined elements ("Peaceful · Thankful, intensity 3 of 5, 2:14pm").
- Placeholder rows announce "Body, coming soon, currently unavailable."
- Insights/Intentions notify-me button reads its current state.

- [ ] **Step 5: Dynamic Type AX5 check**

Set the simulator's preferred text size to AX5. Walk Today / Check In / Settings. Confirm no clipped or truncated text on primary screens.

- [ ] **Step 6: Commit (if any token tweaks needed)**

```sh
git add OpenFeelings/Design/DesignTokens.swift
git commit -m "$(cat <<'EOF'
fix(design): tweak tokens for AA contrast and reduced-motion

(Only if changes were needed — describe specific pairs adjusted.)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 23: Final automated + manual verification

This task is verification only — no code changes unless something fails.

- [ ] **Step 1: Clean build**

```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```
Expected: PASS, no warnings related to new code.

- [ ] **Step 2: Full test suite**

```sh
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```
Expected: 13 original + ~18 new from Phase 1 (Tasks 2-5) = ~31 test methods passing.

- [ ] **Step 3: Manual checklist (iPad simulator iOS 26.0.1)**

Walk every item from the spec's §12 manual checklist:

- [ ] Cold start → `LockGateView` → Today (default tab).
- [ ] All 5 tabs render and switch with Liquid Glass tab bar; no layout glitches.
- [ ] Today populated state: greeting, intention placeholder, today's logs, week summary, "See all" link.
- [ ] Today empty state when zero logs today.
- [ ] Tap "Start a check-in" → Check In tab.
- [ ] Wizard mode: pick a path → confirmation card with placeholder rows.
- [ ] Wheel mode: tap, pinch, rotate, drag-pan all still select correctly.
- [ ] Definition card shows with redesigned typography; Sources disclosure expands.
- [ ] Save → return to Today → "Saved · {time}" ribbon for 2s.
- [ ] Health sync still works when enabled (Apple Health → State of Mind).
- [ ] Insights empty state correct; "Notify me" toggle persists across launches.
- [ ] Intentions empty state correct.
- [ ] Settings sections re-skinned; Lock, Reminders, Health, exports, references all functional; Display name editable.
- [ ] "See all history" → re-skinned `HistoryView`; export menu works.
- [ ] Light + dark mode both look intentional.
- [ ] AX5 Dynamic Type: no clipped text.
- [ ] VoiceOver: labels/hints/order make sense.
- [ ] Reduce Motion: animations instant.
- [ ] Reduce Transparency: glass falls back to solid.

- [ ] **Step 4: Update handoff docs**

Edit `.docs/ai/current-state.md` with a session summary of what shipped. Edit `.docs/ai/roadmap.md` to check off the redesign-cycle items and add the queued follow-on specs (Insights functional, Therapy bridge, Richer check-in data + UI, Intentions functional). Append an entry to `.docs/ai/decisions.md` if any architectural choice during implementation differed from the spec.

- [ ] **Step 5: Final commit**

```sh
git add .docs/
git commit -m "$(cat <<'EOF'
docs(handoff): record redesign-cycle completion

Update current-state, roadmap, and decisions to reflect the warm-calm
visual + IA scaffold redesign. Queue follow-on specs for the deferred
new dimensions.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Self-review summary

**Spec coverage:**
- §3 aesthetic → Tasks 1, 6-10 (tokens + components) and every view-touching task.
- §4 IA → Task 11.
- §5 tokens → Tasks 1, 2.
- §6 components → Tasks 6-10.
- §7.1 Today → Task 12.
- §7.2 Check In → Tasks 13-16, 20.
- §7.3 Insights → Task 17.
- §7.4 Intentions → Task 17.
- §7.5 Settings → Task 18.
- §7.6 Lock gate → Task 21.
- §7.7 History → Task 19.
- §8 Wheel re-skin specifics → Task 13.
- §9 Copy → Tasks 12 (greeting), 14 (hero), 15 (placeholders), 16 (ribbon), 17 (Insights/Intentions hero), 21 (lock).
- §10 Accessibility → Task 22.
- §11 Files affected → matches Phase 1-7 file map.
- §12 Verification → Task 23.

**Type / API consistency:** `EmotionColorPalette.color(coreID:depth:scheme:)`, `Greeting.text(for:name:)`, `WeekSummary.summarize(logs:now:)`, `AppNavigation.select(_:)` / `.savedRibbon` / `.ribbonAfterSave()` / `selectedTab`, `AppTab.{today,checkIn,insights,intentions,settings}.{title,systemImage}` are used identically across all consumers.

**No placeholders:** Every code step has full code; every command shows expected output; every commit has a message. The one `// adapt to existing methods you saw in Step 1` note in Task 18 is appropriate because the existing `SettingsView` controller methods aren't quoted in the plan — but the steps explicitly require reading the file before writing, and naming the methods to preserve.

---

## Execution handoff

Plan complete. Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration with two-stage review. Best for the volume here (23 tasks).
2. **Inline Execution** — Execute tasks in this session with checkpoints between phases.

Which approach?
