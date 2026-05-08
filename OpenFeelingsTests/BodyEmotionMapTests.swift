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

    // MARK: - suggestedCores narrowing

    func testSingleRegionReturnsItsDefaults() {
        let s = BodyEmotionMap.suggestedCores(for: [.chest], overrides: nil)
        XCTAssertEqual(s, Set(["angry", "happy", "fearful"]))
    }

    func testIntersectionNarrowing() {
        // Stomach: {fearful, disgusted, sad}; Legs: {fearful, angry, happy}.
        // Intersection: {fearful}.
        let s = BodyEmotionMap.suggestedCores(for: [.stomach, .legs], overrides: nil)
        XCTAssertEqual(s, Set(["fearful"]))
    }

    func testEmptyIntersectionFallsBackToUnion() {
        // Throat: {sad, fearful}; Disgusted-only region pair would give empty.
        // Use Back ({angry, sad}) + Disgusted-heavy: Gut ({fearful, disgusted}).
        // Intersection: empty → fallback to union.
        let s = BodyEmotionMap.suggestedCores(for: [.back, .gut], overrides: nil)
        XCTAssertEqual(s, Set(["angry", "sad", "fearful", "disgusted"]))
    }

    func testEmptyRegionsReturnsEmptySet() {
        let s = BodyEmotionMap.suggestedCores(for: [], overrides: nil)
        XCTAssertEqual(s, [])
    }

    func testEverywhereDoesNotNarrow() {
        // wholeBody returns all 5 cores so intersection with anything ⊇ all.
        let s = BodyEmotionMap.suggestedCores(for: [.wholeBody], overrides: nil)
        XCTAssertEqual(s, Set(["happy", "sad", "angry", "fearful", "disgusted"]))
    }

    func testNowhereSuggestsSadOnly() {
        // Nowhere alone → just Sad. UI is responsible for "no dimming"
        // styling; the function returns the suggestion set faithfully.
        let s = BodyEmotionMap.suggestedCores(for: [.nowhere], overrides: nil)
        XCTAssertEqual(s, Set(["sad"]))
    }

    // MARK: - Override layer

    func testOverrideReplacesDefaultForOneRegion() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["sad"])
        let s = BodyEmotionMap.suggestedCores(for: [.chest], overrides: map)
        XCTAssertEqual(s, Set(["sad"]))
    }

    func testOverrideAffectsIntersection() {
        // Default chest: {angry, happy, fearful}. Override to {sad}.
        // Combine with legs ({fearful, angry, happy}): intersection is empty,
        // falls back to union of {sad} ∪ {fearful, angry, happy}.
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["sad"])
        let s = BodyEmotionMap.suggestedCores(for: [.chest, .legs], overrides: map)
        XCTAssertEqual(s, Set(["sad", "fearful", "angry", "happy"]))
    }

    func testNonOverriddenRegionUsesDefault() {
        let map = UserBodyMap()
        map.setOverride(for: .hands, coreIDs: ["sad"])
        // Chest is not overridden.
        let s = BodyEmotionMap.suggestedCores(for: [.chest], overrides: map)
        XCTAssertEqual(s, Set(["angry", "happy", "fearful"]))
    }
}
