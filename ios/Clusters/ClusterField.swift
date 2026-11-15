import CoreGraphics
import Foundation

struct ClusterField: Equatable {
    static let spacing: CGFloat = 64
    static let gap: CGFloat = 48

    let size: CGSize
    private(set) var centers: [String: CGPoint] = [:]
    private(set) var radii: [String: CGFloat] = [:]
    private(set) var offsets: [UUID: CGVector] = [:]
    private var home: [UUID: String] = [:]

    init(_ snapshot: ClusterSnapshot, size: CGSize, following previous: ClusterField? = nil) {
        self.size = size
        let groups = snapshot.groups.filter { !$0.members.isEmpty }
        var points: [String: CGPoint] = [:]
        var seeds: [String: CGPoint] = [:]
        for group in groups {
            radii[group.id] = Self.spacing * (0.5 + 0.9 * CGFloat(group.members.count).squareRoot())
            for (index, id) in group.members.enumerated() {
                let angle = Double(index) * 2.399963
                let reach = Self.spacing * 0.9 * CGFloat(Double(index) + 0.5).squareRoot()
                offsets[id] = CGVector(dx: reach * CGFloat(cos(angle)), dy: reach * CGFloat(sin(angle)))
                home[id] = group.id
            }
            let seed = Self.seed(for: group, previous: previous)
            seeds[group.id] = CGPoint(x: seed.x * size.width, y: seed.y * size.height)
            points[group.id] = seeds[group.id]
        }

        let ids = groups.map(\.id)
        let mobility = Dictionary(ids.map { ($0, previous?.centers[$0] == nil ? CGFloat(3) : 1) }, uniquingKeysWith: { first, _ in first })
        for _ in 0..<80 {
            for (i, first) in ids.enumerated() {
                for second in ids[(i + 1)...] {
                    guard let a = points[first], let b = points[second] else { continue }
                    let needed = (radii[first] ?? 0) + (radii[second] ?? 0) + Self.gap
                    var dx = b.x - a.x
                    var dy = b.y - a.y
                    var distance = hypot(dx, dy)
                    if distance < 0.001 {
                        let angle = Self.unit(first + second, salt: 7) * 2 * .pi
                        dx = CGFloat(cos(angle))
                        dy = CGFloat(sin(angle))
                        distance = 1
                    }
                    guard distance < needed else { continue }
                    let overlap = needed - distance
                    let share = (mobility[first] ?? 1) / ((mobility[first] ?? 1) + (mobility[second] ?? 1))
                    points[first] = CGPoint(x: a.x - dx / distance * overlap * share, y: a.y - dy / distance * overlap * share)
                    points[second] = CGPoint(x: b.x + dx / distance * overlap * (1 - share), y: b.y + dy / distance * overlap * (1 - share))
                }
            }
            for id in ids {
                guard let point = points[id], let seed = seeds[id] else { continue }
                let radius = radii[id] ?? 0
                let pulled = CGPoint(x: point.x + (seed.x - point.x) * 0.04, y: point.y + (seed.y - point.y) * 0.04)
                points[id] = CGPoint(
                    x: min(max(pulled.x, radius), max(radius, size.width - radius)),
                    y: min(max(pulled.y, radius), max(radius, size.height - radius))
                )
            }
        }
        for (id, point) in points {
            centers[id] = CGPoint(x: size.width > 0 ? point.x / size.width : 0.5, y: size.height > 0 ? point.y / size.height : 0.5)
        }
    }

    func center(of group: String) -> CGPoint? {
        centers[group].map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }

    func position(of drop: UUID) -> CGPoint? {
        guard let group = home[drop], let center = center(of: group), let offset = offsets[drop] else { return nil }
        return CGPoint(x: center.x + offset.dx, y: center.y + offset.dy)
    }

    private static func seed(for group: ClusterSnapshot.Group, previous: ClusterField?) -> CGPoint {
        if let previous {
            if let center = previous.centers[group.id] { return center }
            var counts: [String: Int] = [:]
            for id in group.members {
                if let old = previous.home[id] { counts[old, default: 0] += 1 }
            }
            if let parent = counts.max(by: { ($0.value, $1.key) < ($1.value, $0.key) })?.key, let center = previous.centers[parent] {
                let angle = unit(group.id, salt: 3) * 2 * .pi
                return CGPoint(x: center.x + 0.12 * CGFloat(cos(angle)), y: center.y + 0.12 * CGFloat(sin(angle)))
            }
        }
        return CGPoint(x: 0.15 + 0.7 * unit(group.id, salt: 1), y: 0.15 + 0.7 * unit(group.id, salt: 2))
    }

    private static func unit(_ text: String, salt: UInt64) -> CGFloat {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325 ^ salt
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
        return CGFloat(hash % 10_000) / 10_000
    }
}
