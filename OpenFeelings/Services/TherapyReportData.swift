import Foundation

/// Pure-value snapshot of what goes into a clinically-filable PDF summary.
/// Built once from `FeelingLog`s + `Intention`s and a chosen window/detail
/// level, then handed to `TherapyReportPDFService` for rendering.
///
/// Reuses `InsightsDataset` for the aggregate math (top cores, day-of-week,
/// avg intensity) so the Insights tab and the therapy export agree on
/// numbers by construction.
struct TherapyReportData {

    enum Window: String, CaseIterable, Identifiable, Hashable, Sendable {
        case last7Days
        case last30Days
        case allTime

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .last7Days:  "Last 7 days"
            case .last30Days: "Last 30 days"
            case .allTime:    "All time"
            }
        }

        /// Mirrors `InsightsPeriod` so we can reuse `InsightsDataset.build`.
        var insightsPeriod: InsightsPeriod {
            switch self {
            case .last7Days:  .week
            case .last30Days: .month
            case .allTime:    .all
            }
        }
    }

    enum DetailLevel: String, CaseIterable, Identifiable, Hashable, Sendable {
        case patternsOnly
        case patternsAndNotable
        case fullEntries

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .patternsOnly:       "Patterns only"
            case .patternsAndNotable: "Patterns + notable entries"
            case .fullEntries:        "Full check-in list"
            }
        }

        var helperText: String {
            switch self {
            case .patternsOnly:
                "Just the aggregates: counts, top emotion cores, day-of-week pattern, average intensity."
            case .patternsAndNotable:
                "Aggregates plus up to five notable entries (highest intensity or those with a note)."
            case .fullEntries:
                "Every check-in in the window, paginated five per page. Longest report."
            }
        }
    }

    let window: Window
    let detailLevel: DetailLevel
    let generatedAt: Date
    let dataset: InsightsDataset
    let intentions: [IntentionSummary]
    let notableLogs: [FeelingLog]
    let allLogs: [FeelingLog]

    static func build(window: Window,
                      detailLevel: DetailLevel,
                      logs: [FeelingLog],
                      intentions: [Intention],
                      now: Date = .now) -> TherapyReportData {
        let dataset = InsightsDataset.build(logs: logs,
                                            period: window.insightsPeriod,
                                            now: now)

        let windowed = filter(logs: logs, window: window, now: now)

        let notable = topNotableLogs(in: windowed, limit: 5)

        let all: [FeelingLog]
        switch detailLevel {
        case .fullEntries:
            all = windowed.sorted { $0.createdAt > $1.createdAt }
        case .patternsOnly, .patternsAndNotable:
            all = []
        }

        let summaries = intentionSummaries(intentions: intentions,
                                           logs: logs,
                                           window: window,
                                           now: now)

        return TherapyReportData(
            window: window,
            detailLevel: detailLevel,
            generatedAt: now,
            dataset: dataset,
            intentions: summaries,
            notableLogs: notable,
            allLogs: all
        )
    }

    // MARK: - Helpers (internal for testing)

    static func filter(logs: [FeelingLog],
                       window: Window,
                       now: Date) -> [FeelingLog] {
        guard let cutoff = window.insightsPeriod.cutoff(now: now) else {
            return logs
        }
        return logs.filter { $0.createdAt >= cutoff }
    }

    /// Top entries to feature in a "notable" page. Sort priority:
    ///   1. Highest intensity (treating nil as 0)
    ///   2. Has a non-empty note (true before false)
    ///   3. Most recent first
    static func topNotableLogs(in logs: [FeelingLog], limit: Int) -> [FeelingLog] {
        logs.sorted { lhs, rhs in
            let li = lhs.intensity ?? 0
            let ri = rhs.intensity ?? 0
            if li != ri { return li > ri }

            let lhsHasNote = !lhs.note.isEmpty
            let rhsHasNote = !rhs.note.isEmpty
            if lhsHasNote != rhsHasNote { return lhsHasNote && !rhsHasNote }

            return lhs.createdAt > rhs.createdAt
        }
        .prefix(limit)
        .map { $0 }
    }

    static func intentionSummaries(intentions: [Intention],
                                   logs: [FeelingLog],
                                   window: Window,
                                   now: Date) -> [IntentionSummary] {
        let cutoff = window.insightsPeriod.cutoff(now: now)
        let inWindow: [Intention]
        if let cutoff {
            inWindow = intentions.filter { $0.date >= cutoff }
        } else {
            inWindow = intentions
        }
        return inWindow
            .sorted { $0.date > $1.date }
            .map { intention in
                IntentionSummary(
                    date: intention.date,
                    text: intention.text,
                    reflection: intention.reflection,
                    topCoreNamesOnDay: IntentionDayFelt.topCoreNames(in: intention.date, logs: logs) ?? []
                )
            }
    }
}

/// Pure value mirror of an `Intention` for inclusion in the report. Avoids
/// retaining the `@Model` reference past data assembly.
struct IntentionSummary: Equatable {
    let date: Date
    let text: String
    let reflection: String
    let topCoreNamesOnDay: [String]
}
