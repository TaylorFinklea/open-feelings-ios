import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class CustomBodyRegionTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([CustomBodyRegion.self, FeelingLog.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testRenameUpdatesNameTrimmed() throws {
        let context = try makeContext()
        let region = CustomBodyRegion(name: "Jaww")
        context.insert(region)
        try context.save()

        BodyMapSettingsView.rename(region, to: "  Jaw  ", in: context)

        XCTAssertEqual(region.name, "Jaw")
    }

    func testRenameToEmptyIsNoOp() throws {
        let context = try makeContext()
        let region = CustomBodyRegion(name: "Jaw")
        context.insert(region)
        try context.save()

        BodyMapSettingsView.rename(region, to: "   ", in: context)

        XCTAssertEqual(region.name, "Jaw")
    }

    func testDeleteRemovesRegionFromStore() throws {
        let context = try makeContext()
        let region = CustomBodyRegion(name: "Jaw")
        context.insert(region)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomBodyRegion>()).count, 1)

        BodyMapSettingsView.delete(region, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomBodyRegion>()).count, 0)
    }

    func testDeleteDoesNotCascadeToLogs() throws {
        let context = try makeContext()
        let region = CustomBodyRegion(name: "Jaw")
        context.insert(region)
        let core = EmotionTaxonomy.cores.first { $0.id == "happy" }!
        let log = FeelingLog(
            selection: EmotionSelection(core: core, secondary: nil, specific: nil),
            intensity: 3,
            note: ""
        )
        log.customBodyRegionIDs = [region.id]
        context.insert(log)
        try context.save()

        BodyMapSettingsView.delete(region, in: context)

        // No cascade: the log keeps its region UUID (benign orphan).
        let fetchedLog = try context.fetch(FetchDescriptor<FeelingLog>()).first
        XCTAssertEqual(fetchedLog?.customBodyRegionIDs, [region.id])
    }
}
