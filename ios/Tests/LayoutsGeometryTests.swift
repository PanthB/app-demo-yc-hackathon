import XCTest
@testable import AppDemo

final class LayoutsGeometryTests: XCTestCase {
    private func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012X", number)) ?? UUID()
    }

    func testTheFirstMemberSitsAtTheHeartAndTheRestRingIt() {
        let members = (1...7).map(id)
        let geometry = ConstellationGeometry(groups: [.init(id: "a", label: "a", members: members)], links: [], width: 400)
        let cluster = try! XCTUnwrap(geometry.clusters.first)
        XCTAssertEqual(geometry.points[id(1)], cluster.center)
        for number in 2...7 {
            let point = try! XCTUnwrap(geometry.points[id(number)])
            XCTAssertEqual(hypot(point.x - cluster.center.x, point.y - cluster.center.y), ConstellationGeometry.ringStep, accuracy: 0.01)
        }
    }

    func testLinkedMembersSitNextToEachOther() {
        let members = [id(1), id(2), id(3), id(4)]
        let links = [LayoutLink(first: id(1), second: id(4), reason: "both late night.")]
        XCTAssertEqual(ConstellationGeometry.arrange(members, links: links), [id(1), id(4), id(2), id(3)])
    }

    func testGroupsNeverOverlapAndTheLayoutRepeats() {
        let groups = (0..<4).map { group in
            ConstellationGeometry.Group(id: "g\(group)", label: "g\(group)", members: (1...(3 + group)).map { id(group * 10 + $0) })
        }
        let first = ConstellationGeometry(groups: groups, links: [], width: 402)
        let second = ConstellationGeometry(groups: groups, links: [], width: 402)
        XCTAssertEqual(first.points, second.points)
        for (index, a) in first.clusters.enumerated() {
            for b in first.clusters[(index + 1)...] {
                XCTAssertGreaterThanOrEqual(hypot(a.center.x - b.center.x, a.center.y - b.center.y), a.radius + b.radius, "\(a.id) and \(b.id)")
            }
        }
        XCTAssertEqual(first.clusters.map(\.id), ["g0", "g1", "g2", "g3"])
        XCTAssertTrue(zip(first.clusters, first.clusters.dropFirst()).allSatisfy { $0.center.y < $1.center.y })
    }

    func testOrbitKeepsItsOrderAndSpacesCrowdedDrops() {
        let spread = OrbitGeometry.spread([0.10, 0.11, 0.12, 2.0], gap: 0.3)
        XCTAssertEqual(spread.sorted(), spread)
        for (a, b) in zip(spread, spread.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b - a, 0.3 - 0.0001)
        }
        XCTAssertEqual(spread[3], 2.0, accuracy: 0.31)
    }

    func testOrbitPutsMidnightAtTheTopAndNoonAtTheBottom() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let midnight = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 0))!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12))!
        XCTAssertEqual(OrbitGeometry.clock(midnight, calendar: calendar), -Double.pi / 2, accuracy: 0.0001)
        XCTAssertEqual(OrbitGeometry.clock(noon, calendar: calendar), Double.pi / 2, accuracy: 0.0001)
    }

    func testASongSitsByTheFirstPlaceItGoesWith() {
        let now = Date(timeIntervalSince1970: 1_794_772_000)
        let anchors = MapAnchors([
            .init(id: id(1), hasPlace: true, cluster: "sunny", createdAt: now, neighbors: []),
            .init(id: id(2), hasPlace: false, cluster: "sunny", createdAt: now, neighbors: [(id(1), "both upbeat.")]),
            .init(id: id(3), hasPlace: true, cluster: "late", createdAt: now, neighbors: []),
            .init(id: id(4), hasPlace: false, cluster: "late", createdAt: now, neighbors: [(id(5), "both dreamy.")]),
            .init(id: id(5), hasPlace: false, cluster: nil, createdAt: now, neighbors: []),
            .init(id: id(6), hasPlace: false, cluster: nil, createdAt: now, neighbors: []),
        ], clusterLabels: ["late": "late night"])
        XCTAssertEqual(anchors.satellites[id(1)], [id(2)])
        XCTAssertEqual(anchors.reasons[id(2)], "both upbeat.")
        XCTAssertEqual(anchors.satellites[id(3)], [id(4)])
        XCTAssertEqual(anchors.reasons[id(4)], "same vibe, late night.")
        XCTAssertEqual(anchors.loose, [id(5), id(6)])
    }
}
