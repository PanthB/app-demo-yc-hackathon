import XCTest

final class BoardViewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testALongPressOnAnObjectOpensItsMenuAndDoneMovesItToThePocket() {
        XCUIDevice.shared.appearance = .light
        let app = XCUIApplication()
        app.launchArguments = ["-view", "board", "-BoardDebugSeed", "YES"]
        app.launch()

        let pocket = app.descendants(matching: .any)["donePocket"]
        let now = app.descendants(matching: .any)["section-now"]
        XCTAssertTrue(now.waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["section-pinned"].exists)
        let before = pocket.label

        let reminder = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "reminder")).firstMatch
        XCTAssertTrue(reminder.exists)
        reminder.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["pin"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["move to"].exists)
        app.buttons["mark done"].tap()

        XCTAssertFalse(reminder.waitForExistence(timeout: 2))
        for _ in 0..<6 where !pocket.isHittable { app.swipeUp(velocity: .slow) }
        XCTAssertNotEqual(pocket.label, before)
        XCTAssertEqual(pocket.label, "done, 2 things")
    }
}
