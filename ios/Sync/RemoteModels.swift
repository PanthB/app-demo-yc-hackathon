import CryptoKit
import Foundation

struct RemotePerson: Decodable, Equatable, Sendable {
    var personId: String
    var name: String
    var personalBoardId: String
}

struct RemoteMember: Decodable, Equatable, Identifiable, Sendable {
    var personId: String
    var name: String
    var color: String
    var joinedAt: Double

    var id: String { personId }
}

struct RemoteBoard: Decodable, Equatable, Identifiable, Sendable {
    var boardId: String
    var name: String
    var shared: Bool
    var inviteCode: String?
    var ownerId: String
    var members: [RemoteMember]
    var createdAt: Double

    var id: String { boardId }

    var inviteLink: URL? {
        inviteCode.flatMap { URL(string: "appdemo://join/\($0)") }
    }
}

struct RemoteDrop: Decodable, Equatable, Sendable {
    struct Hints: Decodable, Equatable, Sendable {
        var artist: String?
        var placeName: String?

        init(from decoder: Decoder) throws {
            let row = try decoder.container(keyedBy: CodingKeys.self)
            artist = row.maybe(.artist)
            placeName = row.maybe(.placeName)
        }

        enum CodingKeys: String, CodingKey {
            case artist, placeName
        }
    }

    struct Enrichment: Decodable, Equatable, Sendable {
        var author: String?
        var genre: String?
        var durationSec: Double?

        init(from decoder: Decoder) throws {
            let row = try decoder.container(keyedBy: CodingKeys.self)
            author = row.maybe(.author)
            genre = row.maybe(.genre)
            durationSec = row.maybe(.durationSec)
        }

        enum CodingKeys: String, CodingKey {
            case author, genre, durationSec
        }
    }

    struct Extraction: Decodable, Equatable, Sendable {
        var placeName: String?
        var area: String?
        var startsAt: Double?
        var dueAt: Double?
        var whenLabel: String?
        var price: Double?
        var kindWords: [String]?
        var vibeWords: [String]?
        var confidence: Double?

        init(from decoder: Decoder) throws {
            let row = try decoder.container(keyedBy: CodingKeys.self)
            placeName = row.maybe(.placeName)
            area = row.maybe(.area)
            startsAt = row.maybe(.startsAt)
            dueAt = row.maybe(.dueAt)
            whenLabel = row.maybe(.whenLabel)
            price = row.maybe(.price)
            kindWords = row.maybe(.kindWords)
            vibeWords = row.maybe(.vibeWords)
            confidence = row.maybe(.confidence)
        }

        enum CodingKeys: String, CodingKey {
            case placeName, area, startsAt, dueAt, whenLabel, price, kindWords, vibeWords, confidence
        }

        var priceText: String? {
            guard let price else { return nil }
            if price == 0 { return "free" }
            return price == price.rounded() ? "$\(Int(price))" : String(format: "$%.2f", price)
        }
    }

    struct Decision: Decodable, Equatable, Sendable {
        var type: String?
        var objectKind: String?
        var emphasis: String?
        var unsure: Bool?

        init(from decoder: Decoder) throws {
            let row = try decoder.container(keyedBy: CodingKeys.self)
            type = row.maybe(.type)
            objectKind = row.maybe(.objectKind)
            emphasis = row.maybe(.emphasis)
            unsure = row.maybe(.unsure)
        }

        enum CodingKeys: String, CodingKey {
            case type, objectKind, emphasis, unsure
        }
    }

    var _id: String
    var boardId: String
    var clientId: String
    var authorId: String
    var authorName: String?
    var authorColor: String?
    var kind: String
    var text: String?
    var url: String?
    var thumbnailUrl: String?
    var title: String?
    var capturedAt: Double
    var latitude: Double?
    var longitude: Double?
    var hints: Hints?
    var status: String
    var zone: String?
    var zoneSetByUser: Bool?
    var previousZone: String?
    var pinned: Bool?
    var pinnedAt: Double?
    var suggestion: String?
    var relatedClientIds: [String]?
    var vibes: [String]?
    var clusterId: String?
    var clusterLabel: String?
    var neighbors: [DropNeighbor]?
    var enrichment: Enrichment?
    var extraction: Extraction?
    var decision: Decision?

    init(from decoder: Decoder) throws {
        let row = try decoder.container(keyedBy: CodingKeys.self)
        _id = try row.decode(String.self, forKey: ._id)
        boardId = try row.decode(String.self, forKey: .boardId)
        clientId = try row.decode(String.self, forKey: .clientId)
        authorId = try row.decode(String.self, forKey: .authorId)
        kind = try row.decode(String.self, forKey: .kind)
        capturedAt = try row.decode(Double.self, forKey: .capturedAt)
        status = try row.decode(String.self, forKey: .status)
        authorName = row.maybe(.authorName)
        authorColor = row.maybe(.authorColor)
        text = row.maybe(.text)
        url = row.maybe(.url)
        thumbnailUrl = row.maybe(.thumbnailUrl)
        title = row.maybe(.title)
        latitude = row.maybe(.latitude)
        longitude = row.maybe(.longitude)
        hints = row.maybe(.hints)
        zone = row.maybe(.zone)
        zoneSetByUser = row.maybe(.zoneSetByUser)
        previousZone = row.maybe(.previousZone)
        pinned = row.maybe(.pinned)
        pinnedAt = row.maybe(.pinnedAt)
        suggestion = row.maybe(.suggestion)
        relatedClientIds = row.maybe(.relatedClientIds)
        vibes = row.maybe(.vibes)
        clusterId = row.maybe(.clusterId)
        clusterLabel = row.maybe(.clusterLabel)
        neighbors = row.maybe(.neighbors)
        enrichment = row.maybe(.enrichment)
        extraction = row.maybe(.extraction)
        decision = row.maybe(.decision)
    }

    enum CodingKeys: String, CodingKey {
        case _id, boardId, clientId, authorId, authorName, authorColor, kind, text, url, thumbnailUrl, title
        case capturedAt, latitude, longitude, hints, status, zone, zoneSetByUser, previousZone, pinned, pinnedAt
        case suggestion, relatedClientIds, vibes, clusterId, clusterLabel, neighbors, enrichment, extraction, decision
    }
}

extension KeyedDecodingContainer {
    func maybe<Value: Decodable>(_ key: Key) -> Value? {
        (try? decodeIfPresent(Value.self, forKey: key)) ?? nil
    }
}

struct LossyList<Element: Decodable>: Decodable {
    var elements: [Element] = []
    var skipped = 0

    init(from decoder: Decoder) throws {
        var list = try decoder.unkeyedContainer()
        while !list.isAtEnd {
            do {
                elements.append(try list.decode(Element.self))
            } catch {
                skipped += 1
                guard (try? list.decode(Anything.self)) != nil else { break }
            }
        }
    }

    private struct Anything: Decodable {
        init(from decoder: Decoder) throws {}
    }
}

enum DropKey {
    static func id(for clientId: String) -> UUID {
        if let id = UUID(uuidString: clientId) { return id }
        var bytes = Array(SHA256.hash(data: Data(clientId.utf8)).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

extension Date {
    init(convexTime milliseconds: Double) {
        self.init(timeIntervalSince1970: milliseconds / 1000)
    }

    var convexTime: Double {
        timeIntervalSince1970 * 1000
    }
}
