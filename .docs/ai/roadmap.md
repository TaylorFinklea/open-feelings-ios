# Roadmap

> Durable goals and milestones. Updated when scope changes, not every session.

## Vision

Open Feelings is a free, local-first iOS app for private emotion check-ins using an attributed complete feelings wheel and a calmer guided wizard. Source code remains MIT licensed; the adapted emotion taxonomy is separately attributed and licensed.

## Now / Next / Later

<!-- Active items. Trim as completed; no claim markers — first agent to pick it up writes it. -->

### Now
- [x] Build the initial iOS app scaffold with wizard and wheel check-in flows.
- [x] Add local persistence, iCloud/CloudKit configuration, reminders, Face ID app lock, export, and optional Apple Health writing.
- [x] Replace the original taxonomy with an attributed Open Emotion Wheel v1.1 adaptation and color-coded wheel/wizard UI.
- [x] Add wheel pinch zoom, rotation, zoomed panning, and reset interactions.
- [x] Add clinically informed educational definitions for selected emotions.
- [x] Redesign: 5-tab IA scaffold, warm-calm design tokens, new components, Today/History/Settings re-skin, save-bounce ribbon, WCAG AA contrast audit + fixes, reduce-motion gating.
- [ ] Review the definition copy with the therapist or another licensed clinician before release.
- [ ] Configure production CloudKit schema and App Store distribution settings.
- [ ] Manual VoiceOver / AX5 / Reduce-Motion / Reduce-Transparency / Liquid Glass simulator walkthroughs (Daisy).

### Next
- [ ] Add app icon, launch branding, and App Store privacy policy copy.
- [ ] Manually validate iCloud sync between two signed-in devices.
- [ ] Review the Open Emotion Wheel attribution/license presentation before release.
- [ ] Add UI tests for check-in flows and export entry points.
- [ ] Insights surface — functional (charts, trends, week/month views).
- [ ] Therapy-bridge export (structured PDF / shareable summary for therapist sessions).
- [ ] Richer check-in fields — data + UI (body, context, triggers/coping, mood scale).
- [ ] Intentions surface — functional (set daily intentions, track completion).

### Later
- [ ] Consider richer reflection prompts, charts, and Apple Health read/import support after v1 privacy review.

## Milestones

### M1: Usable Local-First Check-In App
- [x] Attributed Open Emotion Wheel v1.1 taxonomy adaptation
- [x] Wheel and wizard input
- [x] Interactive wheel viewport gestures
- [x] Definition text for selected emotions
- [x] Local logs, export, reminders, app lock, and optional Apple Health writing

### M2: Release Readiness
- [ ] Signing, CloudKit production schema, privacy policy, app icon, manual sync QA

## Backlog

> Self-contained items any agent can execute. Each entry should include scope, file paths, acceptance criteria, verification steps, and a prose tier hint ("Haiku candidate", "Sonnet — multi-file", "needs Opus to scope").

<!-- Format example:
### Add foo to bar
**Scope**: …
**Files**: `path/to/file.ts:42`
**Acceptance**: …
**Verify**: `npm test -- foo`
**Tier hint**: Sonnet — touches 2 files, no design decisions
-->

### Wire accessibilityIdentifiers for XCUITest on iOS 26 Liquid Glass tab bar
**Scope**: A first attempt at adding a UI test target was reverted on 2026-04-30. The blocker: iOS 26's Liquid Glass tab bar exposes its items as `_UIFloatingTabBarItemCell` / `_UIFloatingTabBarItemView`, not as `UITabBarButton`. XCUITest's `app.tabBars.buttons["Today"]` selector matches nothing; `tabBars.cells["Today"]` also fails to resolve. The fix is to add explicit `.accessibilityIdentifier(...)` strings to each tab item so XCUITest can find them by ID rather than by automation type. Once tabs are addressable, add a UITest target with smoke tests covering: cold launch → Today selected; tab switching; wizard happy path → Save enabled; Settings toggle visibility; History list rendered after a save.
**Files**: `project.yml` (add `OpenFeelingsUITests` target with `type: bundle.ui-testing`); `OpenFeelings/Views/RootView.swift` (add `.accessibilityIdentifier("tab.<name>")` to each `Label` inside `.tabItem { ... }`); new `OpenFeelingsUITests/OpenFeelingsUITests.swift`.
**Acceptance**: The UI test target builds. At least 4 smoke tests pass on iPad (A16) iOS 26.0.1: cold-launch, tab-switch, wizard happy path, Settings rows. Tests use `app.descendants(matching: .any).matching(identifier: "tab.today")` (or equivalent) — not `tabBars.buttons[...]`.
**Verify**:
```sh
xcodegen generate
xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test -only-testing:OpenFeelingsUITests
```
**Tier hint**: Sonnet — small `project.yml` change, light `RootView` annotation, ~80 lines of XCUITest. Mostly mechanical once the iOS 26 element-tree pattern is understood.


- Emotion taxonomy content is adapted from Open Emotion Wheel v1.1 and must preserve Open Emotion Wheel attribution and CC BY-SA 4.0 licensing.
- Emotion definitions are original educational summaries with reference-source documentation; they must not be presented as diagnosis or treatment advice.
- No ads, analytics, accounts, servers, or third-party SDKs.
- Data remains on device and in the user's private iCloud database.
- Target latest SDK/iOS 26 for v1.
