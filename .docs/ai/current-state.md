# Current State

> Updated at the end of every work session. Read this first.

## Active Branch

`main`

## Last Session Summary

**Date**: 2026-04-28

- Created the initial Open Feelings iOS app scaffold with SwiftUI, SwiftData, CloudKit entitlements, HealthKit entitlements, and XcodeGen project generation.
- Implemented the original MIT emotion taxonomy, full three-ring wheel, guided wizard check-in flow, history list, CSV/JSON export, optional app lock, optional reminders, and optional write-only Apple Health State of Mind saving.
- Added XCTest coverage for taxonomy shape, selection lookup, export formatting, and HealthKit mapping.
- Generated `OpenFeelings.xcodeproj` from `project.yml`.
- Updated the app and test bundle IDs to `dev.finklea.openfeelings`, moved team `K7CBQW6MPG` into `project.yml`, and changed the CloudKit container to `iCloud.dev.finklea.openfeelings`.

## Build Status

- iOS device build: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphoneos -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO build` succeeded.
- iOS simulator tests: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad (A16),OS=26.0.1' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test` succeeded, 7/7 tests passing.
- Signed generic iOS build: `xcodebuild -project OpenFeelings.xcodeproj -scheme OpenFeelings -destination generic/platform=iOS -derivedDataPath DerivedData build` succeeded using the `dev.finklea.openfeelings` provisioning profile.

## Blockers

- App Store/device distribution still needs the `iCloud.dev.finklea.openfeelings` container/capabilities configured in the Apple Developer portal.
