// OpenFeelings/Design/DesignTokens.swift
import SwiftUI

// MARK: - Color tokens

extension Color {
    enum OF {
        static let background      = Color(lightHex: "FAF6F0", darkHex: "1B1A18")
        static let surface         = Color(lightHex: "FFFFFF", darkHex: "2A2724")
        static let surfaceElevated = Color(lightHex: "FCF9F4", darkHex: "34302C")
        static let text            = Color(lightHex: "2B2520", darkHex: "F0EAE0")
        static let textMuted       = Color(lightHex: "6B6259", darkHex: "A89E92")
        static let textOnAccent    = Color.white
        static let divider         = Color(lightHex: "E8DFD3", darkHex: "3F3A35")
        static let accent          = Color(lightHex: "C97A4F", darkHex: "D8916A")
        static let accentSoft      = Color(lightHex: "EFD5C2", darkHex: "5C3F2E")
    }

    /// Hex-pair init used by tokens. Resolves per trait collection at draw time
    /// so tokens follow Light/Dark mode automatically.
    init(lightHex: String, darkHex: String) {
        self = Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: darkHex)
                : UIColor(hex: lightHex)
        })
    }
}

private extension UIColor {
    convenience init(hex: String) {
        var h = hex
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = CGFloat((v & 0xFF0000) >> 16) / 255
        let g = CGFloat((v & 0x00FF00) >> 8) / 255
        let b = CGFloat(v & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
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

    /// Returns `.OF.quick` etc. unless Reduce Motion is on, in which case
    /// returns `nil` (callers should pass to `withAnimation(_:)` which treats
    /// `nil` as instant).
    static func ofRespectingReduceMotion(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
