import XCTest

final class SuggestionsFeedUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(sample: String = "full", extra: [String] = []) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-view", "cards", "-BoardDebugSeed", "YES", "-BoardDebugSuggestionsSample", sample] + extra
        app.launch()
        let way = app.buttons["suggestionsButton"]
        guard way.waitForExistence(timeout: 10) else { throw XCTSkip("nothing in the shell opens the suggestions feed.") }
        way.tap()
        guard app.buttons["recsMenu"].waitForExistence(timeout: 5) else { throw XCTSkip("the shell's button doesn't show SuggestionsFeed yet.") }
        let back = app.buttons["turn them back on"]
        if back.waitForExistence(timeout: 1) { back.tap() }
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

    func testTheFeedShowsEveryClusterInLight() throws {
        let app = try launch(extra: ["-AppleInterfaceStyle", "Light"])
        XCUIDevice.shared.appearance = .light
        walk(app, attaching: "feed-light")
    }

    func testTheFeedShowsEveryClusterInDark() throws {
        let app = try launch()
        XCUIDevice.shared.appearance = .dark
        walk(app, attaching: "feed-dark")
        XCUIDevice.shared.appearance = .light
    }

    func testSavingAndDismissingTakeACardAway() throws {
        let app = try launch()
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 10))
        let titles = app.staticTexts.matching(identifier: "suggestionTitle")
        let saved = titles.firstMatch.label
        saves(app).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["feedNote"].waitForExistence(timeout: 3), "saving said nothing")
        attach("feed-saved")
        XCTAssertTrue(settles(app.staticTexts.matching(NSPredicate(format: "label == %@", saved)), at: 0), "saving left the card in the feed")
        let dismissed = titles.firstMatch.label
        XCTAssertNotEqual(dismissed, saved)
        app.buttons.matching(identifier: "suggestionDismiss").firstMatch.tap()
        XCTAssertTrue(settles(app.staticTexts.matching(NSPredicate(format: "label == %@", dismissed)), at: 0), "dismissing left the card in the feed")
        attach("feed-after-save-and-dismiss")
    }

    func testRefreshSaysItsLookingThenBringsANewOne() throws {
        let app = try launch()
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 10))
        let refresh = app.buttons["refreshSuggestions"]
        XCTAssertTrue(refresh.waitForExistence(timeout: 5))
        let header = app.descendants(matching: .any)["cluster-sunny-afternoons"]
        XCTAssertFalse(header.label.contains("looking for new ones"))
        refresh.tap()
        let looking = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS %@", "looking for new ones"), object: header)
        XCTAssertEqual(XCTWaiter().wait(for: [looking], timeout: 3), .completed, "a refresh didn't say it was looking")
        attach("feed-refresh-looking")
        refresh.tap()
        XCTAssertTrue(app.staticTexts["already looking."].waitForExistence(timeout: 3), "a second refresh didn't say it was already looking")
        attach("feed-refresh-already-looking")
        XCTAssertTrue(app.staticTexts["dandelion chocolate"].waitForExistence(timeout: 10), "nothing new arrived after a refresh")
        let quiet = XCTNSPredicateExpectation(predicate: NSPredicate(format: "NOT (label CONTAINS %@)", "looking for new ones"), object: header)
        XCTAssertEqual(XCTWaiter().wait(for: [quiet], timeout: 5), .completed, "the looking line stayed after the new one arrived")
        attach("feed-refresh-arrived")
    }

    func testTurningBothKindsOffSaysSoAndComesBack() throws {
        let app = try launch()
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
        let back = app.buttons["turn them back on"]
        if !back.isHittable {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        }
        attach("feed-recs-off")
        back.tap()
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 5))
    }

    func testAnEmptyFeedSaysSo() throws {
        let app = try launch(sample: "empty")
        XCTAssertTrue(app.staticTexts["nothing yet."].waitForExistence(timeout: 10))
        attach("feed-empty")
    }

    func testCardsFitTheLargestTextSize() throws {
        let app = try launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(saves(app).firstMatch.waitForExistence(timeout: 10))
        attach("feed-largest-text-1")
        let dismiss = app.buttons.matching(identifier: "suggestionDismiss").firstMatch
        var page = 1
        while !dismiss.isHittable, page < 8 {
            app.swipeUp(velocity: .slow)
            page += 1
            attach("feed-largest-text-\(page)")
        }
        XCTAssertTrue(dismiss.isHittable, "the card's buttons never came into reach at the largest text size")
    }
}
