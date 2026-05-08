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
    /// `overrides` will be wired in once `UserBodyMap` exists; for now this
    /// signature accepts an `Any?` placeholder via `nil` callers.
    static func suggestedCores(
        for regions: Set<BodyRegion>,
        overrides: UserBodyMap?
    ) -> Set<String> {
        guard !regions.isEmpty else { return [] }

        let perRegionSets = regions.map { region -> Set<String> in
            Set(defaultCores(for: region))
        }

        // Intersect across all regions.
        let intersection = perRegionSets.dropFirst().reduce(perRegionSets.first ?? []) { acc, next in
            acc.intersection(next)
        }
        if !intersection.isEmpty {
            return intersection
        }
        // Fallback: union when intersection is empty.
        return perRegionSets.reduce(Set<String>()) { $0.union($1) }
    }
}
