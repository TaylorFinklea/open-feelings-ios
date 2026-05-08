import XCTest
@testable import OpenFeelings

final class BodyEmotionMapTests: XCTestCase {
    func testHeadDefaults() {
        XCTAssertEqual(Set(BodyEmotionMap.defaultCores(for: .head)),
                       Set(["fearful", "disgusted", "angry"]))
    }

    func testChestDefaults() {
        XCTAssertEqual(Set(BodyEmotionMap.defaultCores(for: .chest)),
                       Set(["angry", "happy", "fearful"]))
    }

    func testWholeBodyDefaults() {
        XCTAssertEqual(Set(BodyEmotionMap.defaultCores(for: .wholeBody)),
                       Set(["happy", "sad", "angry", "fearful", "disgusted"]))
    }

    func testNowhereDefaults() {
        XCTAssertEqual(Set(BodyEmotionMap.defaultCores(for: .nowhere)),
                       Set(["sad"]))
    }

    func testEveryRegionHasNonEmptyDefaults() {
        for region in BodyRegion.allCases {
            XCTAssertFalse(BodyEmotionMap.defaultCores(for: region).isEmpty,
                           "region \(region.rawValue) has empty default cores")
        }
    }
}
