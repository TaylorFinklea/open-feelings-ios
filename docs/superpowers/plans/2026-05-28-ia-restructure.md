# IA Restructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Focus the Direction tab (keep Intentions + Values), promote Thought Records to a new Thoughts tab, demote Settings from a tab to a top-right gear that opens it modally, and move Insights to the last tab slot.

**Architecture:** Pure SwiftUI view restructuring — no new logic, no new unit tests. The existing 15-test UI suite is the regression net; three of those tests are updated for the new tab layout. New tab order: Today · Check In · Direction · Thoughts · Insights.

**Tech Stack:** SwiftUI · `@Observable` AppNavigation · XCUITest · xcodegen.

**Spec:** [`docs/superpowers/specs/2026-05-28-ia-restructure-design.md`](../specs/2026-05-28-ia-restructure-design.md)

**Sim:** `platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53` (booted Tesela-Test). If gone, `xcrun simctl list devices available` and pick a booted iOS 26 iPhone.

**Sequencing note:** The `.settings` enum case stays until Task 6 (RootView, its last consumer) so every intermediate commit builds. There are no unit tests here; each task verifies with a build, and the final task runs the full suites.

---

## File map

### Create
- `OpenFeelings/Design/Components/SettingsToolbar.swift` — a `ViewModifier` adding the trailing gear.
- `OpenFeelings/Views/ThoughtsView.swift` — hosts `ThoughtRecordsArea()`, mirrors `DirectionView`.

### Modify
- `OpenFeelings/Design/AppNavigation.swift` — `AppTab` enum (add `.thoughts`, later remove `.settings`, reorder), add `showingSettings`.
- `OpenFeelings/Views/RootView.swift` — reorder tabs, swap Settings tab → Thoughts tab, gear on each, settings sheet.
- `OpenFeelings/Views/Direction/DirectionView.swift` — drop `ThoughtRecordsArea()`.
- `OpenFeelings/Views/SettingsView.swift` — add Done button for modal dismissal.
- `OpenFeelingsUITests/OpenFeelingsUITests.swift` — two settings tests open the gear.
- `OpenFeelingsUITests/ThoughtRecordWizardUITests.swift` — navigate to Thoughts tab.

---

## Task 1: AppNavigation — add Thoughts + showingSettings (keep Settings for now)

Add the new tab case and the sheet flag without removing `.settings` yet, so RootView still compiles.

**Files:**
- Modify: `OpenFeelings/Design/AppNavigation.swift`

- [ ] **Step 1: Add the `.thoughts` case + `showingSettings`.**

In `OpenFeelings/Design/AppNavigation.swift`, change the `AppTab` enum to add `.thoughts` (leave `.settings` in place for now):

```swift
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case today
    case checkIn
    case insights
    case direction
    case thoughts
    case settings

    var title: String {
        switch self {
        case .today:      "Today"
        case .checkIn:    "Check In"
        case .insights:   "Insights"
        case .direction:  "Direction"
        case .thoughts:   "Thoughts"
        case .settings:   "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .today:      "sun.horizon"
        case .checkIn:    "circle.grid.3x3"
        case .insights:   "chart.line.uptrend.xyaxis"
        case .direction:  "leaf"
        case .thoughts:   "quote.bubble"
        case .settings:   "gearshape"
        }
    }
}
```

Then add the sheet flag to `AppNavigation` (just below `var selectedTab`):

```swift
    var selectedTab: AppTab = .today

    /// Drives the modal Settings sheet, opened from the per-tab gear.
    var showingSettings = false
```

- [ ] **Step 2: Build.**

Run: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination 'platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

```bash
git add OpenFeelings/Design/AppNavigation.swift
git commit -m "Add Thoughts AppTab case + showingSettings flag

Prep for the IA restructure. .settings stays until RootView (its last
consumer) is rewritten so intermediate commits build.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: SettingsToolbar modifier

**Files:**
- Create: `OpenFeelings/Design/Components/SettingsToolbar.swift`

- [ ] **Step 1: Write the modifier.**

Write `OpenFeelings/Design/Components/SettingsToolbar.swift`:

```swift
import SwiftUI

/// Adds a trailing gear button to a tab's navigation bar that opens the
/// app-wide Settings sheet. Apply to each top-level tab's root content.
struct SettingsToolbar: ViewModifier {
    @Environment(AppNavigation.self) private var navigation

    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    navigation.showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityIdentifier("settings.gear")
                .accessibilityLabel("Settings")
            }
        }
    }
}

extension View {
    func settingsToolbar() -> some View { modifier(SettingsToolbar()) }
}
```

- [ ] **Step 2: Regenerate + build.**

Run: `xcodegen generate && xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination 'platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

```bash
git add OpenFeelings/Design/Components/SettingsToolbar.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add SettingsToolbar modifier (per-tab gear → Settings sheet)

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: ThoughtsView

**Files:**
- Create: `OpenFeelings/Views/ThoughtsView.swift`

- [ ] **Step 1: Write the view (mirrors DirectionView).**

Write `OpenFeelings/Views/ThoughtsView.swift`:

```swift
import SwiftData
import SwiftUI

/// Top-level Thoughts tab. Hosts the CBT thought-record list + wizard,
/// split out of the Direction tab to keep Direction focused on values
/// and intentions. Mirrors `DirectionView`'s structure.
struct ThoughtsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .OF.xl) {
                ThoughtRecordsArea()
            }
            .padding(.horizontal, CGFloat.OF.lg)
            .padding(.bottom, CGFloat.OF.xxxl)
        }
        .background(Color.OF.background, ignoresSafeAreaEdges: .all)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Thoughts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { ThoughtsView() }
        .modelContainer(for: [ThoughtRecord.self, FeelingLog.self], inMemory: true)
}
```

- [ ] **Step 2: Regenerate + build.**

Run: `xcodegen generate && xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination 'platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

```bash
git add OpenFeelings/Views/ThoughtsView.swift OpenFeelings.xcodeproj/project.pbxproj
git commit -m "Add ThoughtsView hosting the thought-record list + wizard

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Focus DirectionView

**Files:**
- Modify: `OpenFeelings/Views/Direction/DirectionView.swift`

- [ ] **Step 1: Remove the ThoughtRecordsArea line.**

In `OpenFeelings/Views/Direction/DirectionView.swift`, change the `VStack` body from:

```swift
            VStack(alignment: .leading, spacing: .OF.xl) {
                IntentionsContent()
                ValuesArea()
                ThoughtRecordsArea()
            }
```

to:

```swift
            VStack(alignment: .leading, spacing: .OF.xl) {
                IntentionsContent()
                ValuesArea()
            }
```

(Leave the `#Preview`'s `modelContainer` list as-is — `ThoughtRecord.self` there is harmless and keeps the preview model graph complete.)

- [ ] **Step 2: Build.**

Run: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination 'platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit.**

```bash
git add OpenFeelings/Views/Direction/DirectionView.swift
git commit -m "Focus DirectionView on Intentions + Values

Thought Records moves to its own Thoughts tab (next: RootView wiring).

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: SettingsView Done button

Settings is now presented modally, so it needs a dismiss.

**Files:**
- Modify: `OpenFeelings/Views/SettingsView.swift`

- [ ] **Step 1: Add the dismiss environment value.**

In `OpenFeelings/Views/SettingsView.swift`, add to the property block (after the other `@Environment` lines, ~line 6):

```swift
    @Environment(\.dismiss) private var dismiss
```

- [ ] **Step 2: Add the Done toolbar item.**

Attach a `.toolbar` to the `ScrollView` in `body`, immediately after the `.navigationTitle("Settings")` line:

```swift
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
```

- [ ] **Step 3: Build.**

Run: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination 'platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit.**

```bash
git add OpenFeelings/Views/SettingsView.swift
git commit -m "Add Done button to SettingsView for modal presentation

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 6: RootView rewrite + remove `.settings` from AppTab

The keystone. Reorders tabs, swaps the Settings tab for the Thoughts tab, adds the gear to each tab, adds the Settings sheet — then removes the now-unused `.settings` enum case in the same commit (RootView is its last consumer, so the build stays green).

**Files:**
- Modify: `OpenFeelings/Views/RootView.swift`
- Modify: `OpenFeelings/Design/AppNavigation.swift`

- [ ] **Step 1: Replace the whole `RootView` body.**

Overwrite `OpenFeelings/Views/RootView.swift` with:

```swift
import SwiftUI

struct RootView: View {
    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.selectedTab) {
            NavigationStack(path: $navigation.todayPath) {
                TodayView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.today.title, systemImage: AppTab.today.systemImage)
                    .accessibilityIdentifier("tab.today")
            }
            .tag(AppTab.today)

            NavigationStack {
                CheckInView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.checkIn.title, systemImage: AppTab.checkIn.systemImage)
                    .accessibilityIdentifier("tab.checkIn")
            }
            .tag(AppTab.checkIn)

            NavigationStack {
                DirectionView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.direction.title, systemImage: AppTab.direction.systemImage)
                    .accessibilityIdentifier("tab.direction")
            }
            .tag(AppTab.direction)

            NavigationStack {
                ThoughtsView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.thoughts.title, systemImage: AppTab.thoughts.systemImage)
                    .accessibilityIdentifier("tab.thoughts")
            }
            .tag(AppTab.thoughts)

            NavigationStack {
                InsightsView().settingsToolbar()
            }
            .tabItem {
                Label(AppTab.insights.title, systemImage: AppTab.insights.systemImage)
                    .accessibilityIdentifier("tab.insights")
            }
            .tag(AppTab.insights)
        }
        .sheet(isPresented: $navigation.showingSettings) {
            NavigationStack { SettingsView() }
        }
    }
}

#Preview {
    RootView()
        .environment(HealthService())
        .environment(AppNavigation())
}
```

- [ ] **Step 2: Remove `.settings` from `AppTab` and reorder.**

In `OpenFeelings/Design/AppNavigation.swift`, set the final `AppTab`:

```swift
enum AppTab: String, CaseIterable, Hashable, Sendable {
    case today
    case checkIn
    case direction
    case thoughts
    case insights

    var title: String {
        switch self {
        case .today:     "Today"
        case .checkIn:   "Check In"
        case .direction: "Direction"
        case .thoughts:  "Thoughts"
        case .insights:  "Insights"
        }
    }

    var systemImage: String {
        switch self {
        case .today:     "sun.horizon"
        case .checkIn:   "circle.grid.3x3"
        case .direction: "leaf"
        case .thoughts:  "quote.bubble"
        case .insights:  "chart.line.uptrend.xyaxis"
        }
    }
}
```

(Leave the rest of `AppNavigation.swift` — `showingSettings`, `selectedTab`, `HistoryRoute`, `HistoryFilter`, the methods — unchanged.)

- [ ] **Step 3: Build.**

Run: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination 'platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53' build 2>&1 | tail -3`
Expected: `** BUILD SUCCEEDED **`. (If it fails on a stray `.settings` reference, grep `grep -rn "\.settings" OpenFeelings/Views OpenFeelings/Design` — only `settingsStore`-style matches should remain.)

- [ ] **Step 4: Commit.**

```bash
git add OpenFeelings/Views/RootView.swift OpenFeelings/Design/AppNavigation.swift
git commit -m "Restructure tab bar: Direction focused, Thoughts tab, Settings gear

New order Today / Check In / Direction / Thoughts / Insights. Settings
leaves the tab bar — a gear on every tab opens it as a modal sheet.
Removed the now-unused .settings AppTab case.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 7: Update UI tests

**Files:**
- Modify: `OpenFeelingsUITests/OpenFeelingsUITests.swift`
- Modify: `OpenFeelingsUITests/ThoughtRecordWizardUITests.swift`

- [ ] **Step 1: Fix `testTabSwitchingShowsEachTabsContent`.**

In `OpenFeelingsUITests/OpenFeelingsUITests.swift`, replace the opening Settings assertion (the `tab("settings").tap()` + "Settings" title block) with a Thoughts-tab check:

```swift
        // Thoughts tab on a fresh launch shows the navigation title "Thoughts".
        tab("thoughts").tap()
        XCTAssertTrue(app.staticTexts["Thoughts"].waitForExistence(timeout: 3),
                      "Thoughts tab should show its navigation title")
```

Keep the existing Direction, Insights, and Today checks that follow.

- [ ] **Step 2: Fix `testSettingsExposesPeriodSummaryRow`.**

In the same file, replace the leading `tab("settings").tap()` with opening the gear and waiting for the sheet:

```swift
        app.buttons["settings.gear"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 3),
                      "Settings sheet should present from the gear")
```

Leave the rest of the test (the `scrollViews.firstMatch` scroll loop to find "Period summary for therapist") unchanged — it now scrolls the sheet's scroll view.

- [ ] **Step 3: Update the file header comment.**

In `OpenFeelingsUITests/OpenFeelingsUITests.swift`, the doc comment near the top cites `"tab.settings"` as an example identifier. Change it to `"tab.thoughts"`.

- [ ] **Step 4: Fix `ThoughtRecordWizardUITests`.**

In `OpenFeelingsUITests/ThoughtRecordWizardUITests.swift`, in `testWizardCarriesEnteredValuesThroughToConfirm`, change:

```swift
        tab("direction").tap()
```

to:

```swift
        tab("thoughts").tap()
```

Leave the rest (the `scrollToWizardEntry()` / `thought-record.start` logic) unchanged — it works on the Thoughts tab, where `ThoughtRecordsArea` is the only content.

- [ ] **Step 5: Commit.**

```bash
git add OpenFeelingsUITests/OpenFeelingsUITests.swift OpenFeelingsUITests/ThoughtRecordWizardUITests.swift
git commit -m "Update UI tests for the IA restructure

testTabSwitching checks the Thoughts tab; testSettingsExposesPeriodSummaryRow
opens the Settings gear sheet; the thought-record wizard test navigates
to the Thoughts tab instead of Direction.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Full verification + manual smoke

**Files:** (none)

- [ ] **Step 1: Full unit suite (sanity — should be unaffected).**

Run: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination 'platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53' -only-testing:OpenFeelingsTests test 2>&1 | grep "Executed [0-9]\+ tests" | tail -1`
Expected: `Executed 404 tests, with 0 failures`.

- [ ] **Step 2: Full UI suite.**

Run: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination 'platform=iOS Simulator,id=5B48EF63-34D8-44BE-8D4F-945509D21C53' -only-testing:OpenFeelingsUITests test 2>&1 | grep "Executed [0-9]\+ tests" | tail -1`
Expected: `Executed 15 tests, with 0 failures`. If `ThoughtRecordWizardUITests` or a settings test fails, re-read the failure — most likely the gear identifier isn't reachable on the tab the test starts on (the gear is on every tab, so `app.buttons["settings.gear"].firstMatch` should resolve regardless).

- [ ] **Step 3: Manual smoke (note completion).**

Run the app in the sim. Confirm: five tabs in order Today / Check In / Direction / Thoughts / Insights; a gear top-right on every tab; the gear opens Settings as a sheet with a working Done; Direction shows only Intentions + Values; Thoughts shows the thought-record list + the wizard entry.

- [ ] **Step 4: Update handoff docs.**

Append to `.docs/ai/current-state.md` (last-session summary) and check off any roadmap item; add a `decisions.md` entry noting the IA restructure (Direction focused, Thoughts tab, Settings gear, Insights last) and that it was done before the App Store screenshots so the screenshots reflect the final IA. Commit:

```bash
git add .docs/ai/current-state.md .docs/ai/roadmap.md .docs/ai/decisions.md
git commit -m "Update handoff docs for the IA restructure

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

- [ ] **Step 5: Ship decision.**

The IA change is meant to land *before* the App Store screenshots. Bump `CURRENT_PROJECT_VERSION` (grep current value, +1), regenerate, commit `Release 0.1.0 (build N) to TestFlight`, archive, and upload — same flow as prior builds — **or** hold and capture screenshots off a local sim build first. This is the user's call at execution time; do not auto-ship without confirmation.

---

## Self-review

- ✅ **Spec coverage.** AppTab enum (`.thoughts` add, `.settings` remove, reorder) → Tasks 1 + 6. `showingSettings` → Task 1. SettingsToolbar → Task 2. ThoughtsView → Task 3. DirectionView focus → Task 4. SettingsView Done → Task 5. RootView (reorder, swap, gear, sheet) → Task 6. UI-test updates (two settings tests + wizard test + header comment) → Task 7. Verification + smoke + handoff + ship → Task 8.
- ✅ **No placeholders.** Every code step shows complete code; every command has an expected result. The build number in Task 8 Step 5 is resolved by grepping current value, and the ship is explicitly gated on user confirmation.
- ✅ **Type/identifier consistency.** `AppTab` cases (`today/checkIn/direction/thoughts/insights`), `showingSettings`, `settingsToolbar()`, `SettingsToolbar`, identifiers `tab.thoughts` / `settings.gear`, and the `quote.bubble` icon are identical across AppNavigation, RootView, the modifier, and the tests. `ThoughtsView` / `ThoughtRecordsArea` / `DirectionView` names match the real files.

---

## Execution

Plan complete and saved to `docs/superpowers/plans/2026-05-28-ia-restructure.md`.

Two execution options:
1. **Subagent-Driven (recommended)** — fresh subagent per task, review between tasks.
2. **Inline Execution** — execute here via executing-plans with checkpoints.
