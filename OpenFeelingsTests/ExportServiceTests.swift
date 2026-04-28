import XCTest
@testable import OpenFeelings

final class ExportServiceTests: XCTestCase {
    func testCSVExportEscapesNotes() throws {
        let selection = try XCTUnwrap(EmotionTaxonomy.selection(
            coreID: "calm",
            secondaryID: "content",
            specificID: "satisfied"
        ))
        let log = FeelingLog(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            createdAt: Date(timeIntervalSince1970: 0),
            selection: selection,
            intensity: 4,
            note: "quiet, steady \"enough\""
        )

        let csv = ExportService.csv(logs: [log])

        XCTAssertTrue(csv.contains("id,created_at,core,secondary,specific,intensity,note"))
        XCTAssertTrue(csv.contains("\"quiet, steady \"\"enough\"\"\""))
    }

    func testJSONExportContainsEmotionPath() throws {
        let selection = try XCTUnwrap(EmotionTaxonomy.selection(
            coreID: "fear",
            secondaryID: "anxious",
            specificID: "worried"
        ))
        let log = FeelingLog(selection: selection, intensity: nil, note: "before appointment")

        let data = try ExportService.jsonData(logs: [log])
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))

        XCTAssertTrue(json.contains("\"core\" : \"Fear\""))
        XCTAssertTrue(json.contains("\"secondary\" : \"Anxious\""))
        XCTAssertTrue(json.contains("\"specific\" : \"Worried\""))
    }
}
