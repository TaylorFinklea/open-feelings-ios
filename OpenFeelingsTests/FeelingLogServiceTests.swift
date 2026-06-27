// OpenFeelingsTests/FeelingLogServiceTests.swift
import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class FeelingLogServiceTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([FeelingLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private var draft: CheckInDraft {
        var d = CheckInDraft()
        d.selection = EmotionTaxonomy.selection(coreID: "fearful", secondaryID: "anxious", specificID: nil)
        d.note = "  before the demo  "
        d.includeIntensity = true
        d.intensity = 4
        d.customBodyRegionIDs = [UUID()]
        return d
    }

    func testPersistInsertsOneLogWithCaptureSourceAndTrimmedNote() throws {
        let ctx = try makeContext()
        let log = FeelingLogService.persist(draft: draft, captureSource: "siri", into: ctx, healthEnabled: false)
        XCTAssertNotNil(log)
        XCTAssertEqual(log?.captureSource, "siri")
        XCTAssertEqual(log?.note, "before the demo")
        XCTAssertEqual(log?.intensity, 4)
        XCTAssertEqual(log?.healthSyncStatus, .notRequested)
        let all = try ctx.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(all.count, 1)
    }

    func testPersistRoundTripsCustomBodyRegionIDs() throws {
        let ctx = try makeContext()
        let d = draft
        let log = FeelingLogService.persist(draft: d, captureSource: "quickentry", into: ctx, healthEnabled: false)
        XCTAssertEqual(Set(log!.customBodyRegionIDs), d.customBodyRegionIDs)
    }

    func testPersistPendingWhenHealthEnabled() throws {
        let ctx = try makeContext()
        let log = FeelingLogService.persist(draft: draft, captureSource: "phone", into: ctx, healthEnabled: true)
        XCTAssertEqual(log?.healthSyncStatus, .pending)
    }

    func testPersistReturnsNilForIncompleteSelection() throws {
        let ctx = try makeContext()
        let log = FeelingLogService.persist(draft: CheckInDraft(), captureSource: "phone", into: ctx, healthEnabled: false)
        XCTAssertNil(log)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FeelingLog>()).count, 0)
    }
}
