import XCTest
@testable import AppDemo

final class ViewModeTests: XCTestCase {
    func testLaunchArgumentWinsOverStoredSetting() {
        XCTAssertEqual(ViewMode.resolve(arguments: ["AppDemo", "-view", "board"], stored: "list"), .board)
        XCTAssertEqual(ViewMode.resolve(arguments: ["AppDemo", "-view", "list"], stored: "board"), .list)
        XCTAssertEqual(ViewMode.resolve(arguments: ["AppDemo", "-view", "night"], stored: "cards"), .night)
    }

    func testStoredSettingThenCardsByDefault() {
        XCTAssertEqual(ViewMode.resolve(arguments: ["AppDemo"], stored: "board"), .board)
        XCTAssertEqual(ViewMode.resolve(arguments: ["AppDemo"], stored: nil), .cards)
        XCTAssertEqual(ViewMode.resolve(arguments: ["AppDemo"], stored: "glass"), .cards)
        XCTAssertEqual(ViewMode.resolve(arguments: ["AppDemo", "-view"], stored: "list"), .list)
        XCTAssertEqual(ViewMode.resolve(arguments: ["AppDemo", "-view", "grid"], stored: nil), .cards)
    }

    func testDeepLinks() {
        XCTAssertEqual(ViewMode(url: URL(string: "appdemo://view/list")!), .list)
        XCTAssertEqual(ViewMode(url: URL(string: "appdemo://view/cards")!), .cards)
        XCTAssertEqual(ViewMode(url: URL(string: "AppDemo://View/Board")!), .board)
        XCTAssertEqual(ViewMode(url: URL(string: "appdemo://view/night")!), .night)
        XCTAssertNil(ViewMode(url: URL(string: "appdemo://view/grid")!))
        XCTAssertNil(ViewMode(url: URL(string: "appdemo://look/glass")!))
        XCTAssertNil(ViewMode(url: URL(string: "https://view/list")!))
    }
}
