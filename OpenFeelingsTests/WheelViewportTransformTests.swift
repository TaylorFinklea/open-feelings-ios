import CoreGraphics
import XCTest
@testable import OpenFeelings

final class WheelViewportTransformTests: XCTestCase {
    func testInverseTransformMapsRenderedPointBackToWheelPoint() {
        let center = CGPoint(x: 140, y: 140)
        let original = CGPoint(x: 182, y: 97)
        let transform = WheelViewportTransform(
            scale: 2.35,
            rotationDegrees: 47,
            offset: CGSize(width: 28, height: -19)
        )

        let rendered = transform.applied(original, around: center)
        let inverted = transform.inverted(rendered, around: center)

        XCTAssertEqual(Double(inverted.x), Double(original.x), accuracy: 0.0001)
        XCTAssertEqual(Double(inverted.y), Double(original.y), accuracy: 0.0001)
    }

    func testScaleAndOffsetAreClampedToWheelViewport() {
        XCTAssertEqual(WheelViewportTransform.clampedScale(0.25), 1)
        XCTAssertEqual(WheelViewportTransform.clampedScale(8), 4)

        let offset = WheelViewportTransform.clampedOffset(
            CGSize(width: 400, height: -400),
            scale: 2,
            side: 300
        )

        XCTAssertEqual(offset.width, 150)
        XCTAssertEqual(offset.height, -150)
    }
}
