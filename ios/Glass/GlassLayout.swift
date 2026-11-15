import Foundation

struct GlassLayout {
    struct Item {
        var id: UUID
        var zone: Zone
        var kind: ObjectKind
        var manual: CGPoint?
    }

    struct Placement: Equatable {
        var center: CGPoint
        var size: CGSize
        var scale: CGFloat
        var tilt: Double
        var nearness: CGFloat
    }

    static let rows: [Zone] = [.someday, .thisWeekend, .tonight, .now]
    static let vibesShown = 3
    static let somedayRows = 3
    static let labelColumn: CGFloat = 112
    static let edge: CGFloat = 16
    static let chipOverhang: CGFloat = 14

    let size: CGSize
    private(set) var placements: [UUID: Placement] = [:]
    private(set) var hiddenVibes = 0

    init(items: [Item], size: CGSize) {
        self.size = size
        for zone in Self.rows {
            placeZone(zone, items: items.filter { $0.zone == zone && $0.manual == nil })
        }
        placeVibes(items.filter { $0.zone == .vibes && $0.manual == nil })
        for item in items where item.manual != nil && item.zone != .done {
            placeManual(item)
        }
    }

    static func nearness(_ zone: Zone) -> CGFloat {
        switch zone {
        case .now: 1
        case .tonight: 0.72
        case .thisWeekend: 0.48
        case .someday: 0.25
        case .vibes: 0.45
        case .done: 0.15
        }
    }

    static func scale(nearness: CGFloat) -> CGFloat {
        0.5 + 0.65 * nearness
    }

    static func baseSize(for kind: ObjectKind) -> CGSize {
        switch kind {
        case .cutout: CGSize(width: 128, height: 128)
        case .polaroid: CGSize(width: 104, height: 124)
        case .record: CGSize(width: 120, height: 120)
        case .slip: CGSize(width: 168, height: 64)
        case .sticky: CGSize(width: 120, height: 120)
        case .stub: CGSize(width: 160, height: 76)
        case .postcard: CGSize(width: 160, height: 108)
        }
    }

    static func unit(_ id: UUID, salt: UInt64) -> CGFloat {
        var hash: UInt64 = 14_695_981_039_346_656_037 ^ (salt &* 0x9E37_79B9_7F4A_7C15)
        withUnsafeBytes(of: id.uuid) { bytes in
            for byte in bytes {
                hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
            }
        }
        hash ^= hash >> 29
        return CGFloat(hash >> 11) / 9_007_199_254_740_992
    }

    static func tilt(for id: UUID) -> Double {
        Double(unit(id, salt: 3) - 0.5) * 7
    }

    func band(_ zone: Zone) -> CGRect {
        let w = size.width
        let h = size.height
        switch zone {
        case .someday: return CGRect(x: 0, y: 0, width: w, height: h * 0.305)
        case .thisWeekend: return CGRect(x: 0, y: h * 0.305, width: w, height: h * 0.145)
        case .tonight: return CGRect(x: 0, y: h * 0.45, width: w, height: h * 0.17)
        case .now: return CGRect(x: 0, y: h * 0.62, width: w, height: h * 0.25)
        case .vibes: return CGRect(x: w * 0.7, y: h * 0.195, width: w * 0.3, height: h * 0.2)
        case .done: return CGRect(x: 0, y: h * 0.9, width: w * 0.42, height: h * 0.1)
        }
    }

    func rowCenter(_ zone: Zone) -> CGFloat {
        switch zone {
        case .someday: size.height * 0.215
        case .thisWeekend: size.height * 0.375
        case .tonight: size.height * 0.54
        case .now: size.height * 0.745
        case .vibes: band(.vibes).midY
        case .done: band(.done).midY
        }
    }

    func labelPoint(_ zone: Zone) -> CGPoint {
        switch zone {
        case .now: CGPoint(x: 20, y: band(.now).minY + 4)
        case .vibes: CGPoint(x: band(.vibes).midX, y: band(.vibes).maxY + 4)
        default: CGPoint(x: 20, y: rowCenter(zone))
        }
    }

    func zone(at point: CGPoint) -> Zone {
        if band(.vibes).contains(point) { return .vibes }
        if band(.done).contains(point) { return .done }
        for zone in Self.rows where point.y < band(zone).maxY {
            return zone
        }
        return .now
    }

    func unitPoint(for point: CGPoint, in zone: Zone) -> CGPoint {
        let rect = band(zone)
        guard rect.width > 0, rect.height > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(
            x: min(max((point.x - rect.minX) / rect.width, 0), 1),
            y: min(max((point.y - rect.minY) / rect.height, 0), 1)
        )
    }

    private func extent(_ zone: Zone) -> ClosedRange<CGFloat> {
        let right = size.width - Self.edge - Self.chipOverhang
        switch zone {
        case .now: return Self.edge...max(right, Self.edge)
        case .tonight: return Self.labelColumn...max(right, Self.labelColumn)
        case .thisWeekend: return Self.labelColumn...max(size.width * 0.68, Self.labelColumn)
        default: return Self.labelColumn...max(size.width * 0.72, Self.labelColumn)
        }
    }

    private mutating func placeZone(_ zone: Zone, items: [Item]) {
        guard !items.isEmpty else { return }
        let nearness = Self.nearness(zone)
        let scale = Self.scale(nearness: nearness)
        guard zone == .someday else {
            placeRow(items, y: rowCenter(zone), scale: scale, range: extent(zone), nearness: nearness)
            return
        }
        var remaining = items[...]
        var rowScale = scale
        for row in 0..<Self.somedayRows where !remaining.isEmpty {
            let wide = Self.labelColumn...max(size.width - Self.edge, Self.labelColumn)
            let range = row == 0 ? extent(.someday) : wide
            let available = range.upperBound - range.lowerBound
            let isLast = row == Self.somedayRows - 1
            var taken: [Item] = []
            var used: CGFloat = 0
            while let next = remaining.first {
                let width = Self.baseSize(for: next.kind).width * rowScale
                let needed = taken.isEmpty ? width : used + 10 * rowScale + width
                if !isLast, !taken.isEmpty, needed > available { break }
                taken.append(next)
                used = needed
                remaining = remaining.dropFirst()
            }
            let y = rowCenter(.someday) - CGFloat(row) * size.height * 0.085
            placeRow(taken, y: y, scale: rowScale, range: range, nearness: nearness)
            rowScale *= 0.9
        }
    }

    private mutating func placeRow(
        _ items: [Item],
        y: CGFloat,
        scale fullScale: CGFloat,
        range: ClosedRange<CGFloat>,
        nearness: CGFloat
    ) {
        guard !items.isEmpty else { return }
        var scale = fullScale
        let available = range.upperBound - range.lowerBound
        let total = items.reduce(CGFloat(0)) { $0 + Self.baseSize(for: $1.kind).width }
        let spaces = CGFloat(items.count - 1)
        var gap = 14 * scale
        if total * scale + gap * spaces > available {
            if spaces > 0 {
                let deepestOverlap = -0.3 * scale * total / CGFloat(items.count)
                gap = max((available - total * scale) / spaces, deepestOverlap)
            }
            let squeezed = total * scale + gap * spaces
            if squeezed > available, squeezed > 0 {
                let shrink = available / squeezed
                scale *= shrink
                gap *= shrink
            }
        }
        let slack = max(available - total * scale - gap * spaces, 0)
        var x = range.lowerBound + slack * (0.25 + 0.5 * Self.unit(items[0].id, salt: 1))
        for (index, item) in items.enumerated() {
            let base = Self.baseSize(for: item.kind)
            let stagger: CGFloat = items.count == 1 ? 0 : (index % 2 == 0 ? -7 : 7) * scale
            let jitter = (Self.unit(item.id, salt: 2) - 0.5) * 8
            placements[item.id] = Placement(
                center: CGPoint(x: x + base.width * scale / 2, y: y + stagger + jitter),
                size: base,
                scale: scale,
                tilt: Self.tilt(for: item.id),
                nearness: nearness
            )
            x += base.width * scale + gap
        }
    }

    private mutating func placeVibes(_ items: [Item]) {
        let shown = Array(items.prefix(Self.vibesShown))
        hiddenVibes = items.count - shown.count
        let nearness = Self.nearness(.vibes)
        let scale = Self.scale(nearness: nearness) * (shown.count > 1 ? 0.8 : 1)
        let rect = band(.vibes)
        let anchor = CGPoint(x: rect.midX, y: rect.midY - rect.height * 0.06)
        let fan: [CGPoint] = [.zero, CGPoint(x: -24, y: 22), CGPoint(x: 18, y: -26)]
        for (index, item) in shown.enumerated() {
            let offset = shown.count == 1 ? CGPoint.zero : fan[index]
            placements[item.id] = Placement(
                center: CGPoint(x: anchor.x + offset.x, y: anchor.y + offset.y),
                size: Self.baseSize(for: item.kind),
                scale: scale,
                tilt: Self.tilt(for: item.id),
                nearness: nearness
            )
        }
    }

    private mutating func placeManual(_ item: Item) {
        guard let unit = item.manual else { return }
        let rect = band(item.zone)
        let nearness = Self.nearness(item.zone)
        let scale = Self.scale(nearness: nearness)
        let base = Self.baseSize(for: item.kind)
        let half = base.width * scale / 2 + 8
        let x = min(max(rect.minX + unit.x * rect.width, half), max(size.width - half, half))
        let y = rect.minY + min(max(unit.y, 0.15), 0.85) * rect.height
        placements[item.id] = Placement(
            center: CGPoint(x: x, y: y),
            size: base,
            scale: scale,
            tilt: Self.tilt(for: item.id),
            nearness: nearness
        )
    }
}
