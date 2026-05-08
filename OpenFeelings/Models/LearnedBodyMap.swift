import Foundation

/// Aggregated counts of secondary-emotion picks per body region, computed on
/// demand from `[FeelingLog]`. Not persisted — recomputed at the start of a
/// check-in session and cached for that session's lifetime.
struct LearnedBodyMap: Sendable {
    /// `[region: [secondary: count]]`
    let counts: [BodyRegion: [String: Int]]
    /// `[region: total log count where this region was picked]`
    let totals: [BodyRegion: Int]

    /// Threshold: ≥60% of region-tagged logs share this secondary AND
    /// ≥5 region-tagged samples. Returns nil when below either threshold.
    func dominantSecondary(for region: BodyRegion) -> String? {
        guard let total = totals[region], total >= 5 else { return nil }
        guard let perSecondary = counts[region] else { return nil }

        for (secondary, count) in perSecondary {
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

        for log in logs {
            let regions = log.bodyRegions
            let secondaryID = log.secondaryID
            guard !secondaryID.isEmpty else { continue }
            for region in regions {
                totals[region, default: 0] += 1
                var perSecondary = counts[region] ?? [:]
                perSecondary[secondaryID, default: 0] += 1
                counts[region] = perSecondary
            }
        }

        return LearnedBodyMap(counts: counts, totals: totals)
    }
}
