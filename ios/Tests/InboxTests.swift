import XCTest
@testable import AppDemo

final class InboxTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testWriteThenReadBack() throws {
        let inbox = Inbox(root: root)
        let item = InboxItem(createdAt: Date(timeIntervalSince1970: 1_794_768_000), kind: .image, text: "ramen", latitude: 37.77, longitude: -122.42)
        let written = try inbox.write(item, payloads: [.data(Data("pixels".utf8), name: "photo.jpg")])

        XCTAssertEqual(written.files, ["photo.jpg"])
        XCTAssertEqual(inbox.pending(), [written])
        XCTAssertEqual(try Data(contentsOf: inbox.fileURL("photo.jpg", in: written)), Data("pixels".utf8))
        let staging = root.appending(path: ".staging", directoryHint: .isDirectory)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: staging.path), [])
    }

    func testPendingIsOldestFirstAndSkipsStaging() throws {
        let inbox = Inbox(root: root)
        let newer = try inbox.write(InboxItem(createdAt: Date(timeIntervalSince1970: 200), kind: .text, text: "b"))
        let older = try inbox.write(InboxItem(createdAt: Date(timeIntervalSince1970: 100), kind: .url, url: "https://example.com"))
        let half = root.appending(path: ".staging/\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: half, withIntermediateDirectories: true)

        XCTAssertEqual(inbox.pending().map(\.id), [older.id, newer.id])
    }

    func testPayloadNamesCannotEscapeTheFolder() throws {
        let inbox = Inbox(root: root)
        let written = try inbox.write(InboxItem(kind: .pdf), payloads: [.data(Data("x".utf8), name: "../../ticket.pdf")])
        XCTAssertEqual(written.files, ["ticket.pdf"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: inbox.fileURL("ticket.pdf", in: written).path))
    }

    func testRemove() throws {
        let inbox = Inbox(root: root)
        let item = try inbox.write(InboxItem(kind: .text, text: "gone soon"))
        try inbox.remove(item.id)
        XCTAssertEqual(inbox.pending(), [])
    }

    func testDropJSONUsesMillisecondDates() throws {
        let inbox = Inbox(root: root)
        let item = try inbox.write(InboxItem(createdAt: Date(timeIntervalSince1970: 1_794_768_000), kind: .text, text: "hi"))
        let json = try String(contentsOf: inbox.folder(for: item.id).appending(path: "drop.json"), encoding: .utf8)
        XCTAssertTrue(json.contains("\"createdAt\" : 1794768000000"))
        XCTAssertTrue(json.contains("\"kind\" : \"text\""))
    }
}
