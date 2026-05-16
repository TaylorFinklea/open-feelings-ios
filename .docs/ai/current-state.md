# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-05-15

Shipped builds 19 through 27 to TestFlight across several sessions. Biggest landings:

- **Values + Direction tab (build 27)**: Renamed the Intentions tab to Direction and added a four-phase sort flow (bucket → pick finalists → rank → confirm) over a 50-item `ValueTaxonomy` deck plus user `CustomValue`s. Persists the latest sort as a `ValueSort`. Adds a `CommittedAction` model with title/value/what's-hard/reflection plus mark-done lifecycle, surfaced in `ValuesArea` with an `info.circle` definition sheet on each ranked value. 23 new unit tests; 293 total.
- **Custom body regions (build 27)**: `CustomBodyRegion` model, `FeelingLog.customBodyRegionIDsRaw` field, generalized `BodyEmotionMap.suggestedCores(...)` to fold custom-region learnings, `LearnedBodyMap.customCounts/Totals` with the same ≥5/≥60% threshold, and a Settings UI to manage regions.
- **Watch app (builds 21–26)**: Added `OpenFeelingsWatch` target and check-in flow: drill picker with stop-at-any-level + body flow, NavigationStack path so swipe-back works, drill value carried in nav path to avoid blank screen, `@Observable` wizard state on watch root, settings synced from iOS so watch flow stays aligned.
- **Earlier (builds 19–20)**: Fixed upside-down therapy report PDF.

## Build Status

- `xcodegen generate` succeeded.
- Full unit test suite: **293 passing** (XCTest on iPhone simulator).
- Build 27 archive + export + upload to App Store Connect via App Store Connect API key — `** EXPORT SUCCEEDED **`.

## Blockers

- SourceKit-LSP indexer false-positives still occasionally noisy — xcodebuild is clean, IDE diagnostics only.
- Manual VoiceOver / AX5 / Reduce-Motion / Reduce-Transparency / Liquid Glass simulator walkthroughs still pending (Daisy).
- Manual on-device verification of the Direction tab + sort flow + committed actions for build 27 (Task 13 of the Values plan) still pending; will surface naturally when the user runs the TestFlight build.
- App Store/device distribution still needs production CloudKit schema deployment and real-device iCloud sync validation between two signed-in devices.
- The in-app definitions are educational and clinically informed, but they have not been reviewed by a licensed clinician.
