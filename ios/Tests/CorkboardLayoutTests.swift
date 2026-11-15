import SwiftData
import XCTest
@testable import AppDemo

@MainActor
final class CorkboardLayoutTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_772_000)
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = ModelContext(BoardStore.makeInMemoryContainer())
    }

    private func drop(_ title: String, in zone: Zone, kind: ObjectKind = .sticky, pinned: Bool = false) -> Drop {
        let drop = Drop(createdAt: now.addingTimeInterval(-600), authorId: "me", boardId: "b", sourceKind: .text)
        drop.title = title
        drop.status = .processed
        drop.objectKind = kind
        drop.applyDecidedZone(zone, unsure: false)
        drop.pinnedAt = pinned ? now : nil
        context.insert(drop)
        return drop
    }

    private func layout(_ drops: [Drop], width: CGFloat = 402) -> CorkboardLayout {
        CorkboardLayout(sections: DropSection.build(drops, filter: .everyone, me: "me", now: now), width: width, minHeight: 874)
    }

    func testARowSharesOneTopAndSitsOnTwoColumns() {
        let board = layout([drop("note", in: .someday), drop("card", in: .someday, kind: .postcard), drop("third", in: .someday)])
        let row = board.items.prefix(2)
        let tops = row.map { $0.center.y - $0.size.height / 2 }
        XCTAssertEqual(tops[0], tops[1], accuracy: 0.001)
        XCTAssertEqual(row.map(\.center.x), [105.5, 296.5])
        XCTAssertEqual(board.items[1].size, CGSize(width: 176, height: 118))
        XCTAssertEqual(board.items[2].center.x, 105.5)
        let nextTop = board.items[2].center.y - board.items[2].size.height / 2
        XCTAssertEqual(nextTop - tops[0], 120 + CorkboardLayout.labelDrop + CorkboardLayout.rowGap, accuracy: 0.001)
    }

    func testTiltsStayBetweenHalfADegreeAndOneAndAHalfAndLeanApart() {
        let board = layout((0..<8).map { drop("note \($0)", in: .now) })
        for item in board.items {
            XCTAssertTrue((0.5...1.5).contains(abs(item.tilt)))
            XCTAssertEqual(item.tilt < 0, item.center.x < 201)
        }
    }

    func testOnlyPinnedDropsGetAPin() {
        let board = layout([drop("dinner", in: .tonight, pinned: true), drop("soup", in: .tonight)])
        XCTAssertEqual(board.headers.map(\.id), ["pinned", "tonight"])
        XCTAssertEqual(board.items.map(\.fastener), [.pin, .tape])
    }

    func testEmptySectionsHaveNoHeaderAndDoneIsTheLastRow() {
        let board = layout([drop("mood", in: .vibes), drop("finished", in: .done), drop("call", in: .now)])
        XCTAssertEqual(board.headers.map(\.id), ["now", "vibes"])
        XCTAssertEqual(board.headers.map(\.count), [1, 1])
        XCTAssertEqual(board.doneCount, 1)
        let pocket = try? XCTUnwrap(board.pocket)
        XCTAssertEqual(pocket?.minX, CorkboardLayout.margin)
        XCTAssertGreaterThan(pocket?.minY ?? 0, board.items.map { $0.center.y + $0.size.height / 2 }.max() ?? .infinity)
    }

    func testAnEmptyBoardOnlyCentersTheNote() {
        let board = layout([])
        XCTAssertTrue(board.headers.isEmpty)
        XCTAssertNil(board.pocket)
        XCTAssertEqual(board.emptyNoteCenter?.x, 201)
    }
}
