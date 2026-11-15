import XCTest
@testable import AppDemo

final class LookTests: XCTestCase {
    func testLaunchArgumentWinsOverStoredSetting() {
        XCTAssertEqual(Look.resolve(arguments: ["AppDemo", "-look", "glass"], stored: "paper"), .glass)
        XCTAssertEqual(Look.resolve(arguments: ["AppDemo", "-look", "paper"], stored: "glass"), .paper)
    }

    func testStoredSettingThenPaper() {
        XCTAssertEqual(Look.resolve(arguments: ["AppDemo"], stored: "glass"), .glass)
        XCTAssertEqual(Look.resolve(arguments: ["AppDemo"], stored: nil), .paper)
        XCTAssertEqual(Look.resolve(arguments: ["AppDemo"], stored: "neon"), .paper)
        XCTAssertEqual(Look.resolve(arguments: ["AppDemo", "-look"], stored: "glass"), .glass)
        XCTAssertEqual(Look.resolve(arguments: ["AppDemo", "-look", "neon"], stored: nil), .paper)
    }

    func testDeepLinks() {
        XCTAssertEqual(Look(url: URL(string: "appdemo://look/glass")!), .glass)
        XCTAssertEqual(Look(url: URL(string: "appdemo://look/paper")!), .paper)
        XCTAssertEqual(Look(url: URL(string: "AppDemo://Look/Glass")!), .glass)
        XCTAssertNil(Look(url: URL(string: "appdemo://look/neon")!))
        XCTAssertNil(Look(url: URL(string: "appdemo://board/glass")!))
        XCTAssertNil(Look(url: URL(string: "https://look/glass")!))
    }
}
