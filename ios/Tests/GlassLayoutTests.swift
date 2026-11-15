import XCTest
@testable import AppDemo

final class GlassLayoutTests: XCTestCase {
    private let size = CGSize(width: 402, height: 778)

    private func item(_ zone: Zone, _ kind: ObjectKind = .postcard, manual: CGPoint? = nil) -> GlassLayout.Item {
        GlassLayout.Item(id: UUID(), zone: zone, kind: kind, manual: manual)
    }

    func testNowIsNearestLowestAndLargest() {
        let items = GlassLayout.rows.map { item($0) }
        let layout = GlassLayout(items: items, size: size)
        let placed = items.compactMap { layout.placements[$0.id] }
        XCTAssertEqual(placed.count, 4)
        for (far, near) in zip(placed, placed.dropFirst()) {
            XCTAssertLessThan(far.center.y, near.center.y)
            XCTAssertLessThan(far.scale, near.scale)
            XCTAssertLessThan(far.nearness, near.nearness)
        }
    }

    func testEveryDropSitsInsideItsZoneAndTheScreen() {
        let items = GlassLayout.rows.flatMap { zone in ObjectKind.allCases.prefix(3).map { item(zone, $0) } }
        let layout = GlassLayout(items: items, size: size)
        for entry in items {
            let placement = try! XCTUnwrap(layout.placements[entry.id])
            XCTAssertEqual(layout.zone(at: placement.center), entry.zone)
            let half = placement.size.width * placement.scale / 2
            XCTAssertGreaterThanOrEqual(placement.center.x - half, 0)
            XCTAssertLessThanOrEqual(placement.center.x + half, size.width)
        }
    }

    func testCrowdedSomedayWrapsUpwardAndShrinks() {
        let items = (0..<8).map { _ in item(.someday, .slip) }
        let layout = GlassLayout(items: items, size: size)
        let placed = items.compactMap { layout.placements[$0.id] }
        XCTAssertEqual(placed.count, 8)
        let first = placed[0]
        let last = placed[7]
        XCTAssertLessThan(last.center.y, first.center.y - 40)
        XCTAssertLessThan(last.scale, first.scale)
        XCTAssertTrue(placed.allSatisfy { layout.zone(at: $0.center) == .someday })
    }

    func testCrowdedRowSqueezesInsteadOfLeavingTheScreen() {
        let items = (0..<6).map { _ in item(.tonight, .postcard) }
        let layout = GlassLayout(items: items, size: size)
        for entry in items {
            let placement = try! XCTUnwrap(layout.placements[entry.id])
            let half = placement.size.width * placement.scale / 2
            XCTAssertGreaterThanOrEqual(placement.center.x - half, GlassLayout.labelColumn - 0.5)
            XCTAssertLessThanOrEqual(placement.center.x + half, size.width)
        }
    }

    func testHandPlacedDropStaysWhereItWasPut() {
        let point = CGPoint(x: 0.5, y: 0.5)
        let moved = item(.tonight, .record, manual: point)
        let layout = GlassLayout(items: [moved, item(.tonight), item(.tonight)], size: size)
        let placement = try! XCTUnwrap(layout.placements[moved.id])
        let band = layout.band(.tonight)
        XCTAssertEqual(placement.center.x, band.midX, accuracy: 0.5)
        XCTAssertEqual(placement.center.y, band.midY, accuracy: 0.5)
        let back = layout.unitPoint(for: placement.center, in: .tonight)
        XCTAssertEqual(back.x, point.x, accuracy: 0.01)
        XCTAssertEqual(back.y, point.y, accuracy: 0.01)
    }

    func testVibesKeepsThreeInViewAndCountsTheRest() {
        let items = (0..<5).map { _ in item(.vibes, .record) }
        let layout = GlassLayout(items: items, size: size)
        XCTAssertEqual(items.filter { layout.placements[$0.id] != nil }.count, 3)
        XCTAssertEqual(layout.hiddenVibes, 2)
        XCTAssertNotNil(layout.placements[items[0].id])
    }

    func testDoneDropsLeaveTheScene() {
        let done = item(.done)
        let layout = GlassLayout(items: [done], size: size)
        XCTAssertNil(layout.placements[done.id])
    }

    func testZoneUnderAPointRunsSomedayToNow() {
        let layout = GlassLayout(items: [], size: size)
        XCTAssertEqual(layout.zone(at: CGPoint(x: 150, y: 10)), .someday)
        XCTAssertEqual(layout.zone(at: CGPoint(x: 150, y: size.height * 0.37)), .thisWeekend)
        XCTAssertEqual(layout.zone(at: CGPoint(x: 150, y: size.height * 0.53)), .tonight)
        XCTAssertEqual(layout.zone(at: CGPoint(x: 300, y: size.height * 0.75)), .now)
        XCTAssertEqual(layout.zone(at: CGPoint(x: size.width * 0.85, y: size.height * 0.3)), .vibes)
        XCTAssertEqual(layout.zone(at: CGPoint(x: 40, y: size.height * 0.96)), .done)
    }

    func testLayoutIsTheSameEveryTime() {
        let items = GlassLayout.rows.map { item($0, .cutout) }
        XCTAssertEqual(GlassLayout(items: items, size: size).placements, GlassLayout(items: items, size: size).placements)
    }
}
