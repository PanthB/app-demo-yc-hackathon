import CoreGraphics
import Foundation

struct ClusterLayout {
    enum Shelf {
        case pinned, cluster, loose, done
    }

    struct Member {
        let id: UUID
        let size: CGSize
        let faceHeight: CGFloat
    }

    struct Group {
        let id: String
        let label: String
        let shelf: Shelf
        let members: [Member]
    }

    struct Spot {
        let group: String
        let shelf: Shelf
        let center: CGPoint
        let size: CGSize
        let faceHeight: CGFloat
        let tilt: Double
        let order: Int

        var frame: CGRect {
            CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
        }

        var faceCenter: CGPoint {
            CGPoint(x: center.x, y: frame.minY + faceHeight / 2)
        }
    }

    struct Label: Identifiable {
        let id: String
        let text: String
        let origin: CGPoint
        let tilt: Double
        let order: Int
    }

    struct Link: Identifiable {
        let id: String
        let first: UUID
        let second: UUID
        let reason: String
        let from: CGPoint
        let control: CGPoint
        let to: CGPoint
        let anchor: CGPoint

        func point(at t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(
                x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
                y: u * u * from.y + 2 * u * t * control.y + t * t * to.y
            )
        }
    }

    static let margin: CGFloat = 16
    static let top: CGFloat = 16
    static let labelHeight: CGFloat = 44
    static let labelGap: CGFloat = 20
    static let columnGap: CGFloat = 20
    static let rowGap: CGFloat = 26
    static let stagger: CGFloat = 8
    static let groupGap: CGFloat = 72
    static let maxTilt = 1.4

    private(set) var spots: [UUID: Spot] = [:]
    private(set) var labels: [Label] = []
    private(set) var order: [UUID] = []
    private(set) var height: CGFloat = 0

    init(groups: [Group], width: CGFloat) {
        var y = Self.top
        var placed = 0
        for group in groups where !group.members.isEmpty {
            let labelTop = y
            y += Self.labelHeight + Self.labelGap
            let rows = group.shelf == .cluster
                ? Self.packRows(group.members, width: width - 2 * Self.margin)
                : Self.flowRows(group.members, width: width - 2 * Self.margin)
            var leading = width
            for (rowIndex, row) in rows.enumerated() {
                let tallest = row.map(\.size.height).max() ?? 0
                let rowHeight = tallest + (row.count > 1 ? Self.stagger * 2 : 0)
                let total = row.map(\.size.width).reduce(0, +) + Self.columnGap * CGFloat(row.count - 1)
                var x = (width - total) / 2
                leading = min(leading, x)
                for (index, member) in row.enumerated() {
                    let side: CGFloat = row.count > 1 ? ((rowIndex + index) % 2 == 0 ? -1 : 1) : 0
                    var random = StableRandom(member.id, salt: 97)
                    let lean = random.value(in: 0.5...Self.maxTilt)
                    let tilt = side == 0 ? (random.value(in: 0...1) < 0.5 ? -lean : lean) : Double(side) * lean
                    spots[member.id] = Spot(
                        group: group.id,
                        shelf: group.shelf,
                        center: CGPoint(x: x + member.size.width / 2, y: y + rowHeight / 2 + side * Self.stagger),
                        size: member.size,
                        faceHeight: member.faceHeight,
                        tilt: tilt,
                        order: placed
                    )
                    order.append(member.id)
                    placed += 1
                    x += member.size.width + Self.columnGap
                }
                y += rowHeight + Self.rowGap
            }
            y -= Self.rowGap
            labels.append(Label(
                id: group.id,
                text: group.label,
                origin: CGPoint(x: max(Self.margin, leading - 4), y: labelTop),
                tilt: Self.labelTilt(group.id),
                order: labels.count
            ))
            y += Self.groupGap
        }
        height = max(y - Self.groupGap + 32, 0)
    }

    static func packRows(_ members: [Member], width: CGFloat) -> [[Member]] {
        guard let core = members.first else { return [] }
        let odd = members.count % 2 == 1
        var rest = odd ? Array(members.dropFirst()) : members
        let rowCount = members.count / 2 + (odd ? 1 : 0)
        let singleRow = odd ? rowCount / 2 : -1
        var rows: [[Member]] = []
        for row in 0..<rowCount {
            if row == singleRow {
                rows.append([core])
                continue
            }
            let pair = Array(rest.prefix(2))
            rest.removeFirst(pair.count)
            if pair.count == 2, pair[0].size.width + pair[1].size.width + columnGap > width {
                rows.append([pair[0]])
                rows.append([pair[1]])
            } else {
                rows.append(pair)
            }
        }
        return rows
    }

    static func flowRows(_ members: [Member], width: CGFloat) -> [[Member]] {
        var rows: [[Member]] = []
        var row: [Member] = []
        var used: CGFloat = 0
        for member in members {
            let needed = row.isEmpty ? member.size.width : used + columnGap + member.size.width
            if !row.isEmpty, needed > width {
                rows.append(row)
                row = [member]
                used = member.size.width
            } else {
                row.append(member)
                used = needed
            }
        }
        if !row.isEmpty { rows.append(row) }
        return rows
    }

    static func links(
        order: [UUID],
        spots: [UUID: Spot],
        neighbors: [UUID: [ClusterFacts.Neighbor]]
    ) -> [Link] {
        var counts: [UUID: Int] = [:]
        var pairs = Set<String>()
        var bridges = Set<String>()
        var result: [Link] = []
        let obstacles = spots.values.map { $0.frame.insetBy(dx: -4, dy: -4) }
        for rank in 0..<2 {
            for id in order {
                guard let spot = spots[id], spot.shelf == .cluster,
                      let list = neighbors[id], rank < list.count,
                      let other = UUID(uuidString: list[rank].clientId), other != id,
                      let partner = spots[other], partner.shelf == .cluster
                else { continue }
                let key = [id.uuidString, other.uuidString].sorted().joined(separator: "|")
                guard !pairs.contains(key), counts[id, default: 0] < 2, counts[other, default: 0] < 2 else { continue }
                if spot.group != partner.group {
                    let bridge = [spot.group, partner.group].sorted().joined(separator: "|")
                    guard !bridges.contains(bridge) else { continue }
                    bridges.insert(bridge)
                }
                pairs.insert(key)
                counts[id, default: 0] += 1
                counts[other, default: 0] += 1
                result.append(link(key: key, first: id, second: other, reason: list[rank].reason, from: spot.faceCenter, to: partner.faceCenter, obstacles: obstacles))
            }
        }
        return result
    }

    private static func link(key: String, first: UUID, second: UUID, reason: String, from: CGPoint, to: CGPoint, obstacles: [CGRect]) -> Link {
        let distance = hypot(to.x - from.x, to.y - from.y)
        let control = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 + distance * 0.12 + 4)
        let draft = Link(id: key, first: first, second: second, reason: reason, from: from, control: control, to: to, anchor: .zero)
        let samples = 48
        var bestStart = -1
        var bestLength = 0
        var runStart = -1
        for step in 0...samples {
            let point = draft.point(at: CGFloat(step) / CGFloat(samples))
            let open = !obstacles.contains { $0.contains(point) }
            if open, runStart < 0 { runStart = step }
            if (!open || step == samples), runStart >= 0 {
                let end = open ? step : step - 1
                if end - runStart + 1 > bestLength {
                    bestLength = end - runStart + 1
                    bestStart = runStart
                }
                runStart = -1
            }
        }
        let middle = bestStart >= 0 ? CGFloat(bestStart) + CGFloat(bestLength - 1) / 2 : CGFloat(samples) / 2
        return Link(id: key, first: first, second: second, reason: reason, from: from, control: control, to: to, anchor: draft.point(at: middle / CGFloat(samples)))
    }

    private static func labelTilt(_ id: String) -> Double {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in id.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return Double(hash % 21) / 10 - 1
    }
}
