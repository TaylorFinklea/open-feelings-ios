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
            ? Color(hex: darkHex)
            : Color(hex: lightHex)
    }

    /// For consumers that need a literal `Color` rather than a `ShapeStyle`.
    func color(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(hex: darkHex) : Color(hex: lightHex)
    }
}

extension Color {
    enum OF {
        static let background      = OFColor(lightHex: "FAF6F0", darkHex: "1B1A18")
        static let surface         = OFColor(lightHex: "FFFFFF", darkHex: "2A2724")
        static let surfaceElevated = OFColor(lightHex: "FCF9F4", darkHex: "34302C")
        static let text            = OFColor(lightHex: "2B2520", darkHex: "F0EAE0")
        static let textMuted       = OFColor(lightHex: "6B6259", darkHex: "A89E92")
        static let textOnAccent    = OFColor(lightHex: "FFFFFF", darkHex: "FFFFFF")
        static let divider         = OFColor(lightHex: "E8DFD3", darkHex: "3F3A35")
        static let accent          = OFColor(lightHex: "C97A4F", darkHex: "D8916A")
        static let accentSoft      = OFColor(lightHex: "EFD5C2", darkHex: "5C3F2E")
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
