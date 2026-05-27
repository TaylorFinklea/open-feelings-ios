import XCTest
@testable import OpenFeelings

@MainActor
final class SortDeltaTests: XCTestCase {

    // MARK: - empty prior

    func testEmptyPriorTreatsAllCurrentAsAdded() {
        let delta = SortDelta.compute(prior: nil, current: ["a", "b", "c"])
        XCTAssertEqual(delta.added, ["a", "b", "c"])
        XCTAssertEqual(delta.removed, [])
        XCTAssertEqual(delta.moved, [])
    }

    func testEmptyArrayPriorAlsoTreatsAllCurrentAsAdded() {
        let delta = SortDelta.compute(prior: [], current: ["a", "b"])
        XCTAssertEqual(delta.added, ["a", "b"])
        XCTAssertEqual(delta.removed, [])
        XCTAssertEqual(delta.moved, [])
    }

    // MARK: - no changes

    func testIdenticalPriorAndCurrentReturnsEmptyDelta() {
        let delta = SortDelta.compute(prior: ["a", "b", "c"], current: ["a", "b", "c"])
        XCTAssertEqual(delta.added, [])
        XCTAssertEqual(delta.removed, [])
        XCTAssertEqual(delta.moved, [])
    }

    // MARK: - single change

    func testSingleAdded() {
        let delta = SortDelta.compute(prior: ["a", "b"], current: ["a", "b", "c"])
        XCTAssertEqual(delta.added, ["c"])
        XCTAssertEqual(delta.removed, [])
        XCTAssertEqual(delta.moved, [])
    }

    func testSingleRemoved() {
        let delta = SortDelta.compute(prior: ["a", "b", "c"], current: ["a", "b"])
        XCTAssertEqual(delta.added, [])
        XCTAssertEqual(delta.removed, ["c"])
        XCTAssertEqual(delta.moved, [])
    }

    func testSingleMovedRecordsFromAndToIndices() {
        let delta = SortDelta.compute(prior: ["a", "b", "c"], current: ["a", "c", "b"])
        XCTAssertEqual(delta.added, [])
        XCTAssertEqual(delta.removed, [])
        XCTAssertEqual(delta.moved.count, 2)
        let move0 = delta.moved[0]
        let move1 = delta.moved[1]
        XCTAssertEqual(move0.ref, "c")
        XCTAssertEqual(move0.from, 2)
        XCTAssertEqual(move0.to, 1)
        XCTAssertEqual(move1.ref, "b")
        XCTAssertEqual(move1.from, 1)
        XCTAssertEqual(move1.to, 2)
    }

    // MARK: - mixed

    func testMixedAddRemoveMoveInOneDiff() {
        let delta = SortDelta.compute(
            prior:   ["family", "work",     "honesty",  "health"],
            current: ["family", "curiosity", "honesty", "growth"]
        )
        XCTAssertEqual(delta.added, ["curiosity", "growth"])
        XCTAssertEqual(delta.removed, ["work", "health"])
        XCTAssertEqual(delta.moved, [])
    }

    func testReorderingWithinSameSetProducesOnlyMoved() {
        let delta = SortDelta.compute(
            prior:   ["a", "b", "c", "d"],
            current: ["d", "c", "b", "a"]
        )
        XCTAssertEqual(delta.added, [])
        XCTAssertEqual(delta.removed, [])
        XCTAssertEqual(delta.moved.count, 4)
        XCTAssertEqual(delta.moved.map(\.ref), ["d", "c", "b", "a"])
        XCTAssertEqual(delta.moved.map(\.to), [0, 1, 2, 3])
    }

    // MARK: - size differences

    func testPriorLargerThanCurrent() {
        let delta = SortDelta.compute(prior: ["a", "b", "c"], current: ["a"])
        XCTAssertEqual(delta.added, [])
        XCTAssertEqual(delta.removed, ["b", "c"])
        XCTAssertEqual(delta.moved, [])
    }

    func testCurrentLargerThanPrior() {
        let delta = SortDelta.compute(prior: ["a"], current: ["a", "b", "c"])
        XCTAssertEqual(delta.added, ["b", "c"])
        XCTAssertEqual(delta.removed, [])
        XCTAssertEqual(delta.moved, [])
    }

    // MARK: - custom refs

    func testCustomValueRefsRoundTripThroughDelta() {
        let custom = "custom:F8B6C8B3-1234-4567-89AB-CDEF12345678"
        let delta = SortDelta.compute(prior: ["a"], current: ["a", custom])
        XCTAssertEqual(delta.added, [custom])
        XCTAssertEqual(delta.removed, [])
        XCTAssertEqual(delta.moved, [])
    }

    // MARK: - ordering guarantees

    func testAddedSortedByCurrentIndexAscending() {
        let delta = SortDelta.compute(
            prior:   ["a", "b"],
            current: ["a", "z", "b", "y"]
        )
        XCTAssertEqual(delta.added, ["z", "y"])
    }

    func testRemovedSortedByPriorIndexAscending() {
        let delta = SortDelta.compute(
            prior:   ["a", "x", "b", "y", "c"],
            current: ["a", "b", "c"]
        )
        XCTAssertEqual(delta.removed, ["x", "y"])
    }
}
