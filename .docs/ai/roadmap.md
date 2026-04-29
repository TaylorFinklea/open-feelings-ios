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
- [ ] Configure production CloudKit schema and App Store distribution settings.

### Next
- [ ] Add app icon, launch branding, and App Store privacy policy copy.
- [ ] Manually validate iCloud sync between two signed-in devices.
- [ ] Review the Open Emotion Wheel attribution/license presentation before release.
- [ ] Add UI tests for check-in flows and export entry points.

### Later
- [ ] Consider richer reflection prompts, charts, and Apple Health read/import support after v1 privacy review.

## Milestones

### M1: Usable Local-First Check-In App
- [x] Attributed Open Emotion Wheel v1.1 taxonomy adaptation
- [x] Wheel and wizard input
- [x] Interactive wheel viewport gestures
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

- Source code is MIT licensed.
- Emotion taxonomy content is adapted from Open Emotion Wheel v1.1 and must preserve Open Emotion Wheel attribution and CC BY-SA 4.0 licensing.
- No ads, analytics, accounts, servers, or third-party SDKs.
- Data remains on device and in the user's private iCloud database.
- Target latest SDK/iOS 26 for v1.
