import SwiftData
import XCTest
@testable import AppDemo

@MainActor
final class NightGroupMenuTests: XCTestCase {
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        context = ModelContext(BoardStore.makeInMemoryContainer())
    }

    private func drop(_ vibes: [String], in cluster: String?, label: String? = nil, board: String = "b", minutesAgo: Double = 10) -> Drop {
        let drop = Drop(createdAt: Date(timeIntervalSince1970: 1_794_772_000 - minutesAgo * 60), authorId: "me", boardId: board, sourceKind: .text)
        drop.status = .processed
        drop.vibes = vibes
        drop.clusterId = cluster
        drop.clusterLabel = label
        context.insert(drop)
        return drop
    }

    func testListsOtherGroupsByLabelWithTheirMostCommonKind() {
        let mine = drop(["food spots", "cozy"], in: "a", label: "food spots, cozy")
        let all = [
            mine,
            drop(["food spots", "cozy"], in: "a", label: "food spots, cozy"),
            drop(["pottery classes", "calm"], in: "c", label: "pottery classes, calm", minutesAgo: 5),
            drop(["pottery classes"], in: "c", label: "pottery classes, calm"),
            drop(["calm"], in: "c", label: "pottery classes, calm"),
            drop(["sad songs", "late night"], in: "s", label: "sad songs, late night"),
            drop(["beaches"], in: "x", label: "beaches", board: "other"),
        ]
        XCTAssertEqual(DropGroups.choices(for: mine, among: all), [
            DropGroupChoice(id: "c", label: "pottery classes, calm", kind: "pottery classes"),
            DropGroupChoice(id: "s", label: "sad songs, late night", kind: "sad songs"),
        ])
    }

    func testSkipsGroupsWithTheDropsOwnKindOrNoKind() {
        let mine = drop(["sad songs", "moody"], in: "a")
        let all = [
            mine,
            drop(["sad songs", "morning"], in: "b", label: "sad songs, morning"),
            drop(["calm", "outdoors"], in: "c", label: "calm, outdoors"),
        ]
        XCTAssertEqual(DropGroups.choices(for: mine, among: all), [])
    }

    func testNewGroupNamesAreLowercaseAndUpToThreeWords() {
        XCTAssertEqual(DropGroups.name("  Ceramics   Classes "), "ceramics classes")
        XCTAssertEqual(DropGroups.name("r&b nights!"), "r&b nights")
        XCTAssertNil(DropGroups.name("one two three four"))
        XCTAssertNil(DropGroups.name("   "))
        XCTAssertNil(DropGroups.name("supercalifragilistic expialidocious"))
        XCTAssertNil(DropGroups.name("Late Night"))
        XCTAssertNil(DropGroups.name("cozy"))
    }
}
