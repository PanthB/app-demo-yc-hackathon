import XCTest
@testable import AppDemo

final class DropKindTests: XCTestCase {
    func testADueTimeMakesAReminderWhateverTheSource() {
        XCTAssertEqual(DropKind.derive(type: .note, source: .text, hasDueTime: true), .reminder)
        XCTAssertEqual(DropKind.derive(type: .place, source: .url, hasDueTime: true), .reminder)
    }

    func testWhatTheReaderFoundWinsOverTheSource() {
        XCTAssertEqual(DropKind.derive(type: .song, source: .url, hasDueTime: false), .song)
        XCTAssertEqual(DropKind.derive(type: .event, source: .video, hasDueTime: false), .event)
        XCTAssertEqual(DropKind.derive(type: .place, source: .image, hasDueTime: false), .place)
    }

    func testAnUnreadDropFallsBackToItsSource() {
        XCTAssertEqual(DropKind.derive(type: nil, source: .image, hasDueTime: false), .photo)
        XCTAssertEqual(DropKind.derive(type: nil, source: .video, hasDueTime: false), .video)
        XCTAssertEqual(DropKind.derive(type: nil, source: .audio, hasDueTime: false), .voice)
        XCTAssertEqual(DropKind.derive(type: nil, source: .url, hasDueTime: false), .link)
        XCTAssertEqual(DropKind.derive(type: nil, source: .text, hasDueTime: false), .note)
        XCTAssertEqual(DropKind.derive(type: nil, source: .pdf, hasDueTime: false), .note)
    }

    func testANoteOrMoodKeepsItsMediaKind() {
        XCTAssertEqual(DropKind.derive(type: .note, source: .audio, hasDueTime: false), .voice)
        XCTAssertEqual(DropKind.derive(type: .mood, source: .image, hasDueTime: false), .photo)
        XCTAssertEqual(DropKind.derive(type: .mood, source: .text, hasDueTime: false), .note)
    }

    func testEveryKindHasALowercaseWordAndASymbol() {
        for kind in DropKind.allCases {
            XCTAssertEqual(kind.word, kind.word.lowercased())
            XCTAssertFalse(kind.symbol.isEmpty)
        }
        XCTAssertEqual(Set(DropKind.allCases.map(\.symbol)).count, DropKind.allCases.count)
    }

    func testTheTitleSkipsWordsThePreviewAlreadyShows() {
        XCTAssertEqual(CardWords.title(["Golden Hour", "raw"], hiding: nil), "golden hour")
        XCTAssertEqual(CardWords.title([nil, "  call mom back "], hiding: nil), "call mom back")
        XCTAssertNil(CardWords.title([nil, "soft pink everything"], hiding: "soft pink everything"))
        XCTAssertNil(CardWords.title([nil, "  "], hiding: nil))
    }

    func testTheMetaLineJoinsWhenAndWhereOnce() {
        XCTAssertEqual(CardWords.meta(["sat 8pm", "The Chapel"], hiding: []), "sat 8pm · the chapel")
        XCTAssertEqual(CardWords.meta([nil, "kacey musgraves"], hiding: [nil]), "kacey musgraves")
        XCTAssertNil(CardWords.meta(["sometime in march", nil], hiding: ["sometime in march"]))
        XCTAssertEqual(CardWords.meta(["instagram.com", "instagram.com"], hiding: []), "instagram.com")
        XCTAssertEqual(CardWords.meta(["12:45pm", "Stonemill Matcha"], hiding: [nil, "stonemill matcha"]), "12:45pm")
        XCTAssertNil(CardWords.meta([nil, nil], hiding: []))
    }

    func testAPersonKeepsOneInitialAndOneColor() {
        XCTAssertEqual(PersonMark.initial(of: "maya"), "M")
        XCTAssertEqual(PersonMark.initial(of: "  sam"), "S")
        XCTAssertEqual(PersonMark.initial(of: ""), "?")
        let first = PersonMark.colorIndex(for: "person-1", count: 6)
        XCTAssertEqual(first, PersonMark.colorIndex(for: "person-1", count: 6))
        XCTAssertTrue((0..<6).contains(first))
        XCTAssertEqual(PersonMark.colorIndex(for: "anyone", count: 0), 0)
        XCTAssertGreaterThan(Set((0..<40).map { PersonMark.colorIndex(for: "person-\($0)", count: 6) }).count, 3)
    }
}
