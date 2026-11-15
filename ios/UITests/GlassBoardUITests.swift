import XCTest

final class GlassBoardUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-look", "glass"]
        app.launch()
        return app
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func element(_ app: XCUIApplication, labelled text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    func testBoardShowsEveryZoneAndTheSampleDrops() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["now"].waitForExistence(timeout: 15))
        for label in ["someday", "tonight", "vibes"] {
            XCTAssertTrue(app.staticTexts[label].exists, "missing the \(label) label")
        }
        for words in ["move the car", "the matcha place", "ramen on clement", "mk.gee at the fillmore"] {
            XCTAssertTrue(element(app, labelled: words).exists, "missing the drop that says \(words)")
        }
        attach("board")
    }

    func testDoneTrayOpensAndCloses() {
        let app = launch()
        let done = app.descendants(matching: .any)["glassDone"]
        XCTAssertTrue(done.waitForExistence(timeout: 15))
        XCTAssertFalse(element(app, labelled: "farmers market").exists)
        done.tap()
        XCTAssertTrue(element(app, labelled: "farmers market").waitForExistence(timeout: 5))
        attach("done-open")
        app.staticTexts["done"].tap()
        XCTAssertTrue(element(app, labelled: "farmers market").waitForNonExistence(timeout: 5))
        attach("done-closed")
    }
}
