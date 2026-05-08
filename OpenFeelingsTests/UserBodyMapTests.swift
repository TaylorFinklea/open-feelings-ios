import XCTest
import SwiftData
@testable import OpenFeelings

final class UserBodyMapTests: XCTestCase {
    func testEmptyMapHasNoOverrides() {
        let map = UserBodyMap()
        XCTAssertNil(map.coreIDs(for: .chest))
    }

    func testWriteAndReadOverride() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["fearful"])
        XCTAssertEqual(map.coreIDs(for: .chest), ["fearful"])
    }

    func testOverwriteOverride() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["fearful"])
        map.setOverride(for: .chest, coreIDs: ["angry", "fearful"])
        XCTAssertEqual(Set(map.coreIDs(for: .chest) ?? []), Set(["angry", "fearful"]))
    }

    func testClearOverride() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["fearful"])
        map.clearOverride(for: .chest)
        XCTAssertNil(map.coreIDs(for: .chest))
    }

    func testResetClearsAll() {
        let map = UserBodyMap()
        map.setOverride(for: .chest, coreIDs: ["fearful"])
        map.setOverride(for: .hands, coreIDs: ["angry"])
        map.resetAll()
        XCTAssertNil(map.coreIDs(for: .chest))
        XCTAssertNil(map.coreIDs(for: .hands))
    }

    func testEntryCodableRoundTrip() throws {
        let entry = UserBodyMapEntry(regionRaw: "chest", coreIDs: ["fearful", "angry"])
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(UserBodyMapEntry.self, from: data)
        XCTAssertEqual(decoded, entry)
    }
}
