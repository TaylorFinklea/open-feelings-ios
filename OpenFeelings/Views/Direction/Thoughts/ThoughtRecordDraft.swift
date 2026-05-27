import Foundation

/// In-memory wizard state for a thought record. Reference type so that
/// SwiftUI's `@State` + `@Bindable` machinery propagates field writes
/// correctly across NavigationStack push destinations on iOS 26. (See
/// decisions.md 2026-05-27 entry — a struct-typed draft was silently
/// losing writes through `.navigationDestination(for:)`.)
/// Mirrors the pattern of `SortSession`, the other multi-step
/// `@Observable` wizard state class in the codebase.
@Observable
final class ThoughtRecordDraft {
    var id: UUID = UUID()
    var situation: String = ""
    var automaticThought: String = ""
    var intensityBefore: Int?
    var patterns: [ThinkingPattern] = []
    var balancedThought: String = ""
    var intensityAfter: Int?
    var linkedLogID: UUID?

    init() {}

    /// True iff the confirm step's Save button should be enabled. Same rule
    /// as `ThoughtRecord.isSaveable`.
    var isSaveable: Bool {
        let trimmedThought = automaticThought.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBalanced = balancedThought.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedThought.isEmpty
            && !trimmedBalanced.isEmpty
            && intensityBefore != nil
            && intensityAfter != nil
    }

    /// Frozen value-type snapshot of the current draft. The wizard host
    /// captures one of these at sheet-open time and compares against
    /// `snapshot` on every render to decide whether Cancel should confirm.
    /// We can't compare two `ThoughtRecordDraft` references directly —
    /// they'd be the same instance, so any "==" we wrote would be a no-op
    /// for dirty detection.
    struct Snapshot: Equatable {
        let id: UUID
        let situation: String
        let automaticThought: String
        let intensityBefore: Int?
        let patterns: [ThinkingPattern]
        let balancedThought: String
        let intensityAfter: Int?
        let linkedLogID: UUID?
    }

    var snapshot: Snapshot {
        Snapshot(
            id: id,
            situation: situation,
            automaticThought: automaticThought,
            intensityBefore: intensityBefore,
            patterns: patterns,
            balancedThought: balancedThought,
            intensityAfter: intensityAfter,
            linkedLogID: linkedLogID
        )
    }

    /// Pre-fill from a check-in. Used by the "Examine this thought" share-
    /// menu entry on `LogCard`. `situation` becomes `"<pathTitle> · <time>"`,
    /// `intensityBefore` mirrors the log's intensity if set.
    static func from(log: FeelingLog) -> ThoughtRecordDraft {
        let draft = ThoughtRecordDraft()
        draft.linkedLogID = log.id
        let time = log.createdAt.formatted(date: .omitted, time: .shortened)
        let path = log.pathTitle.replacingOccurrences(of: " > ", with: " · ")
        draft.situation = path.isEmpty ? time : "\(path) · \(time)"
        draft.intensityBefore = log.intensity
        return draft
    }

    /// Pre-fill from an existing record (edit flow). Carries the record's
    /// `id` so the confirm step's `apply(to:)` updates that row.
    static func from(record: ThoughtRecord) -> ThoughtRecordDraft {
        let draft = ThoughtRecordDraft()
        draft.id = record.id
        draft.situation = record.situation
        draft.automaticThought = record.automaticThought
        draft.intensityBefore = record.intensityBefore
        draft.patterns = record.patterns
        draft.balancedThought = record.balancedThought
        draft.intensityAfter = record.intensityAfter
        draft.linkedLogID = record.linkedLogID
        return draft
    }

    /// Overwrite the given record's mutable fields. Used by the edit-flow
    /// Save action.
    func apply(to record: ThoughtRecord) {
        record.situation = situation
        record.automaticThought = automaticThought
        record.intensityBefore = intensityBefore
        record.patterns = patterns
        record.balancedThought = balancedThought
        record.intensityAfter = intensityAfter
        record.linkedLogID = linkedLogID
    }

    /// Build a new `ThoughtRecord` from this draft. Used by the new-flow
    /// Save action. The draft's `id` is preserved so a subsequent edit-flow
    /// re-uses the same row.
    func toThoughtRecord() -> ThoughtRecord {
        ThoughtRecord(
            id: id,
            situation: situation,
            automaticThought: automaticThought,
            intensityBefore: intensityBefore,
            patterns: patterns,
            balancedThought: balancedThought,
            intensityAfter: intensityAfter,
            linkedLogID: linkedLogID
        )
    }
}
