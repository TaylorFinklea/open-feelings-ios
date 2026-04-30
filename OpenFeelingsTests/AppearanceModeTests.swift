import XCTest
import SwiftUI
@testable import OpenFeelings

final class AppearanceModeTests: XCTestCase {
    func testRawValueRoundTrip() {
        for mode in AppearanceMode.allCases {
            XCTAssertEqual(AppearanceMode(rawValue: mode.rawValue), mode)
        }
    }

    func testColorSchemeMapping() {
        XCTAssertNil(AppearanceMode.system.colorScheme)
        XCTAssertEqual(AppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppearanceMode.dark.colorScheme, .dark)
    }

    func testAllCasesOrder() {
        XCTAssertEqual(AppearanceMode.allCases, [.system, .light, .dark])
    }
}
