import XCTest

final class CardsViewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(seeded: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-view", "cards"] + (seeded ? ["-BoardDebugSeed", "YES"] : []) + extra
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

    private func all(_ app: XCUIApplication, _ id: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: id)
    }

    private func board(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["cardsView"].firstMatch
    }

    private func scrollToDone(_ app: XCUIApplication, attaching prefix: String? = nil) -> XCUIElement {
        let done = header(app, "done")
        var page = 1
        while !done.isHittable, page < 24 {
            board(app).swipeUp(velocity: prefix == nil ? .fast : .default)
            page += 1
            if let prefix { attach("\(prefix)-\(page)") }
        }
        return done
    }

    private func settles(_ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(5)
        while Date() < end, !condition() { usleep(200_000) }
        return condition()
    }

    private func cardsBelow(_ app: XCUIApplication, _ header: XCUIElement) -> Int {
        all(app, "dropCard").allElementsBoundByIndex.filter { $0.exists && $0.frame.minY >= header.frame.maxY }.count
    }

    private func walkTheBoard(_ app: XCUIApplication, prefix: String) {
        XCTAssertTrue(all(app, "dropCard").firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(header(app, "pinned").exists)
        XCTAssertGreaterThan(all(app, "pinnedCard").count, 0)
        attach("\(prefix)-1")
        let done = scrollToDone(app, attaching: prefix)
        XCTAssertTrue(done.isHittable)
        XCTAssertEqual(done.value as? String, "closed")
        done.tap()
        board(app).swipeUp(velocity: .slow)
        XCTAssertEqual(done.value as? String, "open")
        XCTAssertTrue(settles { cardsBelow(app, done) > 0 })
        attach("\(prefix)-done-open")
    }

    func testCardsShowEverySectionInLight() {
        XCUIDevice.shared.appearance = .light
        walkTheBoard(launch(), prefix: "light")
    }

    func testASharedBoardShowsItsSectionsWhateverTheyAre() {
        XCUIDevice.shared.appearance = .light
        let app = launch(extra: ["-BoardDebugBoard", "sf-crew"])
        XCTAssertTrue(all(app, "dropCard").firstMatch.waitForExistence(timeout: 20))
        attach("crew-1")
        for page in 2...6 {
            board(app).swipeUp(velocity: .default)
            attach("crew-\(page)")
        }
    }

    func testCardsShowEverySectionInDark() {
        XCUIDevice.shared.appearance = .dark
        walkTheBoard(launch(), prefix: "dark")
        XCUIDevice.shared.appearance = .light
    }

    func testALongPressPinsADropAndMarksAnotherDone() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        let first = all(app, "dropCard").firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 20))
        let pinnedBefore = all(app, "pinnedCard").count

        first.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["pin"].waitForExistence(timeout: 5))
        attach("menu")
        app.buttons["pin"].tap()
        XCTAssertTrue(app.buttons["pin"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(all(app, "pinnedCard").count, pinnedBefore + 1)
        attach("pinned-one-more")

        let next = all(app, "dropCard").firstMatch
        let name = next.label
        next.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["mark done"].waitForExistence(timeout: 5))
        app.buttons["mark done"].tap()
        let gone = all(app, "dropCard").matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(gone.waitForNonExistence(timeout: 5))
        attach("after-done")
    }

    func testATapZoomsIntoTheDetail() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        XCTAssertTrue(all(app, "dropCard").firstMatch.waitForExistence(timeout: 20))
        let place = all(app, "dropCard").matching(NSPredicate(format: "label BEGINSWITH %@", "place,")).firstMatch
        let card = place.exists ? place : all(app, "dropCard").firstMatch
        card.tap()
        let detail = app.descendants(matching: .any)["dropDetail"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        sleep(1)
        attach("detail")
        detail.swipeDown(velocity: .fast)
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5))
    }

    func testDoneOpensAndCloses() throws {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        XCTAssertTrue(all(app, "dropCard").firstMatch.waitForExistence(timeout: 20))
        let done = scrollToDone(app)
        try XCTSkipUnless(done.isHittable, "this board has nothing done")
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        done.tap()
        board(app).swipeUp(velocity: .slow)
        XCTAssertEqual(done.value as? String, "open")
        XCTAssertTrue(settles { cardsBelow(app, done) > 0 })
        attach("done-opened")
        XCTAssertTrue(done.isHittable)
        done.tap()
        XCTAssertEqual(done.value as? String, "closed")
        XCTAssertTrue(settles { cardsBelow(app, done) == 0 })
        attach("done-closed")
    }

    func testAnEmptyBoardSaysSo() {
        XCUIDevice.shared.appearance = .light
        let app = launch(seeded: false)
        app.open(URL(string: "appdemo://clear")!)
        XCTAssertTrue(app.staticTexts["nothing here yet."].firstMatch.waitForExistence(timeout: 20))
        XCTAssertEqual(all(app, "dropCard").count, 0)
        attach("empty")
    }

    func testCardsStackInOneColumnAtTheLargestTextSize() {
        XCUIDevice.shared.appearance = .light
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let card = all(app, "dropCard").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        XCTAssertEqual(all(app, "pinnedCard").count, 0)
        XCTAssertGreaterThan(card.frame.width, app.frame.width * 0.8)
        attach("largest-1")
        board(app).swipeUp(velocity: .slow)
        attach("largest-2")
        board(app).swipeUp(velocity: .slow)
        attach("largest-3")
    }
}
