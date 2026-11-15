import XCTest

final class SuggestionsFeedUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(board: String = "sf-crew", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-view", "cards", "-BoardDebugSeed", "YES", "-BoardDebugSuggestions", board, "-BoardDebugSuggestionsSample", "YES"] + extra
        app.launch()
        let back = app.buttons["recsBackOn"]
        if back.waitForExistence(timeout: 2) { back.tap() }
        return app
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func saves(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "suggestionSave")
    }

    private func settles(_ query: XCUIElementQuery, at count: Int) -> Bool {
        let done = XCTNSPredicateExpectation(predicate: NSPredicate(format: "count == %d", count), object: query)
        return XCTWaiter().wait(for: [done], timeout: 6) == .completed
    }

    private func walk(_ app: XCUIApplication, attaching prefix: String) {
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 10))
        attach("\(prefix)-1")
        let end = app.descendants(matching: .any)["cluster-golden-hour"]
        var page = 1
        while !end.isHittable, page < 8 {
            app.swipeUp(velocity: .slow)
            page += 1
            attach("\(prefix)-\(page)")
        }
        XCTAssertTrue(end.isHittable, "the feed never reached the cluster that is still being searched")
    }

    func testTheFeedShowsEveryClusterInLight() {
        let app = launch(extra: ["-AppleInterfaceStyle", "Light"])
        XCUIDevice.shared.appearance = .light
        walk(app, attaching: "feed-light")
    }

    func testTheFeedShowsEveryClusterInDark() {
        let app = launch()
        XCUIDevice.shared.appearance = .dark
        walk(app, attaching: "feed-dark")
        XCUIDevice.shared.appearance = .light
    }

    func testSavingAndDismissingTakeACardAway() {
        let app = launch()
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 10))
        let before = saves(app).count
        saves(app).firstMatch.tap()
        XCTAssertTrue(settles(saves(app), at: before - 1), "saving left the card in the feed")
        app.buttons.matching(identifier: "suggestionDismiss").firstMatch.tap()
        XCTAssertTrue(settles(saves(app), at: before - 2), "dismissing left the card in the feed")
        attach("feed-after-save-and-dismiss")
    }

    func testTurningBothKindsOffSaysSoAndComesBack() {
        let app = launch()
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 10))
        app.buttons["recsMenu"].tap()
        let media = app.buttons["songs, clips and shows"]
        XCTAssertTrue(media.waitForExistence(timeout: 5))
        attach("feed-recs-menu")
        media.tap()
        let events = app.buttons["events and places nearby"]
        if !events.waitForExistence(timeout: 2) {
            app.buttons["recsMenu"].tap()
            XCTAssertTrue(events.waitForExistence(timeout: 5))
        }
        events.tap()
        let off = app.staticTexts["recommendations are off."]
        if !off.waitForExistence(timeout: 2) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        }
        XCTAssertTrue(off.waitForExistence(timeout: 5))
        let back = app.buttons["recsBackOn"]
        if !back.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        }
        attach("feed-recs-off")
        back.tap()
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 5))
    }

    func testAnEmptyFeedSaysSo() {
        let app = launch(board: "seed-panth-board")
        XCTAssertTrue(app.staticTexts["nothing yet."].waitForExistence(timeout: 10))
        attach("feed-empty")
    }

    func testCardsFitTheLargestTextSize() {
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 10))
        attach("feed-largest-text")
        XCTAssertTrue(app.buttons.matching(identifier: "suggestionDismiss").firstMatch.isHittable)
    }
}
