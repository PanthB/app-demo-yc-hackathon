import XCTest
@testable import AppDemo

final class CameraTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testAPhotoGoesIntoTheInboxAsAnImageDrop() throws {
        let inbox = Inbox(root: root)
        let taken = Date(timeIntervalSince1970: 1_794_768_000)
        let written = try XCTUnwrap(CameraInbox.drop(Data("pixels".utf8), into: inbox, takenAt: taken))

        XCTAssertEqual(written.kind, .image)
        XCTAssertEqual(written.files, ["photo.jpg"])
        XCTAssertEqual(written.createdAt, taken)
        XCTAssertEqual(inbox.pending(), [written])
        XCTAssertEqual(try Data(contentsOf: inbox.fileURL("photo.jpg", in: written)), Data("pixels".utf8))
    }

    func testEachPhotoIsItsOwnDrop() throws {
        let inbox = Inbox(root: root)
        CameraInbox.drop(Data("one".utf8), into: inbox)
        CameraInbox.drop(Data("two".utf8), into: inbox)
        XCTAssertEqual(inbox.pending().count, 2)
    }

    func testWithoutAnInboxNothingIsWritten() {
        XCTAssertNil(CameraInbox.drop(Data("pixels".utf8), into: nil))
    }

    func testFlashCyclesOffAutoOn() {
        XCTAssertEqual(CameraFlash.off.next, .auto)
        XCTAssertEqual(CameraFlash.auto.next, .on)
        XCTAssertEqual(CameraFlash.on.next, .off)
    }

    func testZoomStaysInsideWhatTheCameraCanDo() {
        XCTAssertEqual(CameraModel.clamp(0.5, from: 1, to: 8), 1)
        XCTAssertEqual(CameraModel.clamp(3, from: 1, to: 8), 3)
        XCTAssertEqual(CameraModel.clamp(20, from: 1, to: 8), 8)
        XCTAssertEqual(CameraModel.clamp(2, from: 1, to: 0.5), 1)
    }

    @MainActor
    func testTheZoomButtonUnderThePinchIsSelected() {
        XCTAssertEqual(DropCamera.selectedPreset(for: 1, in: [1, 2]), 1)
        XCTAssertEqual(DropCamera.selectedPreset(for: 1.6, in: [1, 2]), 1)
        XCTAssertEqual(DropCamera.selectedPreset(for: 1.98, in: [1, 2]), 2)
        XCTAssertEqual(DropCamera.selectedPreset(for: 5, in: [1, 2]), 2)
    }

    @MainActor
    func testZoomWordsReadLikeTheCameraApp() {
        XCTAssertEqual(DropCamera.zoomWords(1), "1×")
        XCTAssertEqual(DropCamera.zoomWords(2), "2×")
        XCTAssertEqual(DropCamera.zoomWords(2.46), "2.5×")
    }

    @MainActor
    func testTheBoardNameMatchesTheBoardThePhotoLandsIn() {
        XCTAssertEqual(DropCamera.boardName(SeedBoard.crewBoardId, remote: []), "sf crew")
        XCTAssertEqual(DropCamera.boardName(SeedBoard.homeBoardId, remote: []), "my board")
        let roomies = RemoteBoard(boardId: "b1", name: "roomies", shared: true, inviteCode: nil, ownerId: "p", members: [], createdAt: 0)
        XCTAssertEqual(DropCamera.boardName("b1", remote: [roomies]), "roomies")
        XCTAssertNil(DropCamera.boardName(UUID().uuidString.lowercased(), remote: [roomies]))
    }
}
