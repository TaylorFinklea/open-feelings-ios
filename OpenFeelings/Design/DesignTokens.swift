// OpenFeelings/Design/DesignTokens.swift
import SwiftUI

// MARK: - Color tokens
//
// `OFColor` is an environment-aware ShapeStyle that resolves to a light or
// dark hex `Color` at draw time. It works directly with any modifier that
// accepts a ShapeStyle: .foregroundStyle, .background, .fill, .tint, .stroke,
// .overlay, etc. For places that need a concrete `Color` (function
// parameters, equality checks), call `.color(for: scheme)` with the
// surrounding view's `@Environment(\.colorScheme)`.

struct OFColor: ShapeStyle, Sendable, Hashable {
    let lightHex: String
    let darkHex: String

    func resolve(in environment: EnvironmentValues) -> Color {
        environment.colorScheme == .dark
            ? Self.color(fromHex: darkHex)
            : Self.color(fromHex: lightHex)
    }

    /// For consumers that need a literal `Color` rather than a `ShapeStyle`.
    func color(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Self.color(fromHex: darkHex)
            : Self.color(fromHex: lightHex)
    }

    /// Self-contained hex parser. Avoids depending on any cross-file
    /// `Color(hex:)` extension so SourceKit can index this file in isolation.
    private static func color(fromHex hex: String) -> Color {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = Double((v & 0xFF0000) >> 16) / 255
        let g = Double((v & 0x00FF00) >> 8)  / 255
        let b = Double(v & 0x0000FF)         / 255
        return Color(red: r, green: g, blue: b)
    }
}

extension Color {
    enum OF {
        static let background      = OFColor(lightHex: "FAF6F0", darkHex: "1B1A18")
        static let surface         = OFColor(lightHex: "FFFFFF", darkHex: "2A2724")
        static let surfaceElevated = OFColor(lightHex: "FCF9F4", darkHex: "34302C")
        static let text            = OFColor(lightHex: "2B2520", darkHex: "F0EAE0")
        static let textMuted       = OFColor(lightHex: "6B6259", darkHex: "A89E92")
        static let textOnAccent    = OFColor(lightHex: "FFFFFF", darkHex: "1B1A18")
        static let divider         = OFColor(lightHex: "E8DFD3", darkHex: "3F3A35")
        static let accent          = OFColor(lightHex: "8E4F2C", darkHex: "D8916A")
        static let accentSoft      = OFColor(lightHex: "EFD5C2", darkHex: "302118")
        /// Cool counterpoint to the warm terracotta accent. Used for calm
        /// "done"/completed affordances (e.g. committed-action checkbox) where a
        /// cool fill reads as settled rather than active. Pair glyphs with
        /// `textOnAccent` (not pure white): white fails WCAG AA on the lighter
        /// dark-mode hex, while `textOnAccent` stays legible in both schemes.
        static let accentCool      = OFColor(lightHex: "4F7280", darkHex: "8FB4C4")
    }
}

// MARK: - Typography tokens

extension Font {
    enum OF {
        static let display       = Font.system(size: 34, weight: .regular, design: .serif)
        static let title         = Font.system(size: 28, weight: .regular, design: .serif)
        static let headline      = Font.system(size: 20, weight: .semibold)
        static let body          = Font.system(size: 17, weight: .regular)
        static let bodyEmphasis  = Font.system(size: 17, weight: .semibold)
        static let caption       = Font.system(size: 13, weight: .regular)
        static let mono          = Font.system(size: 15, weight: .regular, design: .monospaced)

        /// Editorial letter-spacing applied to the serif display/title tokens.
        /// Tracking is a view modifier (not expressible on `Font`), so it lives
        /// in the `.ofDisplay()` / `.ofTitle()` helpers below.
        static let displayTracking: CGFloat = -0.6
        static let titleTracking:   CGFloat = -0.4
    }
}

extension View {
    /// Large serif display heading — `Font.OF.display` with tightened
    /// editorial tracking. Prefer this over `.font(.OF.display)`.
    func ofDisplay() -> some View {
        font(.OF.display).tracking(Font.OF.displayTracking)
    }

    /// Serif section title — `Font.OF.title` with tightened editorial
    /// tracking. Prefer this over `.font(.OF.title)`.
    func ofTitle() -> some View {
        font(.OF.title).tracking(Font.OF.titleTracking)
    }
}

// MARK: - Spacing tokens

extension CGFloat {
    enum OF {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }
}

// MARK: - Radius tokens

extension CGFloat.OF {
    enum Radius {
        static let chip:  CGFloat = 6
        static let card:  CGFloat = 12
        static let sheet: CGFloat = 20
    }
}

// MARK: - Motion tokens

extension Animation {
    enum OF {
        static let quick  = Animation.easeInOut(duration: 0.18)
        static let gentle = Animation.easeInOut(duration: 0.32)
        static let settle = Animation.spring(response: 0.48, dampingFraction: 0.85)
    }

    /// Returns the given animation, or `nil` (instant) when Reduce Motion is on.
    static func ofRespectingReduceMotion(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
