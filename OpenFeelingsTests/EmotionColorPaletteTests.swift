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
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "happy")?.lightHex,     "D9A43A")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "sad")?.lightHex,       "6F8FA8")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "angry")?.lightHex,     "C46A55")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "fearful")?.lightHex,   "A07FB1")
        XCTAssertEqual(EmotionColorPalette.accent(forCoreID: "disgusted")?.lightHex, "7AA88A")
    }

    func testUnknownCoreReturnsNil() {
        XCTAssertNil(EmotionColorPalette.accent(forCoreID: "totally-not-a-core"))
    }

    func testSecondaryAndSpecificDeriveLighter() {
        // Secondary should be lighter than core; specific lighter than secondary.
        let coreL = EmotionColorPalette.brightness(hex: "D9A43A")
        let secL  = EmotionColorPalette.brightness(
            hex: EmotionColorPalette.lightenHex("D9A43A", towardWhite: 0.45)
        )
        let specL = EmotionColorPalette.brightness(
            hex: EmotionColorPalette.lightenHex("D9A43A", towardWhite: 0.78)
        )
        XCTAssertLessThan(coreL, secL)
        XCTAssertLessThan(secL, specL)
    }
}
