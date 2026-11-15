import XCTest

final class ListViewUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-view", "list", "-BoardDebugSeed", "YES"]
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

    private func row(_ app: XCUIApplication, saying words: String) -> XCUIElement {
        app.buttons.matching(identifier: "dropRow").matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    private func list(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["listView"].firstMatch
    }

    private func walkTheList(_ app: XCUIApplication, prefix: String) {
        XCTAssertTrue(header(app, "pinned").waitForExistence(timeout: 20))
        XCTAssertTrue(header(app, "now").exists)
        attach("\(prefix)-1")
        var seen: Set<String> = []
        let ids = ["pinned", "now", "tonight", "thisWeekend", "someday", "vibes", "done"]
        for page in 2...6 {
            ids.filter { header(app, $0).exists }.forEach { seen.insert($0) }
            list(app).swipeUp(velocity: .slow)
            attach("\(prefix)-\(page)")
        }
        ids.filter { header(app, $0).exists }.forEach { seen.insert($0) }
        XCTAssertEqual(seen, Set(ids))
        let done = header(app, "done")
        for _ in 0..<5 where !done.isHittable { list(app).swipeUp(velocity: .slow) }
        XCTAssertTrue(done.isHittable)
        XCTAssertFalse(row(app, saying: "dumpling").exists)
        done.tap()
        list(app).swipeUp(velocity: .slow)
        XCTAssertTrue(row(app, saying: "dumpling").waitForExistence(timeout: 5))
        attach("\(prefix)-done-open")
    }

    func testListShowsEverySectionInLight() {
        XCUIDevice.shared.appearance = .light
        walkTheList(launch(), prefix: "light")
    }

    func testListShowsEverySectionInDark() {
        XCUIDevice.shared.appearance = .dark
        walkTheList(launch(), prefix: "dark")
        XCUIDevice.shared.appearance = .light
    }

    func testASwipePinsARow() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        let matcha = row(app, saying: "stonemill matcha")
        XCTAssertTrue(matcha.waitForExistence(timeout: 20))
        XCTAssertFalse(matcha.label.contains("pinned"))
        matcha.swipeRight(velocity: .slow)
        XCTAssertTrue(app.buttons["pin"].waitForExistence(timeout: 5))
        attach("swipe-pin")
        app.buttons["pin"].tap()
        let pinned = row(app, saying: "stonemill matcha")
        XCTAssertTrue(pinned.waitForExistence(timeout: 5))
        XCTAssertTrue(pinned.label.contains("pinned"))
        attach("pinned")
    }

    func testASwipeMarksARowDone() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        let reminder = row(app, saying: "call mom back")
        XCTAssertTrue(reminder.waitForExistence(timeout: 20))
        reminder.swipeLeft(velocity: .slow)
        XCTAssertTrue(app.buttons["mark done"].waitForExistence(timeout: 5))
        attach("swipe-done")
        app.buttons["mark done"].tap()
        XCTAssertTrue(reminder.waitForNonExistence(timeout: 5))
        attach("after-done")
    }

    func testATapOpensTheDetailForASongAClipAndAPlace() {
        XCUIDevice.shared.appearance = .light
        let app = launch()
        XCTAssertTrue(header(app, "now").waitForExistence(timeout: 20))
        for (words, name) in [("stonemill matcha", "place"), ("tonkotsu ramen", "cutout"), ("pink pony club", "song"), ("warehouse show", "clip")] {
            let drop = row(app, saying: words)
            for _ in 0..<6 where !drop.isHittable { list(app).swipeUp(velocity: .slow) }
            drop.tap()
            let detail = app.descendants(matching: .any)["dropDetail"].firstMatch
            XCTAssertTrue(detail.waitForExistence(timeout: 5))
            sleep(1)
            attach("detail-\(name)")
            detail.swipeDown(velocity: .fast)
            XCTAssertTrue(detail.waitForNonExistence(timeout: 5))
        }
    }

    func testTheDetailButtonsWork() {
        XCUIDevice.shared.appearance = .dark
        let app = launch()
        let song = row(app, saying: "pink pony club")
        XCTAssertTrue(song.waitForExistence(timeout: 20))
        for _ in 0..<6 where !song.isHittable { list(app).swipeUp(velocity: .slow) }
        song.tap()
        let detail = app.descendants(matching: .any)["dropDetail"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        sleep(1)
        attach("detail-dark")

        app.buttons["pin"].tap()
        XCTAssertTrue(app.buttons["unpin"].waitForExistence(timeout: 5))
        attach("detail-pinned")

        app.buttons["move to"].tap()
        XCTAssertTrue(app.buttons["tonight"].waitForExistence(timeout: 5))
        attach("detail-move-menu")
        app.buttons["tonight"].tap()
        XCTAssertTrue(app.buttons["tonight"].waitForNonExistence(timeout: 5))

        app.buttons["mark done"].tap()
        XCTAssertTrue(detail.waitForNonExistence(timeout: 5))
        XCTAssertFalse(row(app, saying: "pink pony club").exists)
        attach("detail-done")

        let clip = row(app, saying: "warehouse show")
        for _ in 0..<6 where !clip.isHittable { list(app).swipeUp(velocity: .slow) }
        clip.tap()
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        app.buttons["watch"].tap()
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 10))
        XCUIDevice.shared.appearance = .light
    }
}
