import Foundation
import SwiftData

/// A concrete commitment tied to one value. Standalone from feeling logs.
/// Persists across re-sorts: the `valueRef` is a stable id; if the user's
/// active `ValueSort` drops that value, the action stays in the list with
/// a "(not in current values)" badge instead of disappearing.
@Model
final class CommittedAction {
    var id: UUID = UUID()
    var createdAt: Date = Date()
    var title: String = ""
    var valueRef: String = ""      // "family" or "custom:<uuid>"
    var whatsHard: String = ""     // optional; empty if not provided
    var isDone: Bool = false
    var completedAt: Date?
    var reflection: String = ""    // optional; written after marking done

    init(id: UUID = UUID(),
         createdAt: Date = Date(),
         title: String,
         valueRef: String,
         whatsHard: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.valueRef = valueRef
        self.whatsHard = whatsHard.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isDone = false
        self.completedAt = nil
        self.reflection = ""
    }
}

extension CommittedAction {
    /// Flip to done and stamp the completion time. Idempotent if already done.
    func markDone(at instant: Date = Date()) {
        if isDone { return }
        isDone = true
        completedAt = instant
    }
}
