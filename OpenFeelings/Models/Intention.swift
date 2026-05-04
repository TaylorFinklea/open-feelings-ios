import Foundation
import SwiftData

/// A free-text daily intention. One per day max — the IntentionsView upserts
/// by `date` (normalized to start-of-day) so re-saving on the same day mutates
/// the existing row rather than creating a duplicate.
@Model
final class Intention {
    var id: UUID = UUID()
    var date: Date = Date()
    var text: String = ""

    init(id: UUID = UUID(), date: Date = Date(), text: String) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.text = text
    }
}
