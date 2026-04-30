import XCTest
import SwiftUI
@testable import OpenFeelings

final class EmotionColorPaletteTests: XCTestCase {
    func testEveryCoreHasARedesignedAccent() {
        for core in EmotionTaxonomy.cores {
            let pair = EmotionColorPalette.accent(forCoreID: core.id)
            XCTAssertNotNil(pair, "core \(core.id) missing redesigned accent")
        }
    }

    func testKnownCoresMapToExpectedHexes() {
        // Light hexes nudged for WCAG AA (≥3:1 on white surface) — see contrast audit 2026-04-30.
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "happy")?.lightHex,     "9E741F")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "sad")?.lightHex,       "6F8FA8")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "angry")?.lightHex,     "C46A55")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "fearful")?.lightHex,   "A07FB1")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "disgusted")?.lightHex, "4F785D")
    }

    func testUnknownCoreReturnsNil() {
        XCTAssertNil(EmotionColorPalette.accent(forCoreID: "totally-not-a-core"))
    }

    func testSecondaryAndSpecificDeriveLighter() {
        // Secondary should be lighter than core; specific lighter than secondary.
        // Uses updated happy light hex 9E741F (nudged for WCAG AA 2026-04-30).
        let coreL = EmotionColorPalette.brightness(hex: "9E741F")
        let secL  = EmotionColorPalette.brightness(
            hex: EmotionColorPalette.lightenHex("9E741F", towardWhite: 0.45)
        )
        let specL = EmotionColorPalette.brightness(
            hex: EmotionColorPalette.lightenHex("9E741F", towardWhite: 0.78)
        )
        XCTAssertLessThan(coreL, secL)
        XCTAssertLessThan(secL, specL)
    }

    // MARK: - hexString(coreID:depth:scheme:)

    func testHexStringCoreLightReturnsBaseLightHex() {
        XCTAssertEqual(
            EmotionColorPalette.hexString(coreID: "happy", depth: .core, scheme: .light),
            "9E741F"
        )
    }

    func testHexStringCoreDarkReturnsBaseDarkHex() {
        XCTAssertEqual(
            EmotionColorPalette.hexString(coreID: "happy", depth: .core, scheme: .dark),
            "E5BC68"
        )
    }

    func testHexStringSecondaryLightensCore() {
        let coreHex = EmotionColorPalette.hexString(coreID: "sad", depth: .core, scheme: .light)
        let secHex = EmotionColorPalette.hexString(coreID: "sad", depth: .secondary, scheme: .light)
        XCTAssertEqual(secHex, EmotionColorPalette.lightenHex(coreHex, towardWhite: 0.45))
    }

    func testHexStringSpecificLightensSecondary() {
        let coreHex = EmotionColorPalette.hexString(coreID: "fearful", depth: .core, scheme: .light)
        let specHex = EmotionColorPalette.hexString(coreID: "fearful", depth: .specific, scheme: .light)
        XCTAssertEqual(specHex, EmotionColorPalette.lightenHex(coreHex, towardWhite: 0.78))
    }

    func testHexStringUnknownCoreFallsBackToNeutral() {
        XCTAssertEqual(
            EmotionColorPalette.hexString(coreID: "not-a-core", depth: .core, scheme: .light),
            "6B6259"
        )
        XCTAssertEqual(
            EmotionColorPalette.hexString(coreID: "not-a-core", depth: .core, scheme: .dark),
            "A89E92"
        )
    }

    // MARK: - color(coreID:depth:scheme:)
    //
    // We can't compare SwiftUI Color values directly without rendering, but we can
    // verify the Color produced from a known hex matches the Color produced by the
    // palette for the same coreID + depth + scheme — i.e., color() and hexString()
    // stay in lockstep.

    func testColorMatchesHexStringForEveryCoreAndDepth() {
        for core in EmotionTaxonomy.cores {
            for depth in [EmotionColorPalette.Depth.core, .secondary, .specific] {
                for scheme in [ColorScheme.light, .dark] {
                    let viaColor = EmotionColorPalette.color(coreID: core.id, depth: depth, scheme: scheme)
                    let hex = EmotionColorPalette.hexString(coreID: core.id, depth: depth, scheme: scheme)
                    let expected = colorFromHex(hex)
                    XCTAssertEqual(
                        viaColor.description, expected.description,
                        "color(\(core.id), \(depth), \(scheme)) should match hexString-derived color"
                    )
                }
            }
        }
    }

    func testColorForUnknownCoreUsesNeutralFallback() {
        let lightFallback = EmotionColorPalette.color(coreID: "not-a-core", depth: .core, scheme: .light)
        XCTAssertEqual(lightFallback.description, colorFromHex("6B6259").description)

        let darkFallback = EmotionColorPalette.color(coreID: "not-a-core", depth: .core, scheme: .dark)
        XCTAssertEqual(darkFallback.description, colorFromHex("A89E92").description)
    }

    // MARK: - Helpers

    // MARK: - Calm-night dark-mode derivation

    func testCalmNightDarkSecondaryAndSpecificDarkenTowardBackground() {
        // In dark mode, the derivation darkens toward the dark page background
        // instead of lightening toward white. So secondary brightness should be
        // LESS than core brightness, and specific should be even darker.
        for core in EmotionTaxonomy.cores {
            let coreHex     = EmotionColorPalette.hexString(coreID: core.id, depth: .core,      scheme: .dark)
            let secondHex   = EmotionColorPalette.hexString(coreID: core.id, depth: .secondary, scheme: .dark)
            let specificHex = EmotionColorPalette.hexString(coreID: core.id, depth: .specific,  scheme: .dark)
            let coreL  = EmotionColorPalette.brightness(hex: coreHex)
            let secL   = EmotionColorPalette.brightness(hex: secondHex)
            let specL  = EmotionColorPalette.brightness(hex: specificHex)
            XCTAssertLessThan(secL,  coreL, "core \(core.id) — dark secondary should be darker than core")
            XCTAssertLessThan(specL, secL,  "core \(core.id) — dark specific should be darker than secondary")
        }
    }

    func testLightModeDerivationStillLightensTowardWhite() {
        // Regression guard: light-mode behavior must NOT change. Specific is
        // brighter than secondary, secondary brighter than core (existing rule).
        for core in EmotionTaxonomy.cores {
            let coreHex     = EmotionColorPalette.hexString(coreID: core.id, depth: .core,      scheme: .light)
            let secondHex   = EmotionColorPalette.hexString(coreID: core.id, depth: .secondary, scheme: .light)
            let specificHex = EmotionColorPalette.hexString(coreID: core.id, depth: .specific,  scheme: .light)
            let coreL = EmotionColorPalette.brightness(hex: coreHex)
            let secL  = EmotionColorPalette.brightness(hex: secondHex)
            let specL = EmotionColorPalette.brightness(hex: specificHex)
            XCTAssertLessThan(coreL, secL, "core \(core.id) — light secondary should be lighter than core")
            XCTAssertLessThan(secL, specL, "core \(core.id) — light specific should be lighter than secondary")
        }
    }

    func testDarkenHexFullStrengthReachesTarget() {
        // Sanity check the math helper: t=1.0 returns the target hex exactly.
        XCTAssertEqual(EmotionColorPalette.darkenHex("FF0000", toward: "000000", by: 1.0), "000000")
        XCTAssertEqual(EmotionColorPalette.darkenHex("D9A43A", toward: "1B1A18", by: 1.0), "1B1A18")
        XCTAssertEqual(EmotionColorPalette.darkenHex("D9A43A", toward: "1B1A18", by: 0.0), "D9A43A")
    }

    // MARK: - Helpers

    /// Mirrors EmotionColorPalette's private hex parser so the tests don't depend
    /// on internal access.
    private func colorFromHex(_ hex: String) -> Color {
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
