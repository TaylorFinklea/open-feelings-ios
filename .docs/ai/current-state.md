# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-05-10

Drill-down v2 per `docs/superpowers/specs/2026-05-10-drill-down-v2-design.md`, following the completed AX label and swipe-to-delete passes.

- **Scope**: `HistoryFilter` now supports core, body-region, and weekday cases; History filtering uses `HistoryView.filteredLogs(_:filter:)`; Insights By core / Body / By day-of-week charts now show the tap-to-filter caption and drill into filtered History with chart overlays.
- **Also completed**: Today/History/Wizard VoiceOver labels committed as `8b0ede0`; History swipe-to-delete committed as `eeada0e`.
- **Tests**: Added `HistoryFilterPredicateTests` and expanded `AppNavigationTests` for new filter labels/equality, on top of the earlier AX and delete tests.
- **Build**: simulator build green; full unit + UI test suite green.

## Build Status

- `xcodegen generate` succeeded.
- `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build` succeeded — BUILD SUCCEEDED.
- `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test` succeeded — 205 unit tests + 5 UI tests pass.

## Blockers

- SourceKit-LSP indexer false-positives (backlogged in `.docs/ai/roadmap.md`) — xcodebuild is clean, IDE diagnostics only.
- Manual VoiceOver / AX5 / Reduce-Motion / Reduce-Transparency / Liquid Glass simulator walkthroughs still pending (will be done by Daisy).
- App Store/device distribution still needs manual Apple Developer/App Store Connect setup, production CloudKit schema deployment, and real-device iCloud sync validation.
- The in-app definitions are educational and clinically informed, but they have not been reviewed by a licensed clinician.
