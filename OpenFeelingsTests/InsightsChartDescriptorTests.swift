import Accessibility
import XCTest
@testable import OpenFeelings

final class InsightsChartDescriptorTests: XCTestCase {
    func testBarCategoricalDescriptorUsesTitle() {
        let descriptor = makeDescriptor()

        XCTAssertEqual(descriptor.title, "Top feelings")
    }

    func testBarCategoricalDescriptorCreatesOneSeries() {
        let descriptor = makeDescriptor()

        XCTAssertEqual(descriptor.series.count, 1)
        XCTAssertEqual(descriptor.series.first?.name, "Top feelings")
        XCTAssertEqual(descriptor.series.first?.isContinuous, false)
    }

    func testBarCategoricalDescriptorDataPointCountMatchesItems() {
        let descriptor = makeDescriptor()

        XCTAssertEqual(descriptor.series.first?.dataPoints.count, 3)
    }

    func testBarCategoricalDescriptorPreservesCategoryOrderInDataPoints() {
        let descriptor = makeDescriptor()

        let labels = descriptor.series.first?.dataPoints.map(\.label)
        XCTAssertEqual(labels, ["Hopeful", "Lonely", "Calm"])
    }

    func testBarCategoricalDescriptorHandlesEmptyItems() {
        let descriptor = InsightsChartDescriptor.barCategorical(title: "By core", items: [])

        XCTAssertEqual(descriptor.title, "By core")
        XCTAssertEqual(descriptor.series.first?.dataPoints.count, 1)
        XCTAssertEqual(descriptor.series.first?.dataPoints.first?.label, "No data")
    }

    func testBarCategoricalDescriptorXAxisIsCategoricalAndPreservesOrder() throws {
        let descriptor = makeDescriptor()

        let axis = try XCTUnwrap(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        XCTAssertEqual(axis.title, "Top feelings")
        XCTAssertEqual(axis.categoryOrder, ["Hopeful", "Lonely", "Calm"])
    }

    func testBarCategoricalDescriptorYAxisCountsCheckIns() throws {
        let descriptor = makeDescriptor()

        let axis = try XCTUnwrap(descriptor.yAxis)
        XCTAssertEqual(axis.title, "Check-ins")
        XCTAssertEqual(axis.range.lowerBound, 0.0)
        XCTAssertEqual(axis.range.upperBound, 4.0)
        XCTAssertEqual(axis.valueDescriptionProvider(1), "1 check-in")
        XCTAssertEqual(axis.valueDescriptionProvider(4), "4 check-ins")
    }

    private func makeDescriptor() -> AXChartDescriptor {
        InsightsChartDescriptor.barCategorical(
            title: "Top feelings",
            items: [
                (category: "Hopeful", count: 4),
                (category: "Lonely", count: 2),
                (category: "Calm", count: 1),
            ]
        )
    }
}
