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
        let status = element(app, "cameraStatus")
        XCTAssertFalse(status.exists, "nothing is dropping yet, so there's no status")
        XCTAssertFalse(element(app, "cameraLastPhoto").isEnabled)
        attach("camera-1-viewfinder")

        shutter.tap()
        XCTAssertTrue(status.waitForExistence(timeout: 2))
        let dropped = NSPredicate(format: "label BEGINSWITH %@", "dropped it into")
        expectation(for: dropped, evaluatedWith: status)
        waitForExpectations(timeout: 3)
        attach("camera-2-dropped")
        XCTAssertTrue(status.waitForNonExistence(timeout: 4), "the status goes away once the photo has landed")

        shutter.tap()
        shutter.tap()
        sleep(2)
        let lastPhoto = element(app, "cameraLastPhoto")
        XCTAssertTrue(lastPhoto.isEnabled)
        XCTAssertTrue(lastPhoto.label.hasPrefix("you dropped 3 photos into"), lastPhoto.label)
        attach("camera-3-three-photos")

        let flash = element(app, "cameraFlash")
        XCTAssertEqual(flash.label, "the flash is off.")
        flash.tap()
        XCTAssertEqual(flash.label, "the flash comes on when it's dark.")

        let oneX = element(app, "cameraZoom-1")
        let twoX = element(app, "cameraZoom-2")
        XCTAssertTrue(oneX.isSelected)
        twoX.tap()
        XCTAssertTrue(twoX.isSelected)
        XCTAssertFalse(oneX.isSelected)

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
