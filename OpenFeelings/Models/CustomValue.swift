import Foundation
import SwiftData

/// User-added value. Lives alongside the curated `ValueTaxonomy`
/// so users can add idiosyncratic values during a sort.
/// CloudKit-synced through the same private DB as other models.
@Model
final class CustomValue {
    /// Stable identifier referenced from `ValueSort.rankedTopRaw`,
    /// `ValueSort.bucketAssignmentsRaw`, and `CommittedAction.valueRef`
    /// via the `"custom:<uuid>"` form. Survives renames.
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

extension CustomValue {
    static func sortedByCreation(_ values: [CustomValue]) -> [CustomValue] {
        values.sorted { $0.createdAt < $1.createdAt }
    }
}
