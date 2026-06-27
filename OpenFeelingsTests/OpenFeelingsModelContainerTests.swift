// OpenFeelingsTests/OpenFeelingsModelContainerTests.swift
import SwiftData
import XCTest
@testable import OpenFeelings

@MainActor
final class OpenFeelingsModelContainerTests: XCTestCase {
    func testSharedReturnsSameInstance() {
        let a = OpenFeelingsModelContainer.shared
        let b = OpenFeelingsModelContainer.shared
        XCTAssertTrue(a === b, "Shared container must be a single instance")
    }
}
