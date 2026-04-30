import Foundation

enum Greeting {
    /// Returns "Good morning, Name." / "Good afternoon, Name." / "Good evening, Name."
    /// If name is empty or whitespace, drops the comma and name (e.g. "Good morning.").
    static func text(for date: Date, name: String, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let part: String
        switch hour {
        case 5..<12:  part = "Good morning"
        case 12..<17: part = "Good afternoon"
        default:      part = "Good evening"
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "\(part)." : "\(part), \(trimmed)."
    }
}
