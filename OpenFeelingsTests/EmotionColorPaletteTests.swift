import XCTest
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
}
