# Watch Natural-Language Entry — Design

**Date**: 2026-06-29
**Branch**: `feat/watch-natural-language-entry` (stacked off `feat/natural-language-entry`, which carries the iOS parser this reuses; that branch is on TestFlight 1.0.1/build 44, not yet merged). Merges after the iOS branch.
**Status**: Design — awaiting review before plan
**Builds on**: the iOS natural-language entry (`docs/superpowers/specs/2026-06-26-natural-language-entry-design.md`), now shipping in 1.0.1. This adds the same capability to watchOS by **reusing the existing parser**.

## Problem

Natural-language check-in entry works great on iPhone. The watch still requires tapping through the drill picker (core → secondary → specific → intensity → note). We want to **speak how you feel on the wrist** — both in-app and via a watch Siri Shortcut — and have it become a structured check-in, reusing the deterministic parser we already built.

## Goals

- **In-app dictation:** a "Speak how you feel" entry on the watch → dictate → parse on-watch → high-confidence lands on the existing confirm screen; low/none confidence drops into the existing picker pre-seeded → Send.
- **Watch Siri / App Shortcut:** "Log a feeling in Open Feelings" from the wrist → parse → send the check-in to the phone (frictionless, spoken read-back); when no emotion resolves, open the watch app pre-seeded with the spoken note (mirrors iOS).
- **Reuse, don't rebuild:** the parser is pure Swift; the watch already has a confirm screen and a `WatchCheckInPayload` → phone path. Maximize reuse.
- **Parse on-watch** (not "ship raw text to the phone") — required because the confirm + low-confidence-refine UX needs the parse result on the watch, and it works with no phone nearby.

## Non-Goals

- No on-watch SwiftData store — the watch stays **send-only** (`WatchCheckInPayload` → phone's `WatchSyncService`, which writes the `FeelingLog`).
- No new `captureSource` — watch NL entries stay `captureSource: "watch"` (the `applewatch` glyph already conveys provenance; **YAGNI**, confirmed).
- No body/sensations/context/etc. parsing (parser already targets core fields only).
- No Phase-2 Foundation Models on watch (the iOS Phase 2 is separate; the watch reuses the deterministic `KeywordFeelingParser`).

## Architecture

```
dictation/Siri text ─▶ FeelingParserProvider.current().parse ─▶ ParsedFeeling
   ├─ in-app: seed CheckInWizardState ─▶ confirm (high) / picker (low/none) ─▶ WatchCheckInPayload ─▶ WatchSessionClient.shared.send
   └─ Siri:  ParsedFeeling ─▶ WatchCheckInPayload ─▶ WatchSessionClient.shared.send   (or: stash note + open app on .none)
```

### Make the parser compile for watchOS

The parser is pure Swift, **except** `ParsedFeeling.toDraft()` which returns the iOS-only `CheckInDraft`. Verified: that one method is the *only* iOS dependency across the four files.

- **Split:** move `ParsedFeeling.toDraft()` into a new **iOS-only** file `OpenFeelings/Views/CheckInWizard/ParsedFeeling+Draft.swift` (an extension). `OpenFeelings/NaturalLanguage/ParsedFeeling.swift` keeps just the struct + `Confidence` enum (Foundation-only).
- **Add to the watch target** (explicit entries in `project.yml`, after the existing `EmotionTaxonomy.swift` entry; the watch target lists sources individually):
  - `OpenFeelings/NaturalLanguage/ParsedFeeling.swift`
  - `OpenFeelings/NaturalLanguage/FeelingParser.swift`
  - `OpenFeelings/NaturalLanguage/FeelingSynonyms.swift`
  - `OpenFeelings/NaturalLanguage/EmotionTaxonomy+Lookup.swift`
  - **Do NOT** add the whole `NaturalLanguage/` directory — it also holds `PendingQuickEntryStore.swift` (iOS-only). Run `xcodegen generate` after.
- The iOS `ParsedFeeling+Draft.swift` lives under `Views/` and is **not** in the watch source list, so it stays iOS-only automatically.

### Map `ParsedFeeling` → the watch wizard state

`CheckInWizardState` (watch, `@MainActor @Observable`) holds `core/secondary/specific: Emotion…?`, `intensity: Int` (non-optional, default 3), `note: String`, plus body fields and `didSend`. New watch-only extension (`OpenFeelingsWatch/Services/CheckInWizardState+ParsedFeeling.swift`):

```
extension CheckInWizardState {
    func apply(_ parsed: ParsedFeeling) {
        core = parsed.core
        secondary = parsed.secondary
        specific = parsed.specific
        intensity = parsed.intensity ?? 3   // watch always records an intensity; 3 is the neutral default
        note = parsed.note
    }
}
```

Mutates the existing environment `wizard` (the watch flow shares one instance), parallel to iOS `toDraft()`. Body fields untouched (NL doesn't parse them). Note the semantic: unlike iOS (no-intensity → unrecorded), the watch has *always* recorded an intensity, so a missing parse defaults to 3 — consistent with the watch's existing IntensityPicker default.

### Hoist `WatchSessionClient` to a shared instance

**Critical** (the watch analog of the iOS shared-`ModelContainer` hoist). `WatchSessionClient` (`@MainActor @Observable`) wraps the `WCSession.default` singleton, sets *itself* as the session delegate, and owns a durable on-disk send queue (`WatchSendQueue.json`) with auto-retry. An AppIntent that instantiated its own `WatchSessionClient()` would register a **second delegate** on the same singleton session and a competing queue — racing the app's. So:

- Add `static let shared = WatchSessionClient()` (one process-wide instance).
- `OpenFeelingsWatchApp` consumes `WatchSessionClient.shared` instead of creating its own `@State` (it still wires `settingsStore` onto it post-construction).
- The in-app flow and the Siri intent both call `WatchSessionClient.shared.send(payload)` — one delegate, one durable queue, auto-retry, queues when the phone is unreachable.
- watchOS in-process AppIntents run in the app's process, so `.shared` lazily activates on first use whether the app is foregrounded or launched by Siri.

## Surface 1 — In-app dictation

- **Entry point.** Add a **"Speak how you feel"** button to `CheckInRootView`'s root view (alongside the existing picker root). New `Step.dictation`.
- **`DictationEntryView`** (new, `OpenFeelingsWatch/Views/`) — mirrors `NoteEntryView`: a focused `TextField("Dictate or type", text:, axis: .vertical)` (watchOS auto-presents dictation/scribble on focus — no Speech framework). A "Continue" button runs `await FeelingParserProvider.current().parse(text)`.
- **Routing on the parse result.** First **`wizard.reset()`** then `wizard.apply(parsed)`, then set `path` (mirroring the screenshot-mode seeding at `CheckInRootView.swift:214-239`). **The `reset()` is required** — the watch shares ONE `wizard` instance and the only other reset is the post-send "New Check-In" button (`startOver()`); without it, a second entry in a session inherits a stale `didSend == true`, so the confirm screen shows "Sent" with **no Send button** and discards the new entry, and stale body fields leak into the payload. Routes:
  - **`.high` with a parsed intensity** → `path = [.confirm]` — confirm shows feeling path + intensity + note + **Send**.
  - **`.high` with NO parsed intensity** → `path = [.intensity]`. The confirm screen's intensity is **read-only**, and common utterances ("I'm anxious", "feeling happy") parse high-confidence with no intensity cue → they'd silently send the neutral default 3 with no way to adjust. Routing through the existing `IntensityPicker` first (it already guards `wizard.core != nil`) lets the user dial it → Continue → confirm. Zero new UI.
  - **`.low`** (a core resolved, weakly) → `path = [.secondary]` — the existing picker pre-seeded at the best core; the user refines secondary/specific and passes through `IntensityPicker`; note pre-filled.
  - **`.none`** (no core) → `path = [.core]` — the unconditional core picker. **Not** `path = []`, which renders the body-region picker in body-first mode. `wizard.note` (set by `apply`) carries through to the payload.
- Save is the **existing confirm-screen `sendPayload()`** (high path) or the existing picker→confirm→send (low/none). No new send code in-app. captureSource on the phone stays `"watch"`.

## Surface 2 — Watch Siri / App Shortcut

- New `OpenFeelingsWatch/AppIntents/` (auto-globbed into the watch target; no `project.yml` change): `WatchCheckInIntent` (`AppIntent`, one natural-language `String` parameter), `WatchAppShortcuts` (`AppShortcutsProvider`, phrase *"Log a feeling in Open Feelings"*), and `OpenWatchCheckInIntent` (tiny app-opener for the `.none` hand-off). No entitlement / Info.plist / extension needed (watchOS 26 target).
- **Testable core** — factor a pure `static func run(...)` (mirrors iOS `LogFeelingIntent.run`) that parses and returns an outcome + the built payload, so the WCSession side-effect is out of the unit test:
  - **`.high`/`.low`** (core resolved) → build `WatchCheckInPayload` from the parse (coreID/coreName + optional secondary/specific + `intensity` (parsed `?? 3`) + note) → `WatchSessionClient.shared.send(payload)` → `IntentDialog` read-back using the resolved node title (e.g. *"Logged Anxious. Open Feelings to add more."*; low adds *"— open the app to pin it down"*).
  - **`.none`** (no core) → `PendingWatchEntryStore().stash(rawUtterance)` and **open the app** via `return .result(opensIntent: OpenWatchCheckInIntent(), dialog: …)`; saves nothing itself.
  - `perform()` is `@MainActor`, calls `run(...)`, and sends via `WatchSessionClient.shared`.
- **`PendingWatchEntryStore`** (new, `OpenFeelingsWatch/Services/`) — mirrors the iOS `PendingQuickEntryStore` exactly: `UserDefaults.standard`, key `"pendingWatchEntryNote"`, `stash` / read-once `take()`. (Plain `.standard` is fine — the watch intent and app share one process/container; no app group needed.)
- **Consumption:** `CheckInRootView` `.onAppear` + `.onChange(of: scenePhase)` → `PendingWatchEntryStore().take()` → **`wizard.reset()`** (same stale-state guard as the in-app route), set `wizard.note = note`, then `path = [.core]` so the user picks the emotion (note already filled). Parallels iOS `RootView` consumption.

> **VERIFY-AGAINST-DOCS (one item):** the conditional app-open from a watchOS `AppIntent` (`.result(opensIntent:dialog:)`). The iOS side confirmed this overload exists in the iOS 26 `AppIntents.swiftinterface`; confirm the same for the watchOS SDK before relying on it (fallback: drop the dialog, `return .result(opensIntent: OpenWatchCheckInIntent())`, let the opener carry the line). Cover the open behavior with a manual device check (not unit-testable).

## Error handling

- `FeelingParser.parse` cannot throw; worst case `.none` / `core: nil` / `note: rawUtterance` — the spoken words are never lost (in-app: routed to picker with note; Siri: stashed + app opens).
- `WatchSessionClient.send` already persists to its disk queue and retries via `transferUserInfo` when the phone is unreachable — no new offline handling.
- Dictation is the system keyboard's; no permission/recording state we own.

## Testing

watchOS uses **XCTest** (`@MainActor final class … : XCTestCase`, no Swift Testing), run on the **"OF Watch Test"** sim (Apple-Watch-Series-11-42mm) via the `OpenFeelingsWatch` scheme. **No watchOS XCUITest** (unreliable on this toolchain — unit-test the `@Observable` state instead). The parser's behavior is already fully covered by the iOS `FeelingParserTests` (15/15) — the watch only needs the seam:

- **`OpenFeelingsWatchTests/CheckInWizardStateMapperTests.swift`** — `apply(_:)` maps core-only+note, secondary+intensity, and `nil` intensity → 3 (mirrors iOS `ParsedFeelingTests`, targeting `CheckInWizardState`).
- **`OpenFeelingsWatchTests/FeelingParserWatchSmokeTests.swift`** — one `async` test that `FeelingParserProvider.current().parse("really anxious")` resolves on watchOS (proves the parser links + runs in the watch target).
- **`OpenFeelingsWatchTests/PendingWatchEntryStoreTests.swift`** — stash → read-once → cleared; empty → nil (mirrors iOS `PendingQuickEntryStoreTests`).
- **`OpenFeelingsWatchTests/WatchCheckInIntentTests.swift`** — the pure `run(...)`: high/low builds a `WatchCheckInPayload` with the right core/intensity/note + a `.saved` outcome; `.none` stashes the utterance + returns `.handedOff` (injected `PendingWatchEntryStore`), no payload.
- **iOS regression guard:** after the `toDraft` split, the existing iOS `ParsedFeelingTests` + `FeelingParserTests` must still pass (the split is behavior-preserving).
- **Manual device check** (not unit-testable): on a real watch, the "Log a feeling" Shortcut sends a `watch` entry that appears on the phone; an unrecognizable phrase opens the watch app pre-seeded.

## File structure

- **Modify** `OpenFeelings/NaturalLanguage/ParsedFeeling.swift` — remove `toDraft()` (keep struct + enum).
- **Create** `OpenFeelings/Views/CheckInWizard/ParsedFeeling+Draft.swift` — `toDraft()` extension (iOS only).
- **Modify** `project.yml` — add the 4 NaturalLanguage files to the watch target; `xcodegen generate`.
- **Create** `OpenFeelingsWatch/Services/CheckInWizardState+ParsedFeeling.swift` — `apply(_:)` mapper.
- **Modify** `OpenFeelingsWatch/Services/WatchSessionClient.swift` — add `static let shared`.
- **Modify** `OpenFeelingsWatch/OpenFeelingsWatchApp.swift` — consume `WatchSessionClient.shared`.
- **Create** `OpenFeelingsWatch/Views/DictationEntryView.swift`.
- **Modify** `OpenFeelingsWatch/Views/CheckInRootView.swift` — "Speak" entry + `.dictation` Step + parse/seed/route + pending-note consumption.
- **Create** `OpenFeelingsWatch/AppIntents/WatchCheckInIntent.swift`, `WatchAppShortcuts.swift`, `OpenWatchCheckInIntent.swift`.
- **Create** `OpenFeelingsWatch/Services/PendingWatchEntryStore.swift`.
- **Create** the four `OpenFeelingsWatchTests/*Tests.swift` above.

## Decisions (resolved in review, 2026-06-29)

1. **Scope** → in-app dictation **and** a watch Siri Shortcut.
2. **In-app review** → confirm screen for high confidence; pre-seeded picker for low (and core picker for none) — no wrong guess sent silently.
3. **Siri `.none`** → open the watch app pre-seeded with the spoken note (mirror iOS); never lose the words.
4. **captureSource** → stays `"watch"` for all watch entries (no new source/glyph).
5. **Read-only-intensity gap (review-found)** → high-confidence-with-no-parsed-intensity routes through `IntensityPicker` (`path = [.intensity]`), not straight to the read-only confirm, so the user sets intensity intentionally instead of silently sending the default 3.
6. **Stale shared-wizard guard (review-found)** → every NL seed (in-app dictation + Siri pending consumption) calls `wizard.reset()` first, since the watch shares one `wizard` instance and a prior send leaves `didSend == true`.

## Open question for review

- **Siri happy-path read-back wording on the tiny screen / audio** — fine to keep it short (*"Logged Anxious."*), or do you want it to also state the intensity when parsed (*"Logged Anxious, 4."*)? (iOS states intensity; the watch can mirror or stay terser.)
