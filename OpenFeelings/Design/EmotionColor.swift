// OpenFeelings/Design/EmotionColor.swift
import SwiftUI

extension Color.OF {
    /// Stable color for an emotion core, looked up by `coreID`. Returns the
    /// core's hex as an `OFColor` so chart call sites use the same
    /// `.foregroundStyle(Color.OF.core(id))` pattern as other design tokens.
    /// Falls back to `Color.OF.accent` when the ID doesn't resolve.
    ///
    /// The five core hexes (Happy F4D03F, Sad 3498DB, Angry EC7063,
    /// Fearful AF7AC5, Disgusted 58D68D) carry enough chroma to read against
    /// both light and dark backgrounds, so the same hex is used for both
    /// schemes. If real-device testing shows muddy contrast in dark mode, add
    /// per-core dark variants here without touching call sites.
    static func core(_ coreID: String) -> OFColor {
        guard let core = EmotionTaxonomy.cores.first(where: { $0.id == coreID }) else {
            return Color.OF.accent
        }
        return OFColor(lightHex: core.colorHex, darkHex: core.colorHex)
    }
}
