import Foundation
import SwiftUI

enum EmotionColorPalette {
    struct ColorPair: Equatable, Sendable, Hashable {
        let lightHex: String
        let darkHex: String
    }

    enum Depth: Sendable { case core, secondary, specific }

    private static let coreAccents: [String: ColorPair] = [
        "happy":     ColorPair(lightHex: "D9A43A", darkHex: "E5BC68"),
        "sad":       ColorPair(lightHex: "6F8FA8", darkHex: "93AABF"),
        "angry":     ColorPair(lightHex: "C46A55", darkHex: "D58B79"),
        "fearful":   ColorPair(lightHex: "A07FB1", darkHex: "B89CC4"),
        "disgusted": ColorPair(lightHex: "7AA88A", darkHex: "99BBA5"),
    ]

    /// Returns the warm-calm rebalanced light/dark accent pair for a core, or nil if unknown.
    static func accent(forCoreID id: String) -> ColorPair? {
        coreAccents[id]
    }

    /// Resolved Color for a taxonomy node at a given depth, in a given color scheme.
    /// Secondary tints derive from the core via `lightenHex(_, 0.45)`; specific via `0.78`.
    /// Unknown cores fall back to a muted neutral.
    static func color(coreID: String, depth: Depth, scheme: ColorScheme) -> Color {
        colorFromHex(hexString(coreID: coreID, depth: depth, scheme: scheme))
    }

    /// Returns the resolved hex string (no `#` prefix) for a taxonomy node at a
    /// given depth + color scheme. Mirrors `color(coreID:depth:scheme:)` but
    /// produces the hex so callers can feed it into `Color.readableText(onHex:)`.
    static func hexString(coreID: String, depth: Depth, scheme: ColorScheme) -> String {
        guard let pair = coreAccents[coreID] else {
            return scheme == .dark ? "A89E92" : "6B6259"
        }
        let base = scheme == .dark ? pair.darkHex : pair.lightHex
        switch depth {
        case .core:      return base
        case .secondary: return lightenHex(base, towardWhite: 0.45)
        case .specific:  return lightenHex(base, towardWhite: 0.78)
        }
    }

    // MARK: - Color math (also exercised directly by tests)

    /// Mixes the input toward pure white by `t` (0...1).
    static func lightenHex(_ hex: String, towardWhite t: CGFloat) -> String {
        let (r, g, b) = rgb(of: hex)
        let nr = r + (1 - r) * t
        let ng = g + (1 - g) * t
        let nb = b + (1 - b) * t
        return String(format: "%02X%02X%02X",
                      Int((nr * 255).rounded()),
                      Int((ng * 255).rounded()),
                      Int((nb * 255).rounded()))
    }

    /// Perceived brightness via standard luma weights.
    static func brightness(hex: String) -> CGFloat {
        let (r, g, b) = rgb(of: hex)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    // MARK: - Local helpers (kept private so this file is self-contained for SourceKit)

    private static func rgb(of hex: String) -> (CGFloat, CGFloat, CGFloat) {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        return (
            CGFloat((v & 0xFF0000) >> 16) / 255,
            CGFloat((v & 0x00FF00) >> 8)  / 255,
            CGFloat(v & 0x0000FF)         / 255
        )
    }

    private static func colorFromHex(_ hex: String) -> Color {
        let (r, g, b) = rgb(of: hex)
        return Color(red: Double(r), green: Double(g), blue: Double(b))
    }
}
