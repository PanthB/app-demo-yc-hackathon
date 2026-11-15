import SwiftData
import XCTest
@testable import AppDemo

@MainActor
final class DropSectionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_772_000)
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = ModelContext(BoardStore.makeInMemoryContainer())
    }

    private func drop(_ title: String, by author: String = "me", in zone: Zone, minutesAgo: Double = 10, pinnedMinutesAgo: Double? = nil) -> Drop {
        let drop = Drop(createdAt: now.addingTimeInterval(-minutesAgo * 60), authorId: author, boardId: "b", sourceKind: .text)
        drop.title = title
        drop.status = .processed
        drop.applyDecidedZone(zone, unsure: false)
        drop.pinnedAt = pinnedMinutesAgo.map { now.addingTimeInterval(-$0 * 60) }
        context.insert(drop)
        return drop
    }

    private func outline(_ sections: [DropSection]) -> [String] {
        sections.map { "\($0.id): \($0.drops.compactMap(\.title).joined(separator: ", "))" }
    }

    func testPinnedComeFirstNewestPinFirstAndLeaveTheirSections() {
        let drops = [
            drop("soup", in: .tonight),
            drop("record", in: .vibes, pinnedMinutesAgo: 60),
            drop("dinner", in: .thisWeekend, pinnedMinutesAgo: 5),
            drop("books", in: .someday),
        ]
        XCTAssertEqual(outline(DropSection.build(drops, filter: .everyone, me: "me", now: now)), [
            "pinned: dinner, record",
            "tonight: soup",
            "someday: books",
        ])
    }

    func testSectionsKeepTheirOrderAndDoneStaysLast() {
        let drops = [
            drop("finished", in: .done, pinnedMinutesAgo: 1),
            drop("mood", in: .vibes),
            drop("later", in: .someday),
            drop("call", in: .now),
        ]
        let sections = DropSection.build(drops, filter: .everyone, me: "me", now: now)
        XCTAssertEqual(outline(sections), ["now: call", "someday: later", "vibes: mood", "done: finished"])
        XCTAssertEqual(sections.map(\.style), [.zone, .zone, .zone, .done])
    }

    func testMineKeepsOnlyMyDrops() {
        let drops = [
            drop("mine", in: .now),
            drop("maya's", by: "maya", in: .now),
            drop("maya's pin", by: "maya", in: .someday, pinnedMinutesAgo: 1),
        ]
        XCTAssertEqual(outline(DropSection.build(drops, filter: .mine, me: "me", now: now)), ["now: mine"])
        XCTAssertEqual(outline(DropSection.build(drops, filter: .everyone, me: "me", now: now)), ["pinned: maya's pin", "now: mine, maya's"])
    }

    func testAnArrivingDropLeadsNow() {
        let settled = drop("call", in: .now)
        let arriving = Drop(createdAt: now, authorId: "me", sourceKind: .url, url: "https://example.com")
        context.insert(arriving)
        let sections = DropSection.build([settled, arriving], filter: .everyone, me: "me", now: now)
        XCTAssertEqual(sections.map(\.id), ["now"])
        XCTAssertEqual(sections.first?.drops.map(\.id), [arriving.id, settled.id])
    }

    private func clustered(_ title: String, _ cluster: String, minutesAgo: Double, pinnedMinutesAgo: Double? = nil) -> Drop {
        let drop = drop(title, in: .vibes, minutesAgo: minutesAgo, pinnedMinutesAgo: pinnedMinutesAgo)
        drop.clusterId = cluster
        drop.clusterLabel = "\(cluster) label"
        return drop
    }

    func testByVibeGroupsClustersBiggestFirstThenTheRestThenDone() {
        let drops = [
            clustered("dreams", "night", minutesAgo: 30),
            clustered("ramen", "night", minutesAgo: 5),
            clustered("dolores", "sunny", minutesAgo: 1),
            clustered("lands end", "water", minutesAgo: 50, pinnedMinutesAgo: 2),
            drop("reminder", in: .now),
            drop("finished", in: .done),
        ]
        let sections = DropSection.build(drops, grouping: .vibe, filter: .everyone, me: "me", now: now)
        XCTAssertEqual(outline(sections), [
            "pinned: lands end",
            "cluster-night: ramen, dreams",
            "cluster-sunny: dolores",
            "loose: reminder",
            "done: finished",
        ])
        XCTAssertEqual(sections.map(\.title), ["pinned", "night label", "sunny label", "everything else", "done"])
    }

    func testByVibeBreaksSizeTiesByTheNewestMember() {
        let drops = [
            clustered("old", "a", minutesAgo: 90),
            clustered("new", "b", minutesAgo: 3),
        ]
        XCTAssertEqual(DropSection.build(drops, grouping: .vibe, filter: .everyone, me: "me", now: now).map(\.id), ["cluster-b", "cluster-a"])
    }

    func testPinningKeepsTheZoneSoUnpinningGoesBack() {
        let dinner = drop("dinner", in: .thisWeekend)
        dinner.setPinned(true)
        XCTAssertEqual(outline(DropSection.build([dinner], filter: .everyone, me: "me", now: now)), ["pinned: dinner"])
        dinner.setPinned(false)
        XCTAssertEqual(outline(DropSection.build([dinner], filter: .everyone, me: "me", now: now)), ["thisWeekend: dinner"])
    }
}
