import Foundation
import SwiftData

/// A free-text daily intention. One per day max — the IntentionsView upserts
/// by `date` (normalized to start-of-day) so re-saving on the same day mutates
/// the existing row rather than creating a duplicate.
///
/// `reflection` is filled in *after* the day, on the look-back list. Empty
/// string means "not yet reflected on" rather than "explicitly empty".
@Model
final class Intention {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""
    var reflection: String = ""

    init(id: UUID = UUID(),
         date: Date = Date(),
         text: String,
         reflection: String = "") {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.text = text
        self.reflection = reflection
    }

    /// Trims surrounding whitespace and newlines. Used by the reflection
    /// editor before assigning to `reflection` — keeps "   " from looking
    /// like a real reflection but also like an empty one.
    static func normalizedReflection(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
