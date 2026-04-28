# Roadmap

> Durable goals and milestones. Updated when scope changes, not every session.

## Vision

Open Feelings is a free, MIT-licensed, local-first iOS app for private emotion check-ins using a complete feelings wheel and a calmer guided wizard.

## Now / Next / Later

<!-- Active items. Trim as completed; no claim markers — first agent to pick it up writes it. -->

### Now
- [x] Build the initial iOS app scaffold with wizard and wheel check-in flows.
- [x] Add local persistence, iCloud/CloudKit configuration, reminders, Face ID app lock, export, and optional Apple Health writing.
- [ ] Configure Apple Developer team, CloudKit container, HealthKit capability, and production signing in Xcode.

### Next
- [ ] Add app icon, launch branding, and App Store privacy policy copy.
- [ ] Manually validate iCloud sync between two signed-in devices.
- [ ] Add UI tests for check-in flows and export entry points.

### Later
- [ ] Consider richer reflection prompts, charts, and Apple Health read/import support after v1 privacy review.

## Milestones

### M1: Usable Local-First Check-In App
- [x] Original MIT emotion taxonomy
- [x] Wheel and wizard input
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

## Constraints

- MIT-only source, assets, and emotion taxonomy.
- No ads, analytics, accounts, servers, or third-party SDKs.
- Data remains on device and in the user's private iCloud database.
- Target latest SDK/iOS 26 for v1.
