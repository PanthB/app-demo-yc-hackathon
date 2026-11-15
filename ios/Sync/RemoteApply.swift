import Foundation

extension RemoteDrop {
    @MainActor
    func makeDrop(id: UUID) -> Drop {
        Drop(
            id: id,
            createdAt: Date(convexTime: capturedAt),
            authorId: authorId,
            boardId: boardId,
            sourceKind: SourceKind(rawValue: kind) ?? .text,
            rawText: text,
            url: url
        )
    }

    @MainActor
    func apply(to drop: Drop, holdingPlacement: Bool) {
        func put<Value: Equatable>(_ path: ReferenceWritableKeyPath<Drop, Value>, _ value: Value) {
            if drop[keyPath: path] != value { drop[keyPath: path] = value }
        }
        func fill<Value: Equatable>(_ path: ReferenceWritableKeyPath<Drop, Value?>, _ value: Value?) {
            if let value { put(path, value) }
        }

        put(\.remoteId, _id)
        put(\.boardId, boardId)
        put(\.authorId, authorId)
        put(\.authorName, authorName)
        put(\.authorColor, authorColor)
        put(\.suggestion, suggestion)
        if DropStatus(rawValue: status) != nil { put(\.statusRaw, status) }

        fill(\.title, title)
        fill(\.placeName, extraction?.placeName ?? hints?.placeName)
        fill(\.startsAt, extraction?.startsAt.map(Date.init(convexTime:)))
        fill(\.dueAt, extraction?.dueAt.map(Date.init(convexTime:)))
        fill(\.whenLabel, extraction?.whenLabel)
        fill(\.price, extraction?.priceText)
        fill(\.confidence, extraction?.confidence)
        fill(\.anchorLatitude, latitude)
        fill(\.anchorLongitude, longitude)
        if let words = extraction?.kindWords { put(\.kindWords, words) }
        if let words = extraction?.vibeWords { put(\.vibeWords, words) }
        put(\.relatedDropIds, (relatedClientIds ?? []).map(DropKey.id(for:)))
        put(\.vibes, vibes ?? [])
        put(\.clusterId, clusterId)
        put(\.clusterLabel, clusterLabel)
        put(\.neighbors, (neighbors ?? []).map { DropNeighbor(clientId: DropKey.id(for: $0.clientId).uuidString, reason: $0.reason) })
        fill(\.genre, enrichment?.genre)
        fill(\.mediaDuration, enrichment?.durationSec)

        if let type = decision?.type.flatMap(DropType.init(rawValue:)) {
            put(\.typeRaw, type.rawValue)
            if type == .song { fill(\.artist, hints?.artist ?? enrichment?.author) }
        }
        if let kind = decision?.objectKind.flatMap(ObjectKind.init(rawValue:)) {
            put(\.objectKindRaw, (kind == .cutout && drop.cutoutPath == nil ? ObjectKind.polaroid : kind).rawValue)
        }
        if let emphasis = decision?.emphasis.flatMap(Emphasis.init(rawValue:)) {
            put(\.emphasisRaw, emphasis.rawValue)
        }

        guard !holdingPlacement else { return }
        put(\.pinnedAt, pinned == true ? Date(convexTime: pinnedAt ?? capturedAt) : nil)
        guard let zone = zone.flatMap(Zone.init(rawValue:)) else { return }
        if zoneSetByUser == true {
            if drop.zone != zone || !drop.zoneSetByUser {
                drop.moveByUser(to: zone)
                drop.previousZoneRaw = previousZone
            }
        } else {
            let unsure = decision?.unsure ?? false
            if drop.zone != zone || drop.zoneUnsure != unsure {
                drop.applyDecidedZone(zone, unsure: unsure)
            }
        }
    }
}
