import SwiftData
import XCTest
@testable import AppDemo

@MainActor
final class InboxIngestTests: XCTestCase {
    private var root: URL!
    private var inbox: Inbox!
    private var ingest: InboxIngest!
    private var context: ModelContext!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        inbox = Inbox(root: root.appending(path: "inbox", directoryHint: .isDirectory))
        ingest = InboxIngest(inbox: inbox, container: root, authorId: "me") { _ in "sf-crew" }
        context = ModelContext(BoardStore.makeInMemoryContainer())
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func drops() throws -> [Drop] {
        try context.fetch(FetchDescriptor<Drop>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    func testLinkBecomesAPendingPostcardAndLeavesTheInbox() throws {
        let item = try inbox.write(InboxItem(kind: .url, text: "marufuku ramen", url: "https://example.com/ramen"))

        XCTAssertEqual(ingest.run(in: context), [item.id])

        let drop = try XCTUnwrap(drops().first)
        XCTAssertEqual(drop.id, item.id)
        XCTAssertEqual(drop.sourceKind, .url)
        XCTAssertEqual(drop.url, "https://example.com/ramen")
        XCTAssertEqual(drop.rawText, "marufuku ramen")
        XCTAssertEqual(drop.status, .pending)
        XCTAssertEqual(drop.objectKind, .postcard)
        XCTAssertEqual(drop.authorId, "me")
        XCTAssertEqual(drop.boardId, "sf-crew")
        XCTAssertEqual(inbox.pending(), [])
    }

    func testPhotoFilesMoveToTheMediaFolderWithTheirLocation() throws {
        let item = try inbox.write(
            InboxItem(kind: .image, latitude: 37.77, longitude: -122.42),
            payloads: [.data(Data("pixels".utf8), name: "photo.jpg")]
        )

        ingest.run(in: context)

        let drop = try XCTUnwrap(drops().first)
        XCTAssertEqual(drop.mediaPaths, ["media/\(item.id.uuidString)/photo.jpg"])
        XCTAssertEqual(try Data(contentsOf: root.appending(path: drop.mediaPaths[0])), Data("pixels".utf8))
        XCTAssertEqual(drop.anchorLatitude, 37.77)
        XCTAssertEqual(drop.anchorLongitude, -122.42)
        XCTAssertEqual(drop.objectKind, .cutout)
        XCTAssertFalse(FileManager.default.fileExists(atPath: inbox.folder(for: item.id).path))
    }

    func testAnItemAlreadyOnTheBoardIsClearedWithoutASecondDrop() throws {
        let item = try inbox.write(InboxItem(kind: .text, text: "remind me in 1 hr"))
        ingest.run(in: context)
        try inbox.write(item)

        XCTAssertEqual(ingest.run(in: context), [])

        XCTAssertEqual(try drops().count, 1)
        XCTAssertEqual(inbox.pending(), [])
    }

    func testEveryKindGetsItsDefaultObject() throws {
        for (offset, kind) in SourceKind.allCases.enumerated() {
            try inbox.write(InboxItem(createdAt: Date(timeIntervalSince1970: Double(offset)), kind: kind, text: kind.rawValue))
        }

        ingest.run(in: context)

        XCTAssertEqual(try drops().map(\.objectKind), [.postcard, .cutout, .polaroid, .slip, .sticky, .stub])
    }
}
