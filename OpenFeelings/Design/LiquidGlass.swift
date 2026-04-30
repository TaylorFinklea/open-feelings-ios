// OpenFeelings/Design/LiquidGlass.swift
import SwiftUI

/// Wraps iOS 26 Liquid Glass adoption so call sites change in one place.
enum LiquidGlass {
    /// Background style for sheets / modals. Falls back to surfaceElevated when
    /// Reduce Transparency is enabled.
    @ViewBuilder
    static func sheetBackground(reduceTransparency: Bool) -> some View {
        if reduceTransparency {
            Rectangle().fill(Color.OF.surfaceElevated)
        } else {
            // iOS 26 system Liquid Glass material; .ultraThinMaterial is the
            // closest stable name on iOS 26 for the glass family.
            Rectangle().fill(.ultraThinMaterial)
        }
    }

    /// Subtle scrim used over the wheel when the selection card slides up.
    @ViewBuilder
    static func scrimOverWheel(reduceTransparency: Bool) -> some View {
        if reduceTransparency {
            Rectangle().fill(Color.OF.background.opacity(0.75))
        } else {
            Rectangle().fill(.thinMaterial)
        }
    }
}

extension View {
    /// Apply Liquid Glass background with Reduce Transparency support.
    func ofGlassSheetBackground(_ reduceTransparency: Bool) -> some View {
        background(LiquidGlass.sheetBackground(reduceTransparency: reduceTransparency))
    }
}
