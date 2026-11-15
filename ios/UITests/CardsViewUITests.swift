import XCTest

final class CardsViewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-view", "cards", "-BoardDebugSeed", "YES"]
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

    private func drop(_ app: XCUIApplication, saying words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    private func pinnedCount(_ app: XCUIApplication) -> Int {
        app.descendants(matching: .any).matching(identifier: "pinnedCard").count
    }

    private func walkTheBoard(_ app: XCUIApplication, prefix: String) {
        XCTAssertTrue(header(app, "pinned").waitForExistence(timeout: 20))
        XCTAssertTrue(header(app, "now").exists)
        XCTAssertEqual(pinnedCount(app), 2)
        attach("\(prefix)-1")
        let cards = app.descendants(matching: .any)["cardsView"]
        for page in 2...5 {
            cards.swipeUp(velocity: .slow)
            attach("\(prefix)-\(page)")
        }
        let done = header(app, "done")
        for _ in 0..<5 where !done.isHittable { cards.swipeUp(velocity: .slow) }
        XCTAssertTrue(done.isHittable)
        XCTAssertFalse(drop(app, saying: "dumpling").exists)
        done.tap()
        cards.swipeUp(velocity: .slow)
        XCTAssertTrue(drop(app, saying: "dumpling").waitForExistence(timeout: 5))
        attach("\(prefix)-done-open")
    }

    func testCardsShowEverySectionInLight() {
        XCUIDevice.shared.appearance = .light
        walkTheBoard(launch(), prefix: "light")
    }

    func testCardsShowEverySectionInDark() {
        XCUIDevice.shared.appearance = .dark
        walkTheBoard(launch(), prefix: "dark")
        XCUIDevice.shared.appearance = .light
    }

    func testALongPressPinsADropAndMarksAnotherDone() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        XCTAssertTrue(header(app, "now").waitForExistence(timeout: 20))
        XCTAssertEqual(pinnedCount(app), 2)

        let matcha = drop(app, saying: "stonemill matcha")
        XCTAssertTrue(matcha.waitForExistence(timeout: 5))
        matcha.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["pin"].waitForExistence(timeout: 5))
        attach("menu")
        app.buttons["pin"].tap()
        XCTAssertTrue(app.buttons["pin"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(pinnedCount(app), 3)
        attach("pinned-three")

        let reminder = drop(app, saying: "call mom back")
        XCTAssertTrue(reminder.waitForExistence(timeout: 5))
        reminder.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["mark done"].waitForExistence(timeout: 5))
        app.buttons["mark done"].tap()
        XCTAssertTrue(reminder.waitForNonExistence(timeout: 5))
        attach("after-done")
    }
}
