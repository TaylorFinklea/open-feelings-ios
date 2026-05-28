import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class CustomValuesManagerTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let schema = Schema([CustomValue.self, ValueSort.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func testRenameUpdatesNameTrimmed() throws {
        let context = try makeContext()
        let value = CustomValue(name: "Curioisty")
        context.insert(value)
        try context.save()

        CustomValuesSheet.rename(value, to: "  Curiosity  ", in: context)

        XCTAssertEqual(value.name, "Curiosity")
    }

    func testRenameToEmptyIsNoOp() throws {
        let context = try makeContext()
        let value = CustomValue(name: "Curiosity")
        context.insert(value)
        try context.save()

        CustomValuesSheet.rename(value, to: "   ", in: context)

        XCTAssertEqual(value.name, "Curiosity")
    }

    func testDeleteRemovesValueFromStore() throws {
        let context = try makeContext()
        let value = CustomValue(name: "Curiosity")
        context.insert(value)
        try context.save()
        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomValue>()).count, 1)

        CustomValuesSheet.delete(value, in: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<CustomValue>()).count, 0)
    }

    func testDeletedValueRefResolvesToRemovedValue() throws {
        let context = try makeContext()
        let value = CustomValue(name: "Curiosity")
        context.insert(value)
        let ref = ValueRef.makeCustomRef(value.id)
        let sort = ValueSort(rankedTop: [ref])
        context.insert(sort)
        try context.save()

        CustomValuesSheet.delete(value, in: context)

        let remaining = try context.fetch(FetchDescriptor<CustomValue>())
        XCTAssertEqual(ValueRef.displayName(for: ref, customs: remaining),
                       "(removed value)")
    }
}
