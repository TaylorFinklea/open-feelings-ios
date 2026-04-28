# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-04-28

- Replaced the original app-authored taxonomy with an adapted Open Emotion Wheel v1.1 taxonomy and added in-app/docs attribution under CC BY-SA 4.0.
- Reworked the wheel renderer to use taxonomy leaf counts for sector sizing, per-feeling colors, radial labels, and tap hit-testing from the generated layout.
- Added color-coded wizard choices, selected-feeling accents, a warmer check-in background, and persisted Wizard/Wheel mode selection.
- Kept the app bundle, provisioning, and CloudKit identifiers on `dev.finklea.openfeelings` / `iCloud.dev.finklea.openfeelings`.
- Added a simulator-only local SwiftData store so unsigned simulator launches do not crash on missing CloudKit entitlements.

## Build Status

- Project generation: `xcodegen generate` succeeded.
- iOS device build: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphoneos -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- iOS simulator tests: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test` succeeded, 8/8 tests passing.
- Signed generic iOS build: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination generic/platform=iOS -derivedDataPath DerivedData build` succeeded using the `dev.finklea.openfeelings` provisioning profile.
- Simulator launch checks succeeded on iPad (A16) and a temporary iPhone 17 simulator; wheel screenshots showed readable labels without the prior text collision.

## Blockers

- App Store/device distribution still needs manual Apple Developer/App Store Connect setup, production CloudKit schema deployment, and real-device iCloud sync validation.
