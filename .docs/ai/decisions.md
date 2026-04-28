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
