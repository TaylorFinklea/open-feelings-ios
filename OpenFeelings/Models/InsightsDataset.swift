import Foundation

/// Time window the user is viewing on the Insights tab.
enum InsightsPeriod: String, CaseIterable, Hashable, Sendable, Identifiable {
    case week, month, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week:  "Week"
        case .month: "Month"
        case .all:   "All"
        }
    }

    /// Returns the cutoff Date for filtering. nil = no cutoff (.all).
    func cutoff(now: Date = Date()) -> Date? {
        switch self {
        case .week:  now.addingTimeInterval(-7 * 86_400)
        case .month: now.addingTimeInterval(-30 * 86_400)
        case .all:   nil
        }
    }
}

/// Aggregated view over an array of FeelingLogs scoped to a period. Pure value
/// type — no SwiftUI, no SwiftData context. Computed once per (logs, period)
/// change in InsightsView.
struct InsightsDataset {
    let totalCount: Int
    let countsPerDay: [DayCount]
    let topFeelings: [FeelingCount]      // top 5 secondary names
    let topBodyRegions: [BodyRegionCount]  // top 5
    let topTriggerCopingPairs: [TriggerCopingPair]     // top 5
    let moodPoints: [MoodPoint]

    struct DayCount: Equatable {
        let day: Date
        let count: Int
    }

    struct FeelingCount: Equatable {
        let name: String
        let count: Int
    }

    struct BodyRegionCount: Equatable {
        let region: BodyRegion
        let count: Int
    }

    struct MoodPoint: Equatable {
        let energy: Double
        let valence: Double
        let date: Date
    }

    struct TriggerCopingPair: Equatable {
        let trigger: Trigger
        let coping: Coping
        let count: Int
    }

    static let empty = InsightsDataset(
        totalCount: 0,
        countsPerDay: [],
        topFeelings: [],
        topBodyRegions: [],
        topTriggerCopingPairs: [],
        moodPoints: []
    )

    /// Build a dataset from logs filtered to `period`.
    static func build(logs: [FeelingLog], period: InsightsPeriod, now: Date = Date()) -> InsightsDataset {
        let filtered: [FeelingLog]
        if let cutoff = period.cutoff(now: now) {
            filtered = logs.filter { $0.createdAt >= cutoff }
        } else {
            filtered = logs
        }

        return InsightsDataset(
            totalCount: filtered.count,
            countsPerDay: countsPerDay(filtered, period: period, now: now),
            topFeelings: topFeelings(filtered),
            topBodyRegions: topBodyRegions(filtered),
            topTriggerCopingPairs: topTriggerCopingPairs(filtered),
            moodPoints: moodPoints(filtered)
        )
    }

    // MARK: - Aggregations

    private static func countsPerDay(_ logs: [FeelingLog], period: InsightsPeriod, now: Date) -> [DayCount] {
        let cal = Calendar.current
        let dayCount = period == .week ? 7 : (period == .month ? 30 : 0)
        guard dayCount > 0 else {
            // .all: group by day, only days with data, sorted ascending
            var buckets: [Date: Int] = [:]
            for log in logs {
                let day = cal.startOfDay(for: log.createdAt)
                buckets[day, default: 0] += 1
            }
            return buckets.sorted { $0.key < $1.key }.map { DayCount(day: $0.key, count: $0.value) }
        }
        // .week or .month: render every day in the window even if zero
        var dayBuckets: [Date: Int] = [:]
        for log in logs {
            let day = cal.startOfDay(for: log.createdAt)
            dayBuckets[day, default: 0] += 1
        }
        var result: [DayCount] = []
        let today = cal.startOfDay(for: now)
        for offset in (0..<dayCount).reversed() {
            if let day = cal.date(byAdding: .day, value: -offset, to: today) {
                result.append(DayCount(day: day, count: dayBuckets[day] ?? 0))
            }
        }
        return result
    }

    private static func topFeelings(_ logs: [FeelingLog]) -> [FeelingCount] {
        var counts: [String: Int] = [:]
        for log in logs where !log.secondaryName.isEmpty {
            counts[log.secondaryName, default: 0] += 1
        }
        return counts
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key  // tie-break alphabetical for determinism
            }
            .prefix(5)
            .map { FeelingCount(name: $0.key, count: $0.value) }
    }

    private static func topBodyRegions(_ logs: [FeelingLog]) -> [BodyRegionCount] {
        var counts: [BodyRegion: Int] = [:]
        for log in logs {
            for region in log.bodyRegions {
                counts[region, default: 0] += 1
            }
        }
        return counts
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key.rawValue < $1.key.rawValue
            }
            .prefix(5)
            .map { BodyRegionCount(region: $0.key, count: $0.value) }
    }

    private static func topTriggerCopingPairs(_ logs: [FeelingLog]) -> [TriggerCopingPair] {
        struct Key: Hashable { let trigger: Trigger; let coping: Coping }
        var counts: [Key: Int] = [:]
        for log in logs {
            for trigger in log.triggers {
                for coping in log.coping {
                    counts[Key(trigger: trigger, coping: coping), default: 0] += 1
                }
            }
        }
        return counts
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                if $0.key.trigger.rawValue != $1.key.trigger.rawValue {
                    return $0.key.trigger.rawValue < $1.key.trigger.rawValue
                }
                return $0.key.coping.rawValue < $1.key.coping.rawValue
            }
            .prefix(5)
            .map { TriggerCopingPair(trigger: $0.key.trigger, coping: $0.key.coping, count: $0.value) }
    }

    private static func moodPoints(_ logs: [FeelingLog]) -> [MoodPoint] {
        logs.compactMap { log in
            guard let e = log.moodEnergy, let v = log.moodValence else { return nil }
            return MoodPoint(energy: e, valence: v, date: log.createdAt)
        }
    }
}
