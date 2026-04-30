import Foundation

struct WeekSummary: Equatable, Sendable {
    let topCoreID: String
    let topCoreName: String
    let totalCount: Int

    /// Most-frequent core + total count over the trailing 7 days from `now`.
    /// Returns nil when there are no logs inside the window.
    /// Tie-break favors the most-recently-logged core (closest to `now`).
    static func summarize(logs: [FeelingLog], now: Date = Date()) -> WeekSummary? {
        let cutoff = now.addingTimeInterval(-7 * 86_400)
        let recent = logs.filter { $0.createdAt >= cutoff }
        guard !recent.isEmpty else { return nil }

        // Sort newest-first so the tie-break can prefer the core that appeared earliest in this list.
        let sorted = recent.sorted { $0.createdAt > $1.createdAt }
        var counts: [String: Int] = [:]
        var firstSeenName: [String: String] = [:]
        var firstSeenIndex: [String: Int] = [:]
        for (i, log) in sorted.enumerated() {
            counts[log.coreID, default: 0] += 1
            if firstSeenName[log.coreID] == nil {
                firstSeenName[log.coreID] = log.coreName
                firstSeenIndex[log.coreID] = i
            }
        }

        // Pick the top by count; on ties, pick the core whose first appearance
        // was earliest in the descending-sorted list (i.e., most recent in time).
        let top = counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return (firstSeenIndex[lhs.key] ?? 0) > (firstSeenIndex[rhs.key] ?? 0)
        }!

        return WeekSummary(
            topCoreID: top.key,
            topCoreName: firstSeenName[top.key] ?? top.key.capitalized,
            totalCount: recent.count
        )
    }
}
