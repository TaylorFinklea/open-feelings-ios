# IA restructure — focus Direction, Thoughts tab, Settings gear — design

**Status:** approved (2026-05-28)
**Ships in:** a build before the App Store screenshots (the screenshots must show the final IA).

## Why

The Direction tab stacks three areas (Intentions, Values, Thought Records) and feels too heavy. We're focusing it, promoting Thought Records to its own tab, demoting Settings from a tab to a top-right gear, and moving Insights to the last tab slot.

## Decisions locked

| Decision | Choice |
|---|---|
| Direction split | Keep Intentions + Values; Thought Records → new **Thoughts** tab |
| Thoughts tab | Title "Thoughts", icon `quote.bubble` (a thought record quotes the automatic thought) |
| Settings | Removed from tab bar; top-right gear on **every** tab, opens Settings **modally** |
| Tab order | Today · Check In · Direction · Thoughts · Insights (Insights last) |

## Current state

- `AppTab` (`OpenFeelings/Design/AppNavigation.swift`): `today, checkIn, insights, direction, settings`.
- `RootView` (`OpenFeelings/Views/RootView.swift`): a `TabView` with five `NavigationStack`-wrapped tabs in enum order, except it lists today, checkIn, insights, direction, settings.
- `DirectionView`: `ScrollView { IntentionsContent(); ValuesArea(); ThoughtRecordsArea() }`, `navigationTitle("Direction")`.
- `SettingsView`: rendered inside `NavigationStack { SettingsView() }` by RootView; has no dismiss affordance (it was a tab).
- `.settings` AppTab is referenced **only** in `AppNavigation.swift` and `RootView.swift` — no deep-links elsewhere.

## Changes

### `OpenFeelings/Design/AppNavigation.swift`

- `AppTab`: remove `.settings`; add `.thoughts`. Reorder cases to match the bar: `today, checkIn, direction, thoughts, insights`.
- `title`: add `.thoughts → "Thoughts"`; remove `.settings`.
- `systemImage`: add `.thoughts → "quote.bubble"`; remove `.settings`.
- Add `var showingSettings = false` to `AppNavigation`. (Drives the Settings sheet.)

### `OpenFeelings/Views/RootView.swift`

- Reorder the `TabView` children to: Today, Check In, Direction, Thoughts, Insights.
- Replace the old Settings tab with the new Thoughts tab: `NavigationStack { ThoughtsView() }`, `.tag(AppTab.thoughts)`, `accessibilityIdentifier("tab.thoughts")`.
- Insights moves to the last position (`.tag(AppTab.insights)`).
- Apply `.settingsToolbar()` (new modifier) to each tab's root content so a gear shows top-right on every tab.
- Add one sheet to the `TabView`: `.sheet(isPresented: $navigation.showingSettings) { NavigationStack { SettingsView() } }`.

### `OpenFeelings/Design/Components/SettingsToolbar.swift` (create)

A `ViewModifier` that reads `@Environment(AppNavigation.self)` and adds a trailing toolbar gear:

```swift
struct SettingsToolbar: ViewModifier {
    @Environment(AppNavigation.self) private var navigation
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { navigation.showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityIdentifier("settings.gear")
                .accessibilityLabel("Settings")
            }
        }
    }
}
extension View { func settingsToolbar() -> some View { modifier(SettingsToolbar()) } }
```

The gear is the rightmost `.topBarTrailing` item. Existing per-tab buttons (e.g. Thoughts' "+" in `ThoughtRecordsArea`, the Values "Re-sort"/"Past sorts") are **inline content buttons, not navbar toolbar items**, so there's no navbar collision. Verify per-tab at build time; if any tab already has a `.topBarTrailing` item, the gear sits alongside it (acceptable).

### `OpenFeelings/Views/ThoughtsView.swift` (create)

Mirror `DirectionView`'s structure exactly:

```swift
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
```

`ThoughtRecordsArea` is unchanged — it already owns its wizard sheet, list, and swipe-delete.

### `OpenFeelings/Views/Direction/DirectionView.swift`

Remove the `ThoughtRecordsArea()` line. Keep `IntentionsContent()` + `ValuesArea()`. Title stays "Direction".

### `OpenFeelings/Views/SettingsView.swift`

Settings is now presented modally, so it needs a dismiss. Add a `Done` button:

```swift
.toolbar {
    ToolbarItem(placement: .confirmationAction) {
        Button("Done") { dismiss() }
    }
}
```

with `@Environment(\.dismiss) private var dismiss`. No other Settings change.

## Test updates (same change)

### `OpenFeelingsUITests/OpenFeelingsUITests.swift`

- `testTabSwitchingShowsEachTabsContent`: the `tab("settings").tap()` + "Settings" title check is invalid (no settings tab). Replace that opening assertion with the **Thoughts** tab: `tab("thoughts").tap()` then assert `app.staticTexts["Thoughts"]` exists. Keep the Direction, Insights, Today checks.
- `testSettingsExposesPeriodSummaryRow`: replace `tab("settings").tap()` with opening the gear: `app.buttons["settings.gear"].firstMatch.tap()` then assert the settings sheet's `Settings` title appears, then the existing scroll-to-row logic (the sheet has its own scroll view — re-query `app.scrollViews.firstMatch` after the sheet presents).
- Update the file's header doc comment that cites `"tab.settings"` as an example → `"tab.today"`, `"tab.thoughts"`.

### `OpenFeelingsUITests/ThoughtRecordWizardUITests.swift`

- `testWizardCarriesEnteredValuesThroughToConfirm`: change `tab("direction").tap()` → `tab("thoughts").tap()`. The Thoughts tab shows `ThoughtRecordsArea` as its only content, so the `thought-record.start` entry is near the top; keep the defensive scroll loop (harmless if no scroll needed).

### Unaffected (verify, don't change)

- `DirectionUITests` asserts the Intentions + Values headers and the sort flow — both stay in Direction. Confirm it makes no reference to thought records (grep showed none).
- `ValueSortRedesignUITests` uses `tab("direction")` for the sort flow — Values stays in Direction. Unaffected.

## Testing

No new tests — this is a restructure of existing surfaces. The existing UI suite (15 tests) is the regression net; the updates above keep it green. Manual smoke: launch, confirm the 5 tabs in order, gear opens Settings modally from each tab with a working Done, Direction shows only Intentions + Values, Thoughts shows the thought-record list + wizard.

## Build sequence

1. `AppNavigation.swift` (enum + `showingSettings`).
2. `SettingsToolbar.swift` modifier.
3. `ThoughtsView.swift`.
4. `DirectionView.swift` (remove ThoughtRecordsArea).
5. `SettingsView.swift` (Done button).
6. `RootView.swift` (reorder tabs, swap Settings→Thoughts, gear on each tab, settings sheet).
7. UI test updates.
8. Build + full unit (404) + full UI (15) + manual smoke.
9. Ship as the next build.

## Out of scope

- No change to any tab's *content* beyond moving ThoughtRecordsArea and adding the gear.
- No change to `ThoughtRecordsArea`, `IntentionsContent`, `ValuesArea`, `CheckInView`, `InsightsView`, `TodayView` internals.
- No new Settings features (just the Done button).
- History remains a push under Today (unchanged).
