import Foundation

/// Maps mood-scale Double values (range -1...1) to human-readable bands for
/// log-card summaries. Bands use thirds: <-0.33 / -0.33...0.33 / >0.33.
enum MoodScale {
    /// Energy axis: -1 (calm) ↔ +1 (activated).
    static func energyBand(_ value: Double) -> String {
        switch value {
        case ..<(-0.33):     "calm"
        case (-0.33)...0.33: "balanced"
        default:             "activated"
        }
    }

    /// Valence axis: -1 (unpleasant) ↔ +1 (pleasant).
    static func valenceBand(_ value: Double) -> String {
        switch value {
        case ..<(-0.33):     "unpleasant"
        case (-0.33)...0.33: "neutral"
        default:             "pleasant"
        }
    }
}
