import Foundation
import SwiftData

/// One CBT thought-record entry. Mirrors the Burns "Feeling Good" five-step
/// shape with intensity split into before/after for an explicit visual of
/// whether the reframe shifted the feeling. Pure-string + Int? storage keeps
/// the schema CloudKit-clean (every field has a default or is Optional).
@Model
final class ThoughtRecord {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var situation: String = ""
    var automaticThought: String = ""
    var intensityBefore: Int?
    /// Comma-joined `ThinkingPattern.rawValue` list. Use the `patterns`
    /// computed accessor to read/write a typed array.
    var patternsRaw: String = ""
    var balancedThought: String = ""
    var intensityAfter: Int?
    /// Optional foreign key to a `FeelingLog.id`. Bare UUID, no relationship —
    /// matches the `CommittedAction.valueRef` pattern.
    var linkedLogID: UUID?

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         situation: String = "",
         automaticThought: String = "",
         intensityBefore: Int? = nil,
         patterns: [ThinkingPattern] = [],
         balancedThought: String = "",
         intensityAfter: Int? = nil,
         linkedLogID: UUID? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.situation = situation
        self.automaticThought = automaticThought
        self.intensityBefore = intensityBefore
        self.patternsRaw = ThinkingPattern.encodeList(patterns)
        self.balancedThought = balancedThought
        self.intensityAfter = intensityAfter
        self.linkedLogID = linkedLogID
    }
}

extension ThoughtRecord {
    var patterns: [ThinkingPattern] {
        get { ThinkingPattern.parseList(patternsRaw) }
        set { patternsRaw = ThinkingPattern.encodeList(newValue) }
    }

    /// `intensityBefore - intensityAfter`. Positive means the reframe reduced
    /// the felt intensity; zero means no change; negative means it got
    /// worse. Nil when either field is missing.
    var intensityDelta: Int? {
        guard let before = intensityBefore, let after = intensityAfter else { return nil }
        return before - after
    }

    /// True iff all four required fields are populated (whitespace-trimmed
    /// non-empty thought + balanced thought, both intensities chosen).
    /// Drives Save-button enablement on the wizard's confirm step.
    var isSaveable: Bool {
        let trimmedThought = automaticThought.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBalanced = balancedThought.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedThought.isEmpty
            && !trimmedBalanced.isEmpty
            && intensityBefore != nil
            && intensityAfter != nil
    }
}
