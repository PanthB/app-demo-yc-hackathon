import SwiftUI

struct CorkboardLayout {
    enum Fastener {
        case pin, ringedPin, tape, none
    }

    struct Item: Identifiable {
        let drop: Drop
        let zone: Zone?
        let center: CGPoint
        let size: CGSize
        let tilt: Double
        let scale: CGFloat
        let tag: String?
        let fastener: Fastener
        let order: Int
        var id: UUID { drop.id }

        func boardPoint(_ local: CGPoint) -> CGPoint {
            let radians = tilt * .pi / 180
            let x = local.x * scale
            let y = local.y * scale
            return CGPoint(
                x: center.x + x * cos(radians) - y * sin(radians),
                y: center.y + x * sin(radians) + y * cos(radians)
            )
        }

        var pinPoint: CGPoint {
            boardPoint(CGPoint(x: 0, y: -size.height / 2 + 5))
        }

        var tagCorner: CGPoint {
            boardPoint(CGPoint(x: size.width / 2 + 6, y: size.height / 2 - 11))
        }
    }

    struct Label: Identifiable {
        let zone: Zone
        let origin: CGPoint
        let order: Int
        var id: Zone { zone }
    }

    struct Thread: Identifiable {
        let id: String
        let from: CGPoint
        let to: CGPoint
    }

    static let labelLeading: CGFloat = 32
    static let objectLeading: CGFloat = 44
    static let trailing: CGFloat = 14
    static let cornerInset: CGFloat = 12
    static let envelopeSize = CGSize(width: 84, height: 60)
    static let pocketSize = CGSize(width: 64, height: 52)
    static let vibeScale: CGFloat = 0.7
    static let shownVibes = 3

    private(set) var items: [Item] = []
    private(set) var vibes: [Item] = []
    private(set) var labels: [Label] = []
    private(set) var threads: [Thread] = []
    private(set) var height: CGFloat = 0
    private(set) var envelope: CGRect = .zero
    private(set) var pocket: CGRect = .zero
    private(set) var emptyNoteCenter: CGPoint?
    private var order = 0

    init(contents: BoardContents, width: CGFloat, minHeight: CGFloat, now: Date) {
        var y: CGFloat = 0
        if !contents.arriving.isEmpty {
            y = placeObjects(contents.arriving, zone: nil, top: 18, width: width, now: now) - 18
        }
        for zone in Zone.timeOrder {
            let labelTop = y + (zone == .now ? 24 : 6)
            labels.append(Label(zone: zone, origin: CGPoint(x: Self.labelLeading, y: labelTop), order: nextOrder()))
            let objectsTop = labelTop + (zone == .now ? 50 : 36) + 14
            let drops = contents.drops(in: zone)
            if zone == .now, contents.isEmpty {
                emptyNoteCenter = CGPoint(x: (Self.objectLeading + width - Self.trailing) / 2, y: objectsTop + 70)
                y = objectsTop + 160
            } else if drops.isEmpty {
                y = objectsTop + 40
            } else {
                y = placeObjects(drops, zone: zone, top: objectsTop, width: width, now: now)
            }
        }

        let shown = Array(contents.drops(in: .vibes).prefix(Self.shownVibes))
        let peek = shown.map { Self.size(for: $0).height * Self.vibeScale / 2 }.max() ?? 0
        let footerBottom = max(y + 24 + peek + Self.envelopeSize.height + 6, minHeight - 8)
        envelope = CGRect(
            x: width - Self.cornerInset - Self.envelopeSize.width,
            y: footerBottom - Self.envelopeSize.height,
            width: Self.envelopeSize.width,
            height: Self.envelopeSize.height
        )
        pocket = CGRect(
            x: Self.cornerInset,
            y: footerBottom - Self.pocketSize.height,
            width: Self.pocketSize.width,
            height: Self.pocketSize.height
        )
        placeVibes(shown)
        height = footerBottom + 8

        let everything = Dictionary((items + vibes).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for item in items + vibes {
            for other in item.drop.relatedDropIds where item.id.uuidString < other.uuidString {
                guard let partner = everything[other] else { continue }
                threads.append(Thread(id: "\(item.id)-\(other)", from: item.pinPoint, to: partner.pinPoint))
            }
        }
    }

    var threadedIds: Set<UUID> {
        var ids = Set<UUID>()
        let all = Dictionary((items + vibes).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for item in items + vibes {
            for other in item.drop.relatedDropIds where all[other] != nil {
                ids.insert(item.id)
                ids.insert(other)
            }
        }
        return ids
    }

    static func size(for drop: Drop) -> CGSize {
        if drop.showsRawThing {
            if MediaStore.image(at: drop.thumbnailPath ?? drop.cutoutPath) != nil {
                return CGSize(width: 160, height: 150)
            }
            return CGSize(width: 160, height: (drop.rawText ?? "").isEmpty ? 56 : 96)
        }
        switch drop.objectKind {
        case .sticky: return CGSize(width: 120, height: 120)
        case .polaroid: return CGSize(width: 136, height: 162)
        case .record: return CGSize(width: 120, height: 120)
        case .slip: return CGSize(width: 160, height: 64)
        case .stub: return CGSize(width: 160, height: 76)
        case .postcard: return CGSize(width: 190, height: 128)
        case .cutout:
            let width: CGFloat = 140
            guard let image = MediaStore.image(at: drop.cutoutPath ?? drop.thumbnailPath), image.size.width > 0 else {
                return CGSize(width: 160, height: 150)
            }
            return CGSize(width: width, height: min(190, max(90, width * image.size.height / image.size.width)))
        }
    }

    static func tag(for drop: Drop, zone: Zone?, now: Date) -> String? {
        guard let zone, Zone.timeOrder.contains(zone), !drop.isHeldByTape else { return nil }
        if drop.objectKind == .sticky, drop.dueAt != nil { return nil }
        if drop.objectKind == .stub { return nil }
        return drop.frontTag(now: now)
    }

    private mutating func nextOrder() -> Int {
        order += 1
        return order
    }

    private mutating func placeObjects(_ drops: [Drop], zone: Zone?, top: CGFloat, width: CGFloat, now: Date) -> CGFloat {
        let left = Self.objectLeading
        let right = width - Self.trailing
        var bottoms: [CGFloat] = [top, top + 22]
        var previous: (top: CGFloat, height: CGFloat)?

        for (index, drop) in drops.enumerated() {
            var random = StableRandom(drop.id)
            let size = Self.size(for: drop)
            let column = index % 2
            var itemTop = bottoms[column]
            if let previous {
                itemTop = max(itemTop, previous.top + previous.height * 0.35)
            }
            itemTop += random.value(in: 0...10)
            let nudge = random.value(in: 0...18)
            let preferred = column == 0 ? left + size.width / 2 + nudge : right - size.width / 2 - nudge
            let x = min(max(preferred, left + size.width / 2), right - size.width / 2)
            let sign: Double = column == 0 ? -1 : 1
            items.append(Item(
                drop: drop,
                zone: zone,
                center: CGPoint(x: x, y: itemTop + size.height / 2),
                size: size,
                tilt: sign * random.value(in: 1.5...4),
                scale: 1,
                tag: Self.tag(for: drop, zone: zone, now: now),
                fastener: drop.isHeldByTape ? .tape : (drop.zoneSetByUser ? .ringedPin : .pin),
                order: nextOrder()
            ))
            bottoms[column] = itemTop + size.height + 28
            previous = (itemTop, size.height)
        }
        return bottoms.max() ?? top
    }

    private mutating func placeVibes(_ drops: [Drop]) {
        let spread: [CGFloat] = drops.count == 1 ? [0] : (drops.count == 2 ? [-12, 12] : [-16, 0, 16])
        let fan: [Double] = drops.count == 1 ? [-3] : (drops.count == 2 ? [-7, 6] : [-9, 2, 10])
        for (index, drop) in drops.enumerated() {
            let size = Self.size(for: drop)
            vibes.append(Item(
                drop: drop,
                zone: .vibes,
                center: CGPoint(x: envelope.midX + spread[index], y: envelope.minY + 4),
                size: size,
                tilt: fan[index],
                scale: Self.vibeScale,
                tag: nil,
                fastener: .none,
                order: nextOrder()
            ))
        }
    }
}
