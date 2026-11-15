import XCTest

final class CardsViewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-look", "glass", "-BoardDebugSeed", "YES"] + extra
        app.launch()
        return app
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func header(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)["section-\(id)"]
    }

    private func walkTheBoard(_ app: XCUIApplication, prefix: String) {
        XCTAssertTrue(header(app, "now").waitForExistence(timeout: 20))
        XCTAssertGreaterThan(app.descendants(matching: .any).matching(identifier: "dropCard").count, 2)
        attach("\(prefix)-1")
        let cards = app.descendants(matching: .any)["cardsView"]
        for page in 2...4 {
            cards.swipeUp(velocity: .slow)
            attach("\(prefix)-\(page)")
        }
        let done = header(app, "done")
        for _ in 0..<4 where !done.isHittable { cards.swipeUp(velocity: .slow) }
        XCTAssertTrue(done.isHittable)
        let before = app.descendants(matching: .any).matching(identifier: "dropCard").count
        done.tap()
        cards.swipeUp(velocity: .slow)
        XCTAssertGreaterThan(app.descendants(matching: .any).matching(identifier: "dropCard").count, before - 1)
        attach("\(prefix)-done-open")
    }

    func testCardsShowEverySectionInLight() {
        XCUIDevice.shared.appearance = .light
        walkTheBoard(launch(), prefix: "light")
    }

    func testCardsShowEverySectionInDarkWithPins() {
        XCUIDevice.shared.appearance = .dark
        let app = launch(["-GlassDebugPins", "YES"])
        XCTAssertTrue(header(app, "pinned").waitForExistence(timeout: 20))
        walkTheBoard(app, prefix: "dark")
        XCUIDevice.shared.appearance = .light
    }
}
