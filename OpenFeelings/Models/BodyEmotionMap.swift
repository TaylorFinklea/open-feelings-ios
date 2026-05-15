import Foundation

/// Curated mapping from body regions to the emotion cores commonly felt there.
/// Source heuristics: mainstream somatic-emotion literature (Damasio, body
/// maps). Marked as starting heuristics — clinical review pass is on the
/// roadmap before general release.
enum BodyEmotionMap {
    /// Curated defaults table. Returns the EmotionCore IDs for the given region.
    static func defaultCores(for region: BodyRegion) -> [String] {
        switch region {
        case .head:      ["fearful", "disgusted", "angry"]
        case .throat:    ["sad", "fearful"]
        case .chest:     ["angry", "happy", "fearful"]
        case .stomach:   ["fearful", "disgusted", "sad"]
        case .gut:       ["fearful", "disgusted"]
        case .shoulders: ["angry", "sad", "fearful"]
        case .back:      ["angry", "sad"]
        case .hands:     ["angry", "fearful", "happy"]
        case .legs:      ["fearful", "angry", "happy"]
        case .wholeBody: ["happy", "sad", "angry", "fearful", "disgusted"]
        case .nowhere:   ["sad"]
        }
    }

    /// Resolves the effective suggested cores for a set of regions.
    ///
    /// Intersection narrowing: starts with each region's mapping, intersects
    /// across all regions. If the intersection is empty (regions disagree),
    /// falls back to the union so the user always sees some highlight.
    ///
    /// Custom regions don't have curated defaults — they contribute only when
    /// learning has crossed the threshold; their dominant secondary's parent
    /// core feeds the suggestion set so a well-trained custom region behaves
    /// like a curated one.
    static func suggestedCores(
        for regions: Set<BodyRegion>,
        customRegionIDs: Set<UUID> = [],
        overrides: UserBodyMap?,
        learned: LearnedBodyMap? = nil
    ) -> Set<String> {
        var perRegionSets: [Set<String>] = []

        for region in regions {
            if let overridden = overrides?.coreIDs(for: region), !overridden.isEmpty {
                perRegionSets.append(Set(overridden))
            } else {
                perRegionSets.append(Set(defaultCores(for: region)))
            }
        }

        for id in customRegionIDs {
            if let learnedCore = learnedCore(forCustomID: id, learned: learned) {
                perRegionSets.append([learnedCore])
            }
            // No defaults / overrides for custom regions in v1 — silently
            // contribute nothing when the user hasn't trained the region yet.
        }

        guard !perRegionSets.isEmpty else { return [] }

        let intersection = perRegionSets.dropFirst().reduce(perRegionSets.first ?? []) { acc, next in
            acc.intersection(next)
        }
        if !intersection.isEmpty {
            return intersection
        }
        return perRegionSets.reduce(Set<String>()) { $0.union($1) }
    }

    private static func learnedCore(forCustomID id: UUID, learned: LearnedBodyMap?) -> String? {
        guard let learned, let secondaryID = learned.dominantSecondary(forCustomID: id) else { return nil }
        return EmotionTaxonomy.cores.first { core in
            core.secondaries.contains { $0.id == secondaryID }
        }?.id
    }
}
