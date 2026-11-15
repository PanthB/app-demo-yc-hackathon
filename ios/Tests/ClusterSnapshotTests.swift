import SwiftData
import XCTest
@testable import AppDemo

@MainActor
final class ClusterSnapshotTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_794_772_000)
    private var context: ModelContext!
    private var drops: [Int: Drop] = [:]

    override func setUp() {
        super.setUp()
        context = ModelContext(BoardStore.makeInMemoryContainer())
        drops = [:]
    }

    private func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012X", number)) ?? UUID()
    }

    @discardableResult
    private func drop(_ number: Int, in cluster: String, _ label: String, neighbors: [Int] = []) -> Drop {
        let drop = drops[number] ?? Drop(id: id(number), createdAt: now.addingTimeInterval(Double(number) * 60), authorId: "me", boardId: "b", sourceKind: .url)
        if drops[number] == nil {
            drop.status = .processed
            drop.applyDecidedZone(.vibes, unsure: false)
            context.insert(drop)
            drops[number] = drop
        }
        drop.clusterId = cluster
        drop.clusterLabel = label
        drop.neighbors = neighbors.map { DropNeighbor(clientId: id($0).uuidString, reason: "both close.") }
        return drop
    }

    private var board: [Drop] {
        drops.keys.sorted().compactMap { drops[$0] }
    }

    private func outline(_ snapshot: ClusterSnapshot) -> [String] {
        snapshot.groups.map { group in
            let numbers = group.members.compactMap { member in drops.first { $0.value.id == member }?.key }.sorted()
            return "\(group.id) (\(group.label)): \(numbers.map(String.init).joined(separator: ","))"
        }
    }

    func testAGrowingClusterKeepsItsIdAndReportsTheNewLabel() {
        drop(1, in: "a", "late night")
        drop(2, in: "a", "late night")
        let before = ClusterSnapshot(drops: board)
        drop(1, in: "a", "late night, dreamy")
        drop(2, in: "a", "late night, dreamy")
        drop(3, in: "a", "late night, dreamy")
        let after = ClusterSnapshot(drops: board, following: before)

        XCTAssertEqual(outline(after), ["cluster-a (late night, dreamy): 1,2,3"])
        XCTAssertEqual(after.changes(since: before), [
            .relabeled(group: "cluster-a", from: "late night", to: "late night, dreamy"),
            .arrived(drop: id(3), into: "cluster-a"),
        ])
    }

    func testAMergeKeepsTheSurvivorAndReportsWhereTheOthersWent() {
        for number in 1...3 { drop(number, in: "a", "upbeat") }
        for number in 4...5 { drop(number, in: "b", "morning") }
        let before = ClusterSnapshot(drops: board)
        for number in 4...5 { drop(number, in: "a", "upbeat") }
        let after = ClusterSnapshot(drops: board, following: before)

        XCTAssertEqual(outline(after), ["cluster-a (upbeat): 1,2,3,4,5"])
        XCTAssertEqual(after.changes(since: before), [
            .merged(from: "cluster-b", into: "cluster-a"),
            .moved(drop: id(4), from: "cluster-b", to: "cluster-a"),
            .moved(drop: id(5), from: "cluster-b", to: "cluster-a"),
        ])
    }

    func testASplitKeepsTheParentAndNamesTheNewGroup() {
        for number in 1...4 { drop(number, in: "a", "upbeat") }
        let before = ClusterSnapshot(drops: board)
        for number in 3...4 { drop(number, in: "c", "late night, food") }
        let after = ClusterSnapshot(drops: board, following: before)

        XCTAssertEqual(outline(after), ["cluster-a (upbeat): 1,2", "cluster-c (late night, food): 3,4"])
        XCTAssertEqual(after.changes(since: before), [
            .split(from: "cluster-a", into: "cluster-c"),
            .moved(drop: id(3), from: "cluster-a", to: "cluster-c"),
            .moved(drop: id(4), from: "cluster-a", to: "cluster-c"),
        ])
    }

    func testAClusterTheBackendRenamesKeepsItsIdAcrossLaterSnapshots() {
        for number in 1...3 { drop(number, in: "a", "golden hour") }
        let first = ClusterSnapshot(drops: board)
        for number in 1...3 { drop(number, in: "z", "golden hour") }
        let second = ClusterSnapshot(drops: board, following: first)
        drop(4, in: "z", "golden hour")
        let third = ClusterSnapshot(drops: board, following: second)

        XCTAssertEqual(outline(second), ["cluster-a (golden hour): 1,2,3"])
        XCTAssertEqual(second.changes(since: first), [])
        XCTAssertEqual(outline(third), ["cluster-a (golden hour): 1,2,3,4"])
        XCTAssertEqual(third.changes(since: second), [.arrived(drop: id(4), into: "cluster-a")])
    }

    func testStringsStayWithinTheirLimits() {
        drop(1, in: "a", "upbeat", neighbors: [2, 3])
        drop(2, in: "a", "upbeat", neighbors: [1, 3])
        drop(3, in: "a", "upbeat", neighbors: [1, 2])
        drop(4, in: "b", "calm", neighbors: [1, 2])
        drop(5, in: "b", "calm", neighbors: [2, 4])
        let snapshot = ClusterSnapshot(drops: board)

        var counts: [UUID: Int] = [:]
        for pair in snapshot.pairs {
            counts[pair.first, default: 0] += 1
            counts[pair.second, default: 0] += 1
        }
        XCTAssertLessThanOrEqual(counts.values.max() ?? 0, 2)
        let bridges = snapshot.pairs.filter { snapshot.group(of: $0.first)?.id != snapshot.group(of: $0.second)?.id }
        XCTAssertEqual(bridges.count, 1)
    }

    func testMovesAreStaggeredOneAfterAnother() {
        let delays = ClusterMotion.delays(for: [
            .merged(from: "cluster-b", into: "cluster-a"),
            .moved(drop: id(4), from: "cluster-b", to: "cluster-a"),
            .moved(drop: id(5), from: "cluster-b", to: "cluster-a"),
            .arrived(drop: id(6), into: "cluster-a"),
        ])
        XCTAssertEqual(delays[id(4)], 0)
        XCTAssertEqual(delays[id(5)], ClusterMotion.step)
        XCTAssertNil(delays[id(6)])
    }

    func testTheFieldDriftsALittleWhenAGroupForms() {
        let size = CGSize(width: 1200, height: 1200)
        for number in 1...4 { drop(number, in: "a", "upbeat") }
        for number in 5...7 { drop(number, in: "b", "late night") }
        let before = ClusterSnapshot(drops: board)
        let fieldBefore = ClusterField(before, size: size)
        for number in 8...9 { drop(number, in: "c", "golden hour") }
        let after = ClusterSnapshot(drops: board, following: before)
        let fieldAfter = ClusterField(after, size: size, following: fieldBefore)

        for group in ["cluster-a", "cluster-b"] {
            let old = try! XCTUnwrap(fieldBefore.center(of: group))
            let new = try! XCTUnwrap(fieldAfter.center(of: group))
            XCTAssertLessThan(hypot(new.x - old.x, new.y - old.y), 160, group)
        }
        let groups = after.groups.map(\.id)
        for (index, first) in groups.enumerated() {
            for second in groups[(index + 1)...] {
                let a = try! XCTUnwrap(fieldAfter.center(of: first))
                let b = try! XCTUnwrap(fieldAfter.center(of: second))
                let needed = (fieldAfter.radii[first] ?? 0) + (fieldAfter.radii[second] ?? 0)
                XCTAssertGreaterThanOrEqual(hypot(b.x - a.x, b.y - a.y), needed, "\(first) and \(second) overlap")
            }
        }
        XCTAssertEqual(ClusterField(after, size: size, following: fieldBefore), fieldAfter)
        XCTAssertNotNil(fieldAfter.position(of: id(9)))
    }
}
