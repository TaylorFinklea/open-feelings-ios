# Decisions

> Architecture decision records. Append-only — one entry per decision.

<!-- Template for each entry:

## [YYYY-MM-DD] Decision Title

**Context**: What prompted this decision?
**Decision**: What was chosen?
**Alternatives considered**: What else was evaluated?
**Rationale**: Why this over the alternatives?
-->

## [2026-04-28] Use Original MIT Emotion Taxonomy

**Context**: The app needs a complete feelings wheel while remaining fully MIT licensed.
**Decision**: Use an original 8 x 4 x 3 taxonomy authored for this app rather than copying Junto, Willcox, or CC BY-SA wheel content.
**Alternatives considered**: Reusing Open Emotion Wheel under CC BY-SA, or matching familiar copyrighted wheel layouts.
**Rationale**: Original content keeps the whole repo MIT-compatible and avoids licensing ambiguity around wheel text and arrangement.

## [2026-04-28] Local-First SwiftData With Optional Apple Platform Integrations

**Context**: The app should store everything locally, sync through iCloud, and optionally tap Apple Health.
**Decision**: Use SwiftData with a private CloudKit database configuration for app logs, local notifications for reminders, LocalAuthentication for app lock, and write-only HealthKit State of Mind samples when explicitly enabled.
**Alternatives considered**: A custom CloudKit layer, Core Data, third-party sync, or reading broader Health data in v1.
**Rationale**: SwiftData/CloudKit matches the local-first iCloud requirement with minimal infrastructure, and write-only HealthKit limits privacy and review scope for v1.

## [2026-04-28] Use Open Emotion Wheel Taxonomy With Separate Content License

**Context**: The user wanted an attributed feelings wheel a therapist is more likely to accept than an app-authored taxonomy, and was open to a non-MIT content license if attribution is required.
**Decision**: Supersede the original MIT emotion taxonomy with an adapted Open Emotion Wheel v1.1 taxonomy by David Thorpe. Keep source code under MIT, and document the adapted taxonomy content under CC BY-SA 4.0 in `ATTRIBUTION.md`, `DATA-LICENSE.md`, and Settings.
**Alternatives considered**: Keeping the original app-authored MIT taxonomy, copying familiar copyrighted wheel layouts, or using Geneva Emotion Wheel materials with unclear/non-free distribution terms for this app.
**Rationale**: Open Emotion Wheel provides explicit attribution and reuse terms, includes therapist/counsellor use language, and avoids unlicensed copying of familiar wheel content.

## [2026-04-28] Disable CloudKit Store For Simulator Builds

**Context**: Unsigned simulator launches do not carry the CloudKit entitlement needed by SwiftData's CloudKit-backed configuration, causing simulator-only startup crashes.
**Decision**: Use an in-memory store for tests, a local SwiftData store for simulator builds, and the private CloudKit-backed store for device builds.
**Alternatives considered**: Requiring signed simulator builds, adding launch-only test hooks, or disabling CloudKit for all debug builds.
**Rationale**: This keeps simulator development reliable without changing the real device/App Store CloudKit behavior.
