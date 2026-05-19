import XCTest
import SwiftData
@testable import OpenFeelings

@MainActor
final class ThoughtRecordTests: XCTestCase {

    // MARK: - Defaults

    func testFreshRecordHasSensibleDefaults() {
        let record = ThoughtRecord()
        XCTAssertEqual(record.situation, "")
        XCTAssertEqual(record.automaticThought, "")
        XCTAssertNil(record.intensityBefore)
        XCTAssertEqual(record.patternsRaw, "")
        XCTAssertEqual(record.balancedThought, "")
        XCTAssertNil(record.intensityAfter)
        XCTAssertNil(record.linkedLogID)
    }

    // MARK: - isSaveable

    func testIsSaveableTrueWhenAllRequiredFieldsPresent() {
        let r = ThoughtRecord(automaticThought: "x",
                              intensityBefore: 4,
                              balancedThought: "y",
                              intensityAfter: 2)
        XCTAssertTrue(r.isSaveable)
    }

    func testIsSaveableFalseWhenAutomaticThoughtEmpty() {
        let r = ThoughtRecord(automaticThought: "",
                              intensityBefore: 4,
                              balancedThought: "y",
                              intensityAfter: 2)
        XCTAssertFalse(r.isSaveable)
    }

    func testIsSaveableFalseWhenAutomaticThoughtIsWhitespace() {
        let r = ThoughtRecord(automaticThought: "   \n  ",
                              intensityBefore: 4,
                              balancedThought: "y",
                              intensityAfter: 2)
        XCTAssertFalse(r.isSaveable)
    }

    func testIsSaveableFalseWhenBalancedThoughtEmpty() {
        let r = ThoughtRecord(automaticThought: "x",
                              intensityBefore: 4,
                              balancedThought: "",
                              intensityAfter: 2)
        XCTAssertFalse(r.isSaveable)
    }

    func testIsSaveableFalseWhenIntensityBeforeMissing() {
        let r = ThoughtRecord(automaticThought: "x",
                              intensityBefore: nil,
                              balancedThought: "y",
                              intensityAfter: 2)
        XCTAssertFalse(r.isSaveable)
    }

    func testIsSaveableFalseWhenIntensityAfterMissing() {
        let r = ThoughtRecord(automaticThought: "x",
                              intensityBefore: 4,
                              balancedThought: "y",
                              intensityAfter: nil)
        XCTAssertFalse(r.isSaveable)
    }

    // MARK: - intensityDelta

    func testIntensityDeltaNilWhenEitherIntensityMissing() {
        let onlyBefore = ThoughtRecord(intensityBefore: 4, intensityAfter: nil)
        let onlyAfter = ThoughtRecord(intensityBefore: nil, intensityAfter: 2)
        XCTAssertNil(onlyBefore.intensityDelta)
        XCTAssertNil(onlyAfter.intensityDelta)
    }

    func testIntensityDeltaIsPositiveWhenReframeReducedIntensity() {
        let r = ThoughtRecord(intensityBefore: 4, intensityAfter: 2)
        XCTAssertEqual(r.intensityDelta, 2)
    }

    func testIntensityDeltaIsZeroWhenIntensityUnchanged() {
        let r = ThoughtRecord(intensityBefore: 3, intensityAfter: 3)
        XCTAssertEqual(r.intensityDelta, 0)
    }

    func testIntensityDeltaIsNegativeWhenReframeMadeWorse() {
        let r = ThoughtRecord(intensityBefore: 2, intensityAfter: 4)
        XCTAssertEqual(r.intensityDelta, -2)
    }

    // MARK: - patterns accessor

    func testPatternsAccessorEncodesAndDecodesViaRawStorage() {
        let r = ThoughtRecord()
        r.patterns = [.blackAndWhite, .mindReading, .alwaysNever]
        XCTAssertEqual(r.patternsRaw, "blackAndWhite,mindReading,alwaysNever")
        XCTAssertEqual(r.patterns, [.blackAndWhite, .mindReading, .alwaysNever])
    }

    // MARK: - Schema registration

    func testModelContainerAcceptsThoughtRecord() throws {
        let schema = Schema([
            FeelingLog.self, Intention.self, UserBodyMap.self, CustomBodyRegion.self,
            CustomValue.self, ValueSort.self, CommittedAction.self, ThoughtRecord.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        let record = ThoughtRecord(automaticThought: "x",
                                   intensityBefore: 3,
                                   balancedThought: "y",
                                   intensityAfter: 1)
        context.insert(record)
        try context.save()
        let rows = try context.fetch(FetchDescriptor<ThoughtRecord>())
        XCTAssertEqual(rows.count, 1)
    }
}
