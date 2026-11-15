import SwiftUI

struct CorkboardLayout {
    enum Fastener {
        case pin, tape
    }

    struct Item: Identifiable {
        let drop: Drop
        let sectionId: String
        let center: CGPoint
        let size: CGSize
        let tilt: Double
        let labelWidth: CGFloat
        let fastener: Fastener
        let order: Int
        var id: UUID { drop.id }

        var pinPoint: CGPoint {
            let radians = tilt * .pi / 180
            let y = -size.height / 2 + 5
            return CGPoint(x: center.x - y * sin(radians), y: center.y + y * cos(radians))
        }
    }

    struct Header: Identifiable {
        let id: String
        let title: String
        let count: Int
        let isNow: Bool
        let top: CGFloat
        let order: Int
    }

    struct Thread: Identifiable {
        let id: String
        let from: CGPoint
        let to: CGPoint
    }

    static let margin: CGFloat = 16
    static let gutter: CGFloat = 12
    static let rowGap: CGFloat = 24
    static let labelDrop: CGFloat = 11
    static let pocketSize = CGSize(width: 64, height: 52)

    private(set) var items: [Item] = []
    private(set) var headers: [Header] = []
    private(set) var threads: [Thread] = []
    private(set) var pocket: CGRect?
    private(set) var doneCount = 0
    private(set) var emptyNoteCenter: CGPoint?
    private(set) var height: CGFloat = 0
    private var order = 0

    init(sections: [DropSection], width: CGFloat, minHeight: CGFloat) {
        guard !sections.isEmpty else {
            emptyNoteCenter = CGPoint(x: width / 2, y: max(minHeight * 0.4, 160))
            height = minHeight
            return
        }
        let column = (width - 2 * Self.margin - Self.gutter) / 2
        var y: CGFloat = 8
        for section in sections {
            if section.style == .done {
                let frame = CGRect(origin: CGPoint(x: Self.margin, y: y + 8), size: Self.pocketSize)
                pocket = frame
                doneCount = section.drops.count
                y = frame.maxY + Self.rowGap
                continue
            }
            let isNow = section.id == Zone.now.rawValue
            let top = y + (isNow ? 16 : 8)
            headers.append(Header(id: section.id, title: section.title, count: section.drops.count, isNow: isNow, top: top, order: nextOrder()))
            y = placeRows(section, top: top + (isNow ? 50 : 36) + 14, width: width, column: column)
        }
        height = max(y, minHeight)

        let placed = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for item in items {
            for other in item.drop.relatedDropIds where item.id.uuidString < other.uuidString {
                guard let partner = placed[other] else { continue }
                threads.append(Thread(id: "\(item.id)-\(other)", from: item.pinPoint, to: partner.pinPoint))
            }
        }
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
        case .polaroid: return CGSize(width: 136, height: 184)
        case .record: return CGSize(width: 120, height: 120)
        case .slip: return CGSize(width: 160, height: 84)
        case .stub: return CGSize(width: 160, height: 76)
        case .postcard: return CGSize(width: 176, height: 118)
        case .cutout:
            let width: CGFloat = 140
            guard let image = MediaStore.image(at: drop.cutoutPath ?? drop.thumbnailPath), image.size.width > 0 else {
                return CGSize(width: 160, height: 150)
            }
            let picture = min(164, max(90, width * image.size.height / image.size.width))
            return CGSize(width: width, height: (picture + PaperObject.captionHeight).rounded())
        }
    }

    private mutating func nextOrder() -> Int {
        order += 1
        return order
    }

    private mutating func placeRows(_ section: DropSection, top: CGFloat, width: CGFloat, column: CGFloat) -> CGFloat {
        let centers = [Self.margin + column / 2, width - Self.margin - column / 2]
        var rowTop = top
        for start in stride(from: 0, to: section.drops.count, by: 2) {
            var tallest: CGFloat = 0
            for (index, drop) in section.drops[start..<min(start + 2, section.drops.count)].enumerated() {
                var random = StableRandom(drop.id)
                let natural = Self.size(for: drop)
                let size = natural.width > column
                    ? CGSize(width: column, height: (natural.height * column / natural.width).rounded())
                    : natural
                items.append(Item(
                    drop: drop,
                    sectionId: section.id,
                    center: CGPoint(x: centers[index], y: rowTop + size.height / 2),
                    size: size,
                    tilt: (index == 0 ? -1 : 1) * random.value(in: 0.5...1.5),
                    labelWidth: (size.width + column) / 2 - 10,
                    fastener: drop.isPinned ? .pin : .tape,
                    order: nextOrder()
                ))
                tallest = max(tallest, size.height)
            }
            rowTop += tallest + Self.labelDrop + Self.rowGap
        }
        return rowTop
    }
}
