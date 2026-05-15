import Foundation

/// Aggregated counts of secondary-emotion picks per body region, computed on
/// demand from `[FeelingLog]`. Not persisted — recomputed at the start of a
/// check-in session and cached for that session's lifetime.
///
/// Tracks built-in `BodyRegion` and user-defined `CustomBodyRegion` in
/// parallel maps so the same threshold logic applies to both without
/// callers having to know which kind they're asking about.
struct LearnedBodyMap: Sendable {
    /// `[region: [secondary: count]]`
    let counts: [BodyRegion: [String: Int]]
    /// `[region: total log count where this region was picked]`
    let totals: [BodyRegion: Int]
    /// `[customRegionID: [secondary: count]]`
    let customCounts: [UUID: [String: Int]]
    /// `[customRegionID: total log count where this custom region was picked]`
    let customTotals: [UUID: Int]

    /// Threshold: ≥60% of region-tagged logs share this secondary AND
    /// ≥5 region-tagged samples. Returns nil when below either threshold.
    func dominantSecondary(for region: BodyRegion) -> String? {
        guard let total = totals[region], total >= 5 else { return nil }
        guard let perSecondary = counts[region] else { return nil }
        return dominantSecondary(in: perSecondary, total: total)
    }

    /// Same ≥5 / ≥60% threshold as built-in regions — per user direction the
    /// learning algorithm doesn't get more aggressive for custom regions.
    func dominantSecondary(forCustomID id: UUID) -> String? {
        guard let total = customTotals[id], total >= 5 else { return nil }
        guard let perSecondary = customCounts[id] else { return nil }
        return dominantSecondary(in: perSecondary, total: total)
    }

    private func dominantSecondary(in counts: [String: Int], total: Int) -> String? {
        for (secondary, count) in counts {
            let ratio = Double(count) / Double(total)
            if ratio >= 0.6 {
                return secondary
            }
        }
        return nil
    }

    static func compute(from logs: [FeelingLog]) -> LearnedBodyMap {
        var counts: [BodyRegion: [String: Int]] = [:]
        var totals: [BodyRegion: Int] = [:]
        var customCounts: [UUID: [String: Int]] = [:]
        var customTotals: [UUID: Int] = [:]

        for log in logs {
            let regions = log.bodyRegions
            let customIDs = log.customBodyRegionIDs
            let secondaryID = log.secondaryID
            guard !secondaryID.isEmpty else { continue }

            for region in regions {
                totals[region, default: 0] += 1
                var perSecondary = counts[region] ?? [:]
                perSecondary[secondaryID, default: 0] += 1
                counts[region] = perSecondary
            }

            for id in customIDs {
                customTotals[id, default: 0] += 1
                var perSecondary = customCounts[id] ?? [:]
                perSecondary[secondaryID, default: 0] += 1
                customCounts[id] = perSecondary
            }
        }

        return LearnedBodyMap(
            counts: counts,
            totals: totals,
            customCounts: customCounts,
            customTotals: customTotals
        )
    }
}
