import XCTest
@testable import OpenFeelings

final class ParsedFeelingTests: XCTestCase {
    private var fearful: EmotionCore { EmotionTaxonomy.cores.first { $0.name == "Fearful" }! }
    private var anxious: EmotionSecondary { fearful.secondaries.first { $0.name == "Anxious" }! }

    func testToDraftMapsCoreOnlyWithNote() {
        let parsed = ParsedFeeling(
            core: fearful, secondary: nil, specific: nil,
            intensity: nil, note: "work is a lot",
            confidence: .low, rawUtterance: "work is a lot"
        )
        let draft = parsed.toDraft()
        XCTAssertEqual(draft.selection?.core.name, "Fearful")
        XCTAssertNil(draft.selection?.secondary)
        XCTAssertEqual(draft.note, "work is a lot")
        XCTAssertFalse(draft.includeIntensity)
    }

    func testToDraftThreadsSecondaryAndIntensity() {
        let parsed = ParsedFeeling(
            core: fearful, secondary: anxious, specific: nil,
            intensity: 4, note: "before the demo",
            confidence: .high, rawUtterance: "anxious before the demo 4/5"
        )
        let draft = parsed.toDraft()
        XCTAssertEqual(draft.selection?.secondary?.name, "Anxious")
        XCTAssertTrue(draft.includeIntensity)
        XCTAssertEqual(Int(draft.intensity.rounded()), 4)
    }

    func testToDraftWithNoCoreLeavesSelectionNil() {
        let parsed = ParsedFeeling(
            core: nil, secondary: nil, specific: nil,
            intensity: nil, note: "asdf",
            confidence: .none, rawUtterance: "asdf"
        )
        XCTAssertNil(parsed.toDraft().selection)
    }
}
