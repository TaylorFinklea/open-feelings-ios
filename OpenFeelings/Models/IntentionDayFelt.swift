import Foundation

/// Pure-logic helper for the Intentions look-back: derives the top N core
/// names for a given calendar day from a list of FeelingLogs. Used to render
/// the "felt: X, Y" subtitle on each past-intention row.
enum IntentionDayFelt {
    /// Returns up to `limit` core names (by count, descending; alphabetical
    /// tiebreak) for logs whose createdAt falls within `day`'s
    /// start..<end. Returns nil if no logs in the window.
    static func topCoreNames(in day: Date,
                             logs: [FeelingLog],
                             limit: Int = 2,
                             calendar: Calendar = .current) -> [String]? {
        let dayStart = calendar.startOfDay(for: day)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        let dayLogs = logs.filter { $0.createdAt >= dayStart && $0.createdAt < dayEnd }
        guard !dayLogs.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for log in dayLogs where !log.coreName.isEmpty {
            counts[log.coreName, default: 0] += 1
        }
        return counts
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }
            .prefix(limit)
            .map(\.key)
    }
}
