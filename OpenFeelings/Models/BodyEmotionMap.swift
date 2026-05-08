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
}
