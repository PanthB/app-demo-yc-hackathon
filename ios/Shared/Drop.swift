import Foundation
import SwiftData

struct DropNeighbor: Codable, Hashable, Sendable {
    var clientId: String
    var reason: String
}

@Model
final class Drop {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var updatedAt: Date
    @Attribute(originalName: "dropperId") var authorId: String = ""
    var authorName: String?
    var authorColor: String?
    var boardId: String = ""
    var remoteId: String?

    var sourceKindRaw: String
    var rawText: String?
    var url: String?
    var mediaPaths: [String] = []
    var thumbnailPath: String?
    var cutoutPath: String?
    var mediaDuration: Double?

    var statusRaw: String = DropStatus.pending.rawValue
    var title: String?
    var artist: String?
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    var anchorLatitude: Double?
    var anchorLongitude: Double?
    var startsAt: Date?
    var dueAt: Date?
    var whenLabel: String?
    var price: String?
    var kindWords: [String] = []
    var vibeWords: [String] = []
    var confidence: Double?

    var typeRaw: String?
    var objectKindRaw: String
    var zoneRaw: String = Zone.someday.rawValue
    var zoneUnsure: Bool = true
    var emphasisRaw: String = Emphasis.normal.rawValue
    var relatedDropIds: [UUID] = []
    var planId: UUID?
    var suggestion: String?
    var genre: String?
    var vibes: [String] = []
    var clusterId: String?
    var clusterLabel: String?
    var neighbors: [DropNeighbor] = []

    var zoneSetByUser: Bool = false
    var pinnedAt: Date?
    var manualX: Double?
    var manualY: Double?
    var previousZoneRaw: String?
    var previousManualX: Double?
    var previousManualY: Double?

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        authorId: String,
        boardId: String = "",
        sourceKind: SourceKind,
        rawText: String? = nil,
        url: String? = nil,
        mediaPaths: [String] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.authorId = authorId
        self.boardId = boardId
        self.sourceKindRaw = sourceKind.rawValue
        self.rawText = rawText
        self.url = url
        self.mediaPaths = mediaPaths
        self.objectKindRaw = sourceKind.defaultObjectKind.rawValue
    }

    var sourceKind: SourceKind {
        get { SourceKind(rawValue: sourceKindRaw) ?? .text }
        set { sourceKindRaw = newValue.rawValue }
    }

    var status: DropStatus {
        get { DropStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var type: DropType? {
        get { typeRaw.flatMap(DropType.init(rawValue:)) }
        set { typeRaw = newValue?.rawValue }
    }

    var objectKind: ObjectKind {
        get { ObjectKind(rawValue: objectKindRaw) ?? sourceKind.defaultObjectKind }
        set { objectKindRaw = newValue.rawValue }
    }

    var zone: Zone {
        Zone(rawValue: zoneRaw) ?? .someday
    }

    var emphasis: Emphasis {
        get { Emphasis(rawValue: emphasisRaw) ?? .normal }
        set { emphasisRaw = newValue.rawValue }
    }

    var previousZone: Zone? {
        previousZoneRaw.flatMap(Zone.init(rawValue:))
    }

    var canUndoMove: Bool {
        previousZoneRaw != nil
    }

    var isPinned: Bool {
        pinnedAt != nil
    }

    func setPinned(_ pinned: Bool) {
        pinnedAt = pinned ? .now : nil
        updatedAt = .now
    }

    func applyDecidedZone(_ decided: Zone, unsure: Bool) {
        guard !zoneSetByUser else { return }
        zoneRaw = decided.rawValue
        zoneUnsure = unsure
        updatedAt = .now
    }

    func moveByUser(to newZone: Zone, x: Double? = nil, y: Double? = nil) {
        previousZoneRaw = zoneRaw
        previousManualX = manualX
        previousManualY = manualY
        zoneRaw = newZone.rawValue
        manualX = x
        manualY = y
        zoneSetByUser = true
        zoneUnsure = false
        updatedAt = .now
    }

    func undoMove() {
        guard let previousZoneRaw else { return }
        zoneRaw = previousZoneRaw
        manualX = previousManualX
        manualY = previousManualY
        self.previousZoneRaw = nil
        previousManualX = nil
        previousManualY = nil
        updatedAt = .now
    }
}
