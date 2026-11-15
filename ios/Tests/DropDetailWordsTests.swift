import XCTest
@testable import AppDemo

final class DropDetailWordsTests: XCTestCase {
    func testADropMovesToAnySectionButDoneOrTheOneItIsIn() {
        XCTAssertEqual(Zone.moveTargets(from: .now), [.tonight, .thisWeekend, .someday, .vibes])
        XCTAssertEqual(Zone.moveTargets(from: .vibes), [.now, .tonight, .thisWeekend, .someday])
        XCTAssertEqual(Zone.moveTargets(from: .done), [.now, .tonight, .thisWeekend, .someday, .vibes])
    }

    func testTheSaverIsYouOrTheirName() {
        XCTAssertEqual(CardWords.saver("Maya", isMe: false), "maya")
        XCTAssertEqual(CardWords.saver("panth", isMe: true), "you")
        XCTAssertEqual(CardWords.saver(nil, isMe: true), "you")
        XCTAssertEqual(CardWords.saver("  ", isMe: false), "someone")
    }

    func testTheOpenButtonSaysWhatOpeningDoes() {
        XCTAssertEqual(DropKind.song.openWord, "listen")
        XCTAssertEqual(DropKind.video.openWord, "watch")
        XCTAssertEqual(DropKind.place.openWord, "visit")
        XCTAssertEqual(DropKind.link.openWord, "open")
        for kind in DropKind.allCases {
            XCTAssertEqual(kind.openWord, kind.openWord.lowercased())
        }
    }
}
