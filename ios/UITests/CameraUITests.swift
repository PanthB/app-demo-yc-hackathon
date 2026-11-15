import XCTest

final class CameraUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-BoardDebugSeed", "YES", "-CameraDebugOpen", "YES"] + extra
        app.launch()
        return app
    }

    private func attach(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    func testTakingAPhotoDropsItIntoTheBoardChip() {
        let app = launch()
        let shutter = element(app, "cameraShutter")
        XCTAssertTrue(shutter.waitForExistence(timeout: 20))
        let chip = element(app, "cameraBoardChip")
        XCTAssertTrue(chip.label.hasPrefix("dropping into"), chip.label)
        attach("camera-1-viewfinder")

        shutter.tap()
        let dropped = NSPredicate(format: "label BEGINSWITH %@", "dropped it into")
        expectation(for: dropped, evaluatedWith: chip)
        waitForExpectations(timeout: 3)
        attach("camera-2-dropped")

        shutter.tap()
        shutter.tap()
        sleep(2)
        attach("camera-3-three-photos")

        let flash = element(app, "cameraFlash")
        XCTAssertEqual(flash.label, "the flash is off.")
        flash.tap()
        XCTAssertEqual(flash.label, "the flash comes on when it's dark.")

        let zoom = element(app, "cameraZoom")
        XCTAssertEqual(zoom.label, "zoom is 1×")
        zoom.tap()
        XCTAssertEqual(zoom.label, "zoom is 2×")

        let flip = element(app, "cameraFlip")
        XCTAssertEqual(flip.label, "switch to the front camera")
        flip.tap()
        let flipped = NSPredicate(format: "label == %@", "switch to the back camera")
        expectation(for: flipped, evaluatedWith: flip)
        waitForExpectations(timeout: 3)
        attach("camera-4-controls")

        element(app, "cameraClose").tap()
        XCTAssertTrue(shutter.waitForNonExistence(timeout: 3))
        attach("camera-5-closed")
    }

    func testBeforeAskingItExplainsAndThenOpens() {
        let app = launch(["-CameraDebugAccess", "notAsked"])
        let ask = element(app, "cameraAsk")
        XCTAssertTrue(ask.waitForExistence(timeout: 20))
        attach("camera-access-not-asked")
        ask.tap()
        XCTAssertTrue(element(app, "cameraShutter").waitForExistence(timeout: 3))
    }

    func testDeniedOffersSettingsAndPhotos() {
        let app = launch(["-CameraDebugAccess", "denied"])
        XCTAssertTrue(element(app, "cameraSettings").waitForExistence(timeout: 20))
        XCTAssertTrue(element(app, "cameraPickInstead").exists)
        attach("camera-access-denied")
    }

    func testNoCameraOffersPhotos() {
        let app = launch(["-CameraDebugAccess", "unavailable"])
        XCTAssertTrue(element(app, "cameraPickInstead").waitForExistence(timeout: 20))
        attach("camera-access-unavailable")
        element(app, "cameraClose").tap()
        XCTAssertTrue(element(app, "cameraPickInstead").waitForNonExistence(timeout: 3))
    }
}
