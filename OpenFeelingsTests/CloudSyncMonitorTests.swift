import XCTest
import CoreData
@testable import OpenFeelings

@MainActor
final class CloudSyncMonitorTests: XCTestCase {

    private struct SampleError: LocalizedError {
        let errorDescription: String?
    }

    // MARK: - apply(...) phase transitions

    func testInProgressImportEventSetsPhaseToImporting() {
        let monitor = CloudSyncMonitor()
        monitor.apply(eventType: .import, endDate: nil, error: nil)
        XCTAssertEqual(monitor.state.phase, .importing)
        XCTAssertNil(monitor.state.lastError)
        XCTAssertNil(monitor.state.lastSuccessAt)
    }

    func testInProgressExportEventSetsPhaseToExporting() {
        let monitor = CloudSyncMonitor()
        monitor.apply(eventType: .export, endDate: nil, error: nil)
        XCTAssertEqual(monitor.state.phase, .exporting)
    }

    func testInProgressSetupEventTreatedAsExporting() {
        // .setup is rare and short — folding it into the "exporting" phase
        // keeps the public surface to two motion states, which is enough for
        // the Settings row.
        let monitor = CloudSyncMonitor()
        monitor.apply(eventType: .setup, endDate: nil, error: nil)
        XCTAssertEqual(monitor.state.phase, .exporting)
    }

    func testCompletedSuccessfulEventStampsLastSuccess() {
        let monitor = CloudSyncMonitor()
        let endDate = Date(timeIntervalSince1970: 1_700_000_000)
        monitor.apply(eventType: .export, endDate: endDate, error: nil)
        XCTAssertEqual(monitor.state.phase, .idle)
        XCTAssertNil(monitor.state.lastError)
        XCTAssertEqual(monitor.state.lastSuccessAt, endDate)
    }

    func testCompletedFailedEventStoresErrorAndLeavesSuccessAlone() {
        let monitor = CloudSyncMonitor()
        let previousSuccess = Date(timeIntervalSince1970: 1_600_000_000)
        monitor.apply(eventType: .export, endDate: previousSuccess, error: nil)
        XCTAssertEqual(monitor.state.lastSuccessAt, previousSuccess)

        monitor.apply(eventType: .export,
                      endDate: Date(timeIntervalSince1970: 1_700_000_000),
                      error: SampleError(errorDescription: "Permission denied"))
        XCTAssertEqual(monitor.state.lastError, "Permission denied")
        XCTAssertEqual(monitor.state.lastSuccessAt, previousSuccess,
                       "A later failure must not erase the previous success timestamp")
    }

    func testSuccessAfterErrorClearsTheError() {
        let monitor = CloudSyncMonitor()
        monitor.apply(eventType: .import,
                      endDate: Date(timeIntervalSince1970: 1_600_000_000),
                      error: SampleError(errorDescription: "Offline"))
        XCTAssertEqual(monitor.state.lastError, "Offline")

        monitor.apply(eventType: .import,
                      endDate: Date(timeIntervalSince1970: 1_700_000_000),
                      error: nil)
        XCTAssertNil(monitor.state.lastError, "A later success must clear the error")
    }

    // MARK: - statusLine

    func testStatusLineUnknownByDefault() {
        let state = CloudSyncState()
        XCTAssertEqual(state.statusLine, "Waiting for sync")
    }

    func testStatusLineErrorTakesPrecedence() {
        var state = CloudSyncState()
        state.lastSuccessAt = Date()
        state.lastError = "Network unreachable"
        state.phase = .idle
        XCTAssertEqual(state.statusLine, "Sync error: Network unreachable")
    }

    func testStatusLineFallsBackToInFlightPhase() {
        var state = CloudSyncState()
        state.phase = .importing
        XCTAssertEqual(state.statusLine, "Pulling latest…")

        state.phase = .exporting
        XCTAssertEqual(state.statusLine, "Sending latest…")
    }

    func testIsFailingReflectsErrorPresence() {
        var state = CloudSyncState()
        XCTAssertFalse(state.isFailing)
        state.lastError = "x"
        XCTAssertTrue(state.isFailing)
        state.lastError = nil
        XCTAssertFalse(state.isFailing)
    }
}
