import XCTest
@testable import AppDemo

final class ShellToastTests: XCTestCase {
    func testAFriendsSongNamesHerAndTheKind() {
        let drop = Drop(authorId: "seed-maya", sourceKind: .url, url: "https://open.spotify.com/track/6ZRuF2n1CQxyxxAAWsKJOy")
        drop.authorName = "maya"
        drop.type = .song
        XCTAssertEqual(ShellToast.words(for: drop), "maya added a song.")
    }

    func testAnEventTakesAn() {
        let drop = Drop(authorId: "seed-sam", sourceKind: .url, url: "https://example.com")
        drop.authorName = "sam"
        drop.type = .event
        XCTAssertEqual(ShellToast.words(for: drop), "sam added an event.")
    }
}
