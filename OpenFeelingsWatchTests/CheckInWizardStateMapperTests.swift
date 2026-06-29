// OpenFeelingsWatchTests/CheckInWizardStateMapperTests.swift
import XCTest
@testable import OpenFeelingsWatch

@MainActor
final class CheckInWizardStateMapperTests: XCTestCase {
    private var fearful: EmotionCore { EmotionTaxonomy.cores.first { $0.name == "Fearful" }! }
    private var anxious: EmotionSecondary { fearful.secondaries.first { $0.name == "Anxious" }! }

    func testApplyCoreOnlyWithNote() {
        let state = CheckInWizardState()
        state.apply(ParsedFeeling(core: fearful, secondary: nil, specific: nil,
                                  intensity: nil, note: "work is a lot",
                                  confidence: .low, rawUtterance: "work is a lot"))
        XCTAssertEqual(state.core?.name, "Fearful")
        XCTAssertNil(state.secondary)
        XCTAssertEqual(state.note, "work is a lot")
        XCTAssertEqual(state.intensity, 3)   // nil parsed intensity → watch neutral default
    }

    func testApplyThreadsSecondaryAndIntensity() {
        let state = CheckInWizardState()
        state.apply(ParsedFeeling(core: fearful, secondary: anxious, specific: nil,
                                  intensity: 4, note: "before the demo",
                                  confidence: .high, rawUtterance: "anxious 4/5"))
        XCTAssertEqual(state.secondary?.name, "Anxious")
        XCTAssertEqual(state.intensity, 4)
    }
}
