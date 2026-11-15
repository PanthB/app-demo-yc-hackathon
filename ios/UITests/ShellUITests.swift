import XCTest

final class ShellUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.appearance = .light
    }

    private func launch(_ view: String = "cards") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-view", view, "-BoardDebugSeed", "YES"]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func drop(_ app: XCUIApplication, saying words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    private func title(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        app.navigationBars.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
    }

    private func pause(_ seconds: Double = 1.2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    func testAFriendsDropShowsItsToast() {
        let app = launch()
        XCTAssertTrue(element(app, "cardsView").waitForExistence(timeout: 20))
        pause()
        app.open(URL(string: "appdemo://arrive")!)
        let toast = element(app, "arrivalToast")
        XCTAssertTrue(toast.waitForExistence(timeout: 15))
        XCTAssertEqual(toast.label, "maya added a song.")
        XCTAssertTrue(toast.waitForNonExistence(timeout: 5))
    }

    func testACardZoomsIntoItsDetailAndBack() {
        let app = launch()
        let card = element(app, "dropCard")
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        pause()
        card.tap()
        XCTAssertTrue(element(app, "dropDetail").waitForExistence(timeout: 5))
        pause(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        pause()
    }

    func testABoardObjectZoomsIntoItsDetail() {
        let app = launch("board")
        let reminder = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "reminder")).firstMatch
        XCTAssertTrue(reminder.waitForExistence(timeout: 20))
        pause()
        reminder.tap()
        XCTAssertTrue(element(app, "dropDetail").waitForExistence(timeout: 5))
        pause(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(element(app, "paperBoard").waitForExistence(timeout: 5))
    }

    func testTheBarSwitchesViewsAndNightHidesTheShell() {
        let app = launch()
        XCTAssertTrue(element(app, "cardsView").waitForExistence(timeout: 20))
        pause()
        element(app, "view-list").tap()
        XCTAssertTrue(element(app, "listView").waitForExistence(timeout: 5))
        pause()
        element(app, "view-board").tap()
        XCTAssertTrue(element(app, "paperBoard").waitForExistence(timeout: 5))
        XCTAssertTrue(title(app, "my board").exists)
        pause()
        element(app, "view-night").tap()
        XCTAssertTrue(element(app, "nightBoard").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "view-cards").exists)
        pause()
    }

    func testTheTitleMenuOpensSfCrewByMoodWithItsPeople() {
        let app = launch()
        XCTAssertTrue(element(app, "cardsView").waitForExistence(timeout: 20))
        let home = title(app, "my board")
        XCTAssertTrue(home.waitForExistence(timeout: 10))
        home.tap()
        let crew = app.buttons["sf crew"]
        XCTAssertTrue(crew.waitForExistence(timeout: 5))
        crew.tap()
        XCTAssertTrue(title(app, "sf crew").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "filterControl").exists)
        XCTAssertTrue(element(app, "section-cluster-late-night").waitForExistence(timeout: 5))
        pause()

        XCTAssertTrue(drop(app, saying: "nights like this").exists)
        app.buttons["mine"].tap()
        XCTAssertTrue(drop(app, saying: "dreams").waitForExistence(timeout: 5))
        XCTAssertFalse(drop(app, saying: "nights like this").exists)
        app.buttons["everyone"].tap()
        pause()

        element(app, "view-board").tap()
        XCTAssertTrue(element(app, "clusterBoard").waitForExistence(timeout: 5))
        pause(2)

        element(app, "membersButton").tap()
        XCTAssertTrue(app.staticTexts["people in sf crew"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["maya"].exists)
        pause()
    }
}
