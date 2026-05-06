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
    let topFeelings: [FeelingCount]              // top 5 secondary names
    let topBodyRegions: [BodyRegionCount]        // top 5
    let topTriggerCopingPairs: [TriggerCopingPair] // top 5
    let moodPoints: [MoodPoint]
    let byCore: [CoreCount]                      // one entry per core present
    let byDayOfWeek: [DOWCount]                  // 7 entries, locale-respecting
    let intensityTrend: [DayIntensity]           // per-day avg intensity
    let previousPeriodCount: Int                 // count in the preceding window
    let currentStreak: Int                       // consecutive-days streak (unfiltered)

    struct DayCount: Equatable {
        let day: Date
        let count: Int
    }

    struct FeelingCount: Equatable {
        let name: String
        let coreID: String   // parent core, used for color-by-core in charts
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
        let coreID: String   // empty string is valid; Color.OF.core(_) falls back to accent
    }

    struct TriggerCopingPair: Equatable {
        let trigger: Trigger
        let coping: Coping
        let count: Int
    }

    struct CoreCount: Equatable {
        let coreID: String
        let coreName: String
        let colorHex: String
        let count: Int
    }

    struct DOWCount: Equatable {
        let weekday: Int     // 1...7 in Calendar.weekday convention
        let label: String    // localized short symbol ("Mon", "Mar.", etc.)
        let count: Int
    }

    struct DayIntensity: Equatable {
        let day: Date
        let avgIntensity: Double?  // nil when no logs that day or no intensities
        let logCount: Int          // total logs that day, regardless of intensity
    }

    static let empty = InsightsDataset(
        totalCount: 0,
        countsPerDay: [],
        topFeelings: [],
        topBodyRegions: [],
        topTriggerCopingPairs: [],
        moodPoints: [],
        byCore: [],
        byDayOfWeek: [],
        intensityTrend: [],
        previousPeriodCount: 0,
        currentStreak: 0
    )

    /// Build a dataset from logs filtered to `period`. Streak math sees the
    /// full unfiltered list because a streak built outside the window is
    /// still a real streak.
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
            moodPoints: moodPoints(filtered),
            byCore: byCore(filtered),
            byDayOfWeek: byDayOfWeek(filtered),
            intensityTrend: intensityTrend(filtered, period: period, now: now),
            previousPeriodCount: previousPeriodCount(allLogs: logs, period: period, now: now),
            currentStreak: currentStreak(allLogs: logs, now: now)
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
        // Track count and the first observed coreID per secondary name.
        var counts: [String: (count: Int, coreID: String)] = [:]
        for log in logs where !log.secondaryName.isEmpty {
            if var existing = counts[log.secondaryName] {
                existing.count += 1
                counts[log.secondaryName] = existing
            } else {
                counts[log.secondaryName] = (1, log.coreID)
            }
        }
        return counts
            .sorted {
                if $0.value.count != $1.value.count { return $0.value.count > $1.value.count }
                return $0.key < $1.key  // tie-break alphabetical for determinism
            }
            .prefix(5)
            .map { FeelingCount(name: $0.key, coreID: $0.value.coreID, count: $0.value.count) }
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
            return MoodPoint(energy: e, valence: v, date: log.createdAt, coreID: log.coreID)
        }
    }

    private static func byCore(_ logs: [FeelingLog]) -> [CoreCount] {
        var counts: [String: Int] = [:]
        for log in logs where !log.coreID.isEmpty {
            counts[log.coreID, default: 0] += 1
        }
        let cores = EmotionTaxonomy.cores
        return counts.compactMap { (id, count) -> CoreCount? in
            guard let core = cores.first(where: { $0.id == id }) else { return nil }
            return CoreCount(coreID: id, coreName: core.name, colorHex: core.colorHex, count: count)
        }
        .sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.coreName < $1.coreName
        }
    }

    private static func byDayOfWeek(_ logs: [FeelingLog]) -> [DOWCount] {
        let cal = Calendar.current
        let symbols = cal.shortWeekdaySymbols  // ["Sun", "Mon", ...] in en_US
        // Compute counts keyed by Calendar weekday (1...7).
        var counts: [Int: Int] = [:]
        for log in logs {
            let wd = cal.component(.weekday, from: log.createdAt)
            counts[wd, default: 0] += 1
        }
        // Output 7 entries in display order, starting at firstWeekday.
        let first = cal.firstWeekday  // 1 in en_US, 2 in en_GB, etc.
        return (0..<7).map { offset in
            let wd = ((first - 1 + offset) % 7) + 1   // 1...7
            let label = symbols.indices.contains(wd - 1) ? symbols[wd - 1] : "\(wd)"
            return DOWCount(weekday: wd, label: label, count: counts[wd] ?? 0)
        }
    }

    private static func intensityTrend(_ logs: [FeelingLog], period: InsightsPeriod, now: Date) -> [DayIntensity] {
        let cal = Calendar.current
        // Group logs by start-of-day, capturing both total log count and the
        // intensities for averaging.
        var dayLogCount: [Date: Int] = [:]
        var dayIntensities: [Date: [Int]] = [:]
        for log in logs {
            let day = cal.startOfDay(for: log.createdAt)
            dayLogCount[day, default: 0] += 1
            if let value = log.intensity {
                dayIntensities[day, default: []].append(value)
            }
        }

        let dayCount = period == .week ? 7 : (period == .month ? 30 : 0)

        if dayCount > 0 {
            // .week / .month: render every day in the window with zero-fill.
            var result: [DayIntensity] = []
            let today = cal.startOfDay(for: now)
            for offset in (0..<dayCount).reversed() {
                guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
                let intensities = dayIntensities[day] ?? []
                let avg: Double? = intensities.isEmpty
                    ? nil
                    : Double(intensities.reduce(0, +)) / Double(intensities.count)
                result.append(DayIntensity(day: day, avgIntensity: avg, logCount: dayLogCount[day] ?? 0))
            }
            return result
        }

        // .all: only days with data, ascending.
        return dayLogCount
            .sorted { $0.key < $1.key }
            .map { (day, count) in
                let intensities = dayIntensities[day] ?? []
                let avg: Double? = intensities.isEmpty
                    ? nil
                    : Double(intensities.reduce(0, +)) / Double(intensities.count)
                return DayIntensity(day: day, avgIntensity: avg, logCount: count)
            }
    }

    private static func previousPeriodCount(allLogs: [FeelingLog], period: InsightsPeriod, now: Date) -> Int {
        let windowDays: Double
        switch period {
        case .week:  windowDays = 7
        case .month: windowDays = 30
        case .all:
            // Sentinel: no comparison meaningful, return total so delta == 0.
            return allLogs.count
        }
        let upper = now.addingTimeInterval(-windowDays * 86_400)
        let lower = now.addingTimeInterval(-2 * windowDays * 86_400)
        return allLogs.filter { $0.createdAt >= lower && $0.createdAt < upper }.count
    }

    private static func currentStreak(allLogs: [FeelingLog], now: Date) -> Int {
        let cal = Calendar.current
        // Build a set of days that have at least one log.
        var loggedDays = Set<Date>()
        for log in allLogs {
            loggedDays.insert(cal.startOfDay(for: log.createdAt))
        }
        guard !loggedDays.isEmpty else { return 0 }

        let today = cal.startOfDay(for: now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today) ?? today

        // Pick the anchor: today if today has a log, else yesterday if yesterday
        // has a log, else streak is 0 (a streak that ended >1 day ago is over).
        var anchor: Date
        if loggedDays.contains(today) {
            anchor = today
        } else if loggedDays.contains(yesterday) {
            anchor = yesterday
        } else {
            return 0
        }

        // Walk backward from anchor while each prior day has a log.
        var streak = 1
        while let prior = cal.date(byAdding: .day, value: -1, to: anchor),
              loggedDays.contains(prior) {
            streak += 1
            anchor = prior
        }
        return streak
    }
}
