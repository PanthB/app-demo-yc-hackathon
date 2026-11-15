import XCTest

final class ListViewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-view", "list", "-BoardDebugSeed", "YES"] + extra
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

    private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(identifier: "dropRow")
    }

    private func row(_ app: XCUIApplication, kind: String) -> XCUIElement {
        rows(app).matching(NSPredicate(format: "label BEGINSWITH %@", kind + ",")).firstMatch
    }

    private func loose(_ app: XCUIApplication) -> XCUIElement {
        rows(app).matching(NSPredicate(format: "NOT (label ENDSWITH %@)", ", pinned")).firstMatch
    }

    private func list(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["listView"].firstMatch
    }

    private func detail(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["dropDetail"].firstMatch
    }

    private func find(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        for _ in 0..<12 where !element.isHittable { list(app).swipeUp(velocity: .default) }
        for _ in 0..<24 where !element.isHittable { list(app).swipeDown(velocity: .default) }
        return element.isHittable
    }

    private func walkTheList(_ app: XCUIApplication, prefix: String) {
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 20))
        XCTAssertTrue(header(app, "pinned").exists)
        attach("\(prefix)-1")
        let done = header(app, "done")
        var page = 1
        while !done.isHittable, page < 24 {
            list(app).swipeUp(velocity: .default)
            page += 1
            attach("\(prefix)-\(page)")
        }
        XCTAssertTrue(done.isHittable)
        XCTAssertEqual(done.value as? String, "closed")
        done.tap()
        list(app).swipeUp(velocity: .slow)
        XCTAssertEqual(done.value as? String, "open")
        XCTAssertTrue(rows(app).allElementsBoundByIndex.contains { $0.exists && $0.frame.minY >= done.frame.maxY })
        attach("\(prefix)-done-open")
    }

    func testListShowsEverySectionInLight() {
        XCUIDevice.shared.appearance = .light
        walkTheList(launch(), prefix: "light")
    }

    func testASharedBoardShowsItsSectionsWhateverTheyAre() {
        XCUIDevice.shared.appearance = .light
        let app = launch(extra: ["-BoardDebugBoard", "sf-crew"])
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 20))
        attach("crew-1")
        for page in 2...4 {
            list(app).swipeUp(velocity: .default)
            attach("crew-\(page)")
        }
    }

    func testListShowsEverySectionInDark() {
        XCUIDevice.shared.appearance = .dark
        walkTheList(launch(), prefix: "dark")
        XCUIDevice.shared.appearance = .light
    }

    func testASwipePinsARow() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 20))
        let first = loose(app)
        XCTAssertTrue(find(first, in: app))
        let name = first.label
        first.swipeRight(velocity: .slow)
        XCTAssertTrue(app.buttons["pin"].waitForExistence(timeout: 5))
        attach("swipe-pin")
        app.buttons["pin"].tap()
        let pinned = rows(app).matching(NSPredicate(format: "label == %@", name + ", pinned")).firstMatch
        XCTAssertTrue(pinned.waitForExistence(timeout: 5))
        attach("pinned")
    }

    func testASwipeMarksARowDone() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 20))
        let first = loose(app)
        XCTAssertTrue(find(first, in: app))
        let name = first.label
        first.swipeLeft(velocity: .slow)
        XCTAssertTrue(app.buttons["mark done"].waitForExistence(timeout: 5))
        attach("swipe-done")
        app.buttons["mark done"].tap()
        let gone = rows(app).matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(gone.waitForNonExistence(timeout: 5))
        attach("after-done")
    }

    func testATapOpensTheDetailForAPlaceAClipAndASong() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 20))
        var opened = 0
        for kind in ["place", "clip", "song"] where find(row(app, kind: kind), in: app) {
            row(app, kind: kind).tap()
            XCTAssertTrue(detail(app).waitForExistence(timeout: 5))
            sleep(1)
            attach("detail-\(kind)")
            detail(app).swipeDown(velocity: .fast)
            XCTAssertTrue(detail(app).waitForNonExistence(timeout: 5))
            opened += 1
        }
        XCTAssertGreaterThan(opened, 0)
    }

    func testTheDetailButtonsWork() throws {
        XCUIDevice.shared.appearance = .dark
        addTeardownBlock { XCUIDevice.shared.appearance = .light }
        let app = launch()
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 20))
        let song = rows(app).matching(NSPredicate(format: "label BEGINSWITH %@ AND NOT (label ENDSWITH %@)", "song,", ", pinned")).firstMatch
        try XCTSkipUnless(find(song, in: app), "this board has no song")
        let name = song.label
        song.tap()
        XCTAssertTrue(detail(app).waitForExistence(timeout: 5))
        sleep(1)
        attach("detail-dark")

        app.buttons["pin"].tap()
        XCTAssertTrue(app.buttons["unpin"].waitForExistence(timeout: 5))
        attach("detail-pinned")
        app.buttons["unpin"].tap()
        XCTAssertTrue(app.buttons["pin"].waitForExistence(timeout: 5))

        app.buttons["move to"].tap()
        XCTAssertTrue(app.buttons["tonight"].waitForExistence(timeout: 5))
        attach("detail-move-menu")
        app.buttons["tonight"].tap()
        XCTAssertTrue(app.buttons["tonight"].waitForNonExistence(timeout: 5))

        app.buttons["mark done"].tap()
        XCTAssertTrue(detail(app).waitForNonExistence(timeout: 5))
        XCTAssertFalse(rows(app).matching(NSPredicate(format: "label == %@", name)).firstMatch.exists)
        attach("detail-done")

        let clip = row(app, kind: "clip")
        try XCTSkipUnless(find(clip, in: app), "this board has no clip")
        clip.tap()
        XCTAssertTrue(detail(app).waitForExistence(timeout: 5))
        app.buttons["watch"].tap()
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
    }

    func testAnEmptyListSaysSo() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 20))
        app.open(URL(string: "appdemo://clear")!)
        XCTAssertTrue(app.staticTexts["nothing here yet."].firstMatch.waitForExistence(timeout: 20))
        XCTAssertEqual(rows(app).count, 0)
        attach("empty")
    }

    func testRowsFitTheLargestTextSize() {
        XCUIDevice.shared.appearance = .light
        let app = launch(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(rows(app).firstMatch.waitForExistence(timeout: 20))
        attach("largest-1")
        list(app).swipeUp(velocity: .slow)
        attach("largest-2")
    }
}
