// OpenFeelingsTests/LogFeelingIntentTests.swift
import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class LogFeelingIntentTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([FeelingLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testHighConfidenceSavesSiriLog() async throws {
        let ctx = try makeContext()
        let outcome = await LogFeelingIntent.run(phrase: "anxious about the demo 4/5", context: ctx, healthEnabled: false)
        let logs = try ctx.fetch(FetchDescriptor<FeelingLog>())
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs.first?.captureSource, "siri")
        XCTAssertEqual(logs.first?.intensity, 4)
        if case .saved = outcome {} else { XCTFail("expected .saved, got \(outcome)") }
    }

    func testNoneSavesNothingAndStashesPending() async throws {
        let ctx = try makeContext()
        let defaults = UserDefaults(suiteName: "intent-test-\(UUID().uuidString)")!
        let outcome = await LogFeelingIntent.run(phrase: "asdf qwer", context: ctx, healthEnabled: false,
                                                 pending: PendingQuickEntryStore(defaults: defaults))
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<FeelingLog>()).count, 0)
        XCTAssertEqual(PendingQuickEntryStore(defaults: defaults).take(), "asdf qwer")
        if case .handedOff = outcome {} else { XCTFail("expected .handedOff, got \(outcome)") }
    }
}
