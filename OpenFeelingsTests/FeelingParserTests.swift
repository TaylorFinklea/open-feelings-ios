// OpenFeelingsTests/FeelingParserTests.swift
import XCTest
@testable import OpenFeelings

final class FeelingParserTests: XCTestCase {
    private let parser = KeywordFeelingParser()

    private func parse(_ s: String) async -> ParsedFeeling { await parser.parse(s) }

    func testExactSecondaryNameIsHigh() async {
        let r = await parse("I feel anxious about the demo")
        XCTAssertEqual(r.core?.name, "Fearful")
        XCTAssertEqual(r.secondary?.name, "Anxious")
        XCTAssertEqual(r.confidence, .high)
    }

    func testSpecificNameResolvesDeepest() async {
        let r = await parse("pretty nervous right now")
        XCTAssertEqual(r.specific?.name, "Nervous")
        XCTAssertEqual(r.confidence, .high)
    }

    func testStrongSynonymIsHigh() async {
        let r = await parse("I'm so mad")
        XCTAssertEqual(r.core?.name, "Angry")
        XCTAssertEqual(r.confidence, .high)
    }

    func testWeakSynonymIsLow() async {
        let r = await parse("feeling kind of off today")
        XCTAssertEqual(r.core?.name, "Sad")
        XCTAssertEqual(r.confidence, .low)
    }

    func testIntensitySlashForm() async {
        let r = await parse("anxious 4/5")
        XCTAssertEqual(r.intensity, 4)
    }

    func testIntensityWordLadder() async {
        let r = await parse("really sad")
        XCTAssertEqual(r.intensity, 4)
    }

    func testNoIntensityStatedIsNil() async {
        let r = await parse("a bit lonely")
        XCTAssertNil(r.intensity)
    }

    func testGarbageIsNoneButKeepsNote() async {
        let r = await parse("asdf qwer")
        XCTAssertNil(r.core)
        XCTAssertEqual(r.confidence, .none)
        XCTAssertEqual(r.rawUtterance, "asdf qwer")
        XCTAssertFalse(r.note.isEmpty)
    }

    func testNoteStripsLeadingIFeel() async {
        let r = await parse("I feel hopeful about next week")
        XCTAssertFalse(r.note.lowercased().hasPrefix("i feel"))
        XCTAssertEqual(r.core?.name, "Happy")
    }

    func testProviderReturnsKeywordParserInPhase1() {
        XCTAssertTrue(FeelingParserProvider.current() is KeywordFeelingParser)
    }
}
