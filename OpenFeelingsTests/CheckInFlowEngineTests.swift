import XCTest
@testable import OpenFeelings

final class CheckInFlowEngineTests: XCTestCase {
    func testBodyFirstOnDefaultPromotedSteps() {
        // Default: only `strength` is promoted.
        let steps = CheckInFlowEngine.steps(
            bodyFirst: true,
            promotedSteps: [.strength]
        )
        XCTAssertEqual(steps, [.body, .feeling, .strength, .reflect])
    }

    func testBodyFirstOffDefaultPromotedSteps() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: false,
            promotedSteps: [.strength]
        )
        XCTAssertEqual(steps, [.feeling, .strength, .reflect])
    }

    func testEmptyPromotedSteps() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: true,
            promotedSteps: []
        )
        XCTAssertEqual(steps, [.body, .feeling, .reflect])
    }

    func testAllOptionalStepsPromoted() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: true,
            promotedSteps: [.sensations, .strength, .context, .triggers, .coping, .mood]
        )
        // Body → Sensations → Feeling → Context → Triggers → Coping → Strength → Mood → Reflect
        // Sensations land between Body and Feeling; the rest land between Feeling and Reflect.
        XCTAssertEqual(steps, [.body, .sensations, .feeling, .context, .triggers, .coping, .strength, .mood, .reflect])
    }

    func testReflectIsAlwaysLast() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: true,
            promotedSteps: [.context, .triggers, .coping, .mood]
        )
        XCTAssertEqual(steps.last, .reflect)
    }

    func testFeelingIsAlwaysPresent() {
        let steps = CheckInFlowEngine.steps(
            bodyFirst: false,
            promotedSteps: []
        )
        XCTAssertTrue(steps.contains(.feeling))
    }
}
