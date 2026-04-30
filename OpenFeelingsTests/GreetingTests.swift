import XCTest
@testable import OpenFeelings

final class GreetingTests: XCTestCase {
    private let cal = Calendar(identifier: .gregorian)

    private func date(hour: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 28; c.hour = hour
        return cal.date(from: c)!
    }

    func testMorning() {
        XCTAssertEqual(Greeting.text(for: date(hour: 7), name: "Taylor", calendar: cal),
                       "Good morning, Taylor.")
    }

    func testAfternoon() {
        XCTAssertEqual(Greeting.text(for: date(hour: 13), name: "Taylor", calendar: cal),
                       "Good afternoon, Taylor.")
    }

    func testEvening() {
        XCTAssertEqual(Greeting.text(for: date(hour: 21), name: "Taylor", calendar: cal),
                       "Good evening, Taylor.")
    }

    func testEmptyNameDropsCommaAndName() {
        XCTAssertEqual(Greeting.text(for: date(hour: 9), name: "", calendar: cal),
                       "Good morning.")
    }

    func testWhitespaceNameIsTreatedAsEmpty() {
        XCTAssertEqual(Greeting.text(for: date(hour: 9), name: "   ", calendar: cal),
                       "Good morning.")
    }

    func testBoundaries() {
        XCTAssertEqual(Greeting.text(for: date(hour: 0),  name: "", calendar: cal), "Good evening.")
        XCTAssertEqual(Greeting.text(for: date(hour: 5),  name: "", calendar: cal), "Good morning.")
        XCTAssertEqual(Greeting.text(for: date(hour: 11), name: "", calendar: cal), "Good morning.")
        XCTAssertEqual(Greeting.text(for: date(hour: 12), name: "", calendar: cal), "Good afternoon.")
        XCTAssertEqual(Greeting.text(for: date(hour: 16), name: "", calendar: cal), "Good afternoon.")
        XCTAssertEqual(Greeting.text(for: date(hour: 17), name: "", calendar: cal), "Good evening.")
        XCTAssertEqual(Greeting.text(for: date(hour: 23), name: "", calendar: cal), "Good evening.")
    }
}
