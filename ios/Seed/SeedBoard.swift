#if DEBUG
import os
import SwiftData
import UIKit

enum SeedBoard {
    static let homeBoardId = "seed-panth-board"
    static let crewBoardId = "sf-crew"

    struct Person {
        let id: String
        let name: String
        let color: String
    }

    static let panth = Person(id: "seed-panth", name: "panth", color: "orange")
    static let maya = Person(id: "seed-maya", name: "maya", color: "blue")
    static let sam = Person(id: "seed-sam", name: "sam", color: "green")
    static let alex = Person(id: "seed-alex", name: "alex", color: "pink")

    static let boards: [RemoteBoard] = [
        RemoteBoard(
            boardId: homeBoardId,
            name: "my board",
            shared: false,
            ownerId: panth.id,
            members: [RemoteMember(personId: panth.id, name: panth.name, color: panth.color, joinedAt: 0)],
            createdAt: 0
        ),
        RemoteBoard(
            boardId: crewBoardId,
            name: "sf crew",
            shared: true,
            inviteCode: "SFCREW",
            ownerId: panth.id,
            members: [panth, maya, sam, alex].enumerated().map { index, person in
                RemoteMember(personId: person.id, name: person.name, color: person.color, joinedAt: Double(index))
            },
            createdAt: 0
        ),
    ]

    static func clientId(board: Int, _ number: Int) -> UUID {
        UUID(uuidString: String(format: "5EED%04X-0000-4000-8000-%012X", board, number)) ?? UUID()
    }

    @MainActor
    static func replace(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        clear(context)
        DeviceIdentity.adopt(personId: panth.id, boardId: homeBoardId)
        pin(into: context, now: now, calendar: calendar)
    }

    @MainActor
    static func pin(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        pinHome(into: context, now: now, calendar: calendar)
        pinCrew(into: context, now: now)
        save(context)
    }

    @MainActor
    private static func make(
        _ board: Int,
        _ number: Int,
        _ person: Person,
        _ kind: SourceKind,
        _ zone: Zone,
        minutesAgo: Double,
        now: Date,
        unsure: Bool = false,
        in context: ModelContext,
        configure: (Drop) -> Void
    ) -> Drop {
        let drop = Drop(
            id: clientId(board: board, number),
            createdAt: now.addingTimeInterval(-minutesAgo * 60),
            authorId: person.id,
            boardId: board == 1 ? homeBoardId : crewBoardId,
            sourceKind: kind
        )
        drop.authorName = person.name
        drop.authorColor = person.color
        drop.status = .processed
        configure(drop)
        drop.applyDecidedZone(zone, unsure: unsure)
        context.insert(drop)
        return drop
    }

    @MainActor
    private static func pinHome(into context: ModelContext, now: Date, calendar: Calendar) {
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }
        func rounded(_ date: Date, toMinutes step: Double) -> Date {
            let seconds = step * 60
            return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / seconds).rounded(.up) * seconds)
        }
        let saturday = 7 - calendar.component(.weekday, from: today)
        func drop(_ number: Int, _ kind: SourceKind, _ zone: Zone, minutesAgo: Double, unsure: Bool = false, configure: (Drop) -> Void) -> Drop {
            make(1, number, panth, kind, zone, minutesAgo: minutesAgo, now: now, unsure: unsure, in: context, configure: configure)
        }

        _ = drop(1, .text, .now, minutesAgo: 2) {
            $0.rawText = "remind me in 1 hr to call mom back"
            $0.type = .note
            $0.dueAt = $0.createdAt.addingTimeInterval(3600)
            $0.whenLabel = "in 1 hr"
        }
        _ = drop(2, .image, .tonight, minutesAgo: 600) {
            $0.title = "tonkotsu ramen"
            $0.placeName = "mensho tokyo"
            $0.latitude = 37.7869
            $0.longitude = -122.4137
            $0.type = .place
            $0.objectKind = .cutout
            $0.startsAt = max(day(0, 19, 30), rounded(now.addingTimeInterval(2 * 3600), toMinutes: 30))
            $0.cutoutPath = media("seed-ramen", jpeg: false)
        }
        _ = drop(3, .url, .tonight, minutesAgo: 200) {
            $0.url = "https://www.act-sf.org/the-strand"
            $0.title = "late show at the strand"
            $0.placeName = "the strand theater"
            $0.latitude = 37.7787
            $0.longitude = -122.4139
            $0.type = .event
            $0.objectKind = .postcard
            $0.startsAt = max(day(0, 21, 45), rounded(now.addingTimeInterval(3 * 3600), toMinutes: 15))
            $0.thumbnailPath = media("seed-strand", jpeg: true)
        }
        _ = drop(4, .url, .thisWeekend, minutesAgo: 1440) {
            $0.url = "https://goseeshows.com/san-francisco/shows/2026-11-21-the-chapel-poi-dog-pondering/"
            $0.title = "poi dog pondering at the chapel"
            $0.placeName = "the chapel"
            $0.type = .event
            $0.objectKind = .stub
            $0.startsAt = day(saturday, 20)
            $0.price = "$28–33"
        }
        _ = drop(5, .audio, .thisWeekend, minutesAgo: 300) {
            $0.rawText = "the thrift spots on valencia, the one with the green awning first"
            $0.type = .note
            $0.objectKind = .slip
            $0.mediaDuration = 14
            $0.startsAt = day(saturday, 11)
        }
        _ = drop(6, .text, .thisWeekend, minutesAgo: 2880) {
            $0.rawText = "sam's birthday dinner at nopa saturday 7pm"
            $0.title = "sam's birthday dinner"
            $0.placeName = "nopa"
            $0.latitude = 37.7748
            $0.longitude = -122.4376
            $0.type = .event
            $0.objectKind = .sticky
            $0.startsAt = day(saturday, 19)
            $0.whenLabel = "saturday at 7pm"
            $0.pinnedAt = now.addingTimeInterval(-26 * 3600)
        }
        _ = drop(7, .image, .thisWeekend, minutesAgo: 420) {
            $0.rawText = "picnic at dolores sunday, bring a blanket"
            $0.title = "picnic at dolores"
            $0.placeName = "dolores park"
            $0.latitude = 37.7596
            $0.longitude = -122.4269
            $0.type = .event
            $0.objectKind = .polaroid
            $0.startsAt = day(saturday + 1, 13)
            $0.thumbnailPath = media("seed-dolores", jpeg: true)
            $0.pinnedAt = now.addingTimeInterval(-3 * 3600)
        }
        _ = drop(8, .url, .someday, minutesAgo: 9000) {
            $0.url = "https://www.nps.gov/muwo/planyourvisit/index.htm"
            $0.title = "muir woods"
            $0.placeName = "muir woods"
            $0.latitude = 37.8970
            $0.longitude = -122.5811
            $0.type = .place
            $0.objectKind = .postcard
            $0.thumbnailPath = media("seed-muirwoods", jpeg: true)
        }
        _ = drop(9, .text, .someday, minutesAgo: 7000, unsure: true) {
            $0.rawText = "that pottery class maya mentioned"
        }
        _ = drop(10, .url, .someday, minutesAgo: 6000) {
            $0.url = "https://goseeshows.com/san-francisco/shows/2027-03-13-the-fillmore-beach-bunny/"
            $0.title = "beach bunny at the fillmore"
            $0.placeName = "the fillmore"
            $0.type = .event
            $0.objectKind = .stub
            $0.startsAt = calendar.date(from: DateComponents(year: 2027, month: 3, day: 13, hour: 20))
            $0.whenLabel = "sometime in march"
        }
        _ = drop(11, .url, .someday, minutesAgo: 6500) {
            $0.url = "https://sf.eater.com/maps/best-burritos-san-francisco"
            $0.title = "the best burritos in the mission"
            $0.type = .note
            $0.objectKind = .postcard
        }
        _ = drop(12, .url, .vibes, minutesAgo: 3000) {
            $0.url = "https://open.spotify.com/track/7EHmKkyAr6MZv5Y2FdZbXw"
            $0.title = "lights"
            $0.artist = "journey"
            $0.type = .song
            $0.objectKind = .record
            $0.thumbnailPath = media("seed-lights", jpeg: true)
        }
        _ = drop(13, .image, .vibes, minutesAgo: 5000) {
            $0.rawText = "soft pink everything"
            $0.type = .mood
            $0.objectKind = .polaroid
            $0.thumbnailPath = media("seed-pinksky", jpeg: true)
        }
        let dumplings = drop(14, .url, .someday, minutesAgo: 20000) {
            $0.title = "the dumpling place"
            $0.placeName = "dumpling home"
            $0.type = .place
            $0.objectKind = .postcard
        }
        dumplings.moveByUser(to: .done)

        let arriving = Drop(id: clientId(board: 1, 15), createdAt: now, authorId: panth.id, boardId: homeBoardId, sourceKind: .url, url: "https://www.instagram.com/p/C9pastaplace")
        arriving.authorName = panth.name
        arriving.authorColor = panth.color
        context.insert(arriving)
    }

    private struct CrewDrop {
        let person: Person
        let what: ObjectKind
        let url: String
        let title: String
        var artist: String? = nil
        var place: (name: String, latitude: Double, longitude: Double)? = nil
        let image: String
        let minutesAgo: Double
        var pinnedHoursAgo: Double? = nil
        let vibes: [String]
        let cluster: String
        let neighbors: [(Int, String)]
        var suggestion: String? = nil
        var related: Int? = nil
        var seconds: Double? = nil
    }

    private static let clusterLabels = [
        "sunny-afternoons": "upbeat, in the mission",
        "late-night": "late night",
        "golden-hour": "golden hour, by the water",
    ]

    private static let crew: [CrewDrop] = [
        CrewDrop(person: maya, what: .polaroid, url: "https://www.tiktok.com/@graacciiee/video/7617551860244745503", title: "dolores park on a sunny day", place: ("dolores park", 37.75972, -122.42713), image: "seed-dolores-sunny", minutesAgo: 300, pinnedHoursAgo: 2, vibes: ["upbeat", "outdoors", "mission"], cluster: "sunny-afternoons", neighbors: [(5, "both upbeat, outdoors."), (2, "both in the mission.")], suggestion: "sam saved something that goes with this.", related: 2, seconds: 14),
        CrewDrop(person: sam, what: .postcard, url: "https://www.instagram.com/p/DHY65llvDPK/", title: "tartine morning bun", place: ("tartine bakery", 37.76146, -122.42395), image: "seed-tartine", minutesAgo: 1500, vibes: ["cozy", "morning", "food", "mission"], cluster: "sunny-afternoons", neighbors: [(3, "both morning, in the mission."), (1, "both in the mission.")], suggestion: "maya saved something that goes with this.", related: 1),
        CrewDrop(person: alex, what: .postcard, url: "https://www.stonemillmatcha-us.com/", title: "stonemill matcha", place: ("stonemill matcha", 37.76402, -122.42153), image: "seed-matcha", minutesAgo: 2600, vibes: ["calm", "morning", "mission"], cluster: "sunny-afternoons", neighbors: [(2, "both morning, in the mission.")]),
        CrewDrop(person: panth, what: .record, url: "https://open.spotify.com/track/6UsdldEfcEXSID2G3nA89J", title: "san francisco (be sure to wear flowers in your hair)", artist: "scott mckenzie", image: "seed-flowers", minutesAgo: 900, vibes: ["upbeat", "folk", "steady"], cluster: "sunny-afternoons", neighbors: [(1, "both upbeat."), (5, "both upbeat.")]),
        CrewDrop(person: maya, what: .polaroid, url: "https://www.tiktok.com/@marissadaily_/video/7541446036347309343", title: "15 things to do in sf", image: "seed-15things", minutesAgo: 4000, vibes: ["upbeat", "outdoors"], cluster: "sunny-afternoons", neighbors: [(1, "both upbeat, outdoors.")], seconds: 62),
        CrewDrop(person: alex, what: .polaroid, url: "https://www.tiktok.com/@thesnacksensei/video/7561602082596343095", title: "mission district food tour", image: "seed-foodtour", minutesAgo: 700, vibes: ["late night", "food", "mission"], cluster: "late-night", neighbors: [(7, "both late night, food."), (10, "both late night, in the mission.")], suggestion: "sam saved something that goes with this.", related: 7, seconds: 48),
        CrewDrop(person: sam, what: .polaroid, url: "https://www.youtube.com/watch?v=zmIgc0SkVgE", title: "marufuku ramen", place: ("marufuku ramen", 37.78530, -122.43010), image: "seed-marufuku", minutesAgo: 2000, vibes: ["cozy", "late night", "food", "japantown"], cluster: "late-night", neighbors: [(6, "both late night, food.")], suggestion: "alex saved something that goes with this.", related: 6, seconds: 462),
        CrewDrop(person: panth, what: .record, url: "https://open.spotify.com/track/0ofHAoxe9vBkTCp2UQIavz", title: "dreams", artist: "fleetwood mac", image: "seed-dreams", minutesAgo: 3100, vibes: ["dreamy", "late night", "rock", "steady"], cluster: "late-night", neighbors: [(9, "both late night."), (14, "both dreamy.")]),
        CrewDrop(person: maya, what: .record, url: "https://open.spotify.com/track/6ZRuF2n1CQxyxxAAWsKJOy", title: "nights like this", artist: "kehlani", image: "seed-nights", minutesAgo: 1200, vibes: ["moody", "late night", "r&b", "slow"], cluster: "late-night", neighbors: [(8, "both late night.")]),
        CrewDrop(person: alex, what: .postcard, url: "https://thechapelsf.com", title: "the chapel", place: ("the chapel", 37.76049, -122.42120), image: "seed-concert", minutesAgo: 5200, vibes: ["late night", "live music", "mission"], cluster: "late-night", neighbors: [(6, "both late night, in the mission.")]),
        CrewDrop(person: panth, what: .polaroid, url: "https://www.instagram.com/p/DWCN6pbgn3F/", title: "golden gate from fort point", place: ("fort point", 37.81060, -122.47710), image: "seed-fortpoint", minutesAgo: 450, vibes: ["golden hour", "by the water", "calm", "presidio"], cluster: "golden-hour", neighbors: [(12, "both golden hour, by the water."), (15, "both golden hour, by the water.")], seconds: 9),
        CrewDrop(person: sam, what: .polaroid, url: "https://www.instagram.com/reel/DbySW82ILGn/", title: "the golden gate still feels unreal", image: "seed-ggreel", minutesAgo: 3600, vibes: ["golden hour", "by the water", "dreamy"], cluster: "golden-hour", neighbors: [(11, "both golden hour, by the water."), (14, "both dreamy, golden hour.")], seconds: 18),
        CrewDrop(person: maya, what: .record, url: "https://open.spotify.com/track/3zBhihYUHBmGd2bcQIobrF", title: "(sittin' on) the dock of the bay", artist: "otis redding", image: "seed-dock", minutesAgo: 6100, vibes: ["calm", "by the water", "soul", "slow"], cluster: "golden-hour", neighbors: [(11, "both calm, by the water.")]),
        CrewDrop(person: alex, what: .record, url: "https://open.spotify.com/track/3xKsf9qdS1CyvXSMEid6g8", title: "pink + white", artist: "frank ocean", image: "seed-pinkwhite", minutesAgo: 2300, vibes: ["dreamy", "golden hour", "r&b", "steady"], cluster: "golden-hour", neighbors: [(12, "both dreamy, golden hour.")]),
        CrewDrop(person: panth, what: .postcard, url: "https://www.nps.gov/goga/planyourvisit/landsend.htm", title: "lands end trail", place: ("lands end", 37.78020, -122.51150), image: "seed-landsend", minutesAgo: 8000, pinnedHoursAgo: 20, vibes: ["golden hour", "by the water", "outdoors", "lands end"], cluster: "golden-hour", neighbors: [(11, "both golden hour, by the water.")]),
    ]

    @MainActor
    private static func pinCrew(into context: ModelContext, now: Date) {
        for (index, seed) in crew.enumerated() {
            let type: DropType = switch seed.what {
            case .record: .song
            case .postcard: .place
            default: .mood
            }
            _ = make(2, index + 1, seed.person, .url, type == .place ? .someday : .vibes, minutesAgo: seed.minutesAgo, now: now, in: context) { drop in
                drop.url = seed.url
                drop.title = seed.title
                drop.artist = seed.artist
                drop.placeName = seed.place?.name
                drop.latitude = seed.place?.latitude
                drop.longitude = seed.place?.longitude
                drop.type = type
                drop.objectKind = seed.what
                drop.thumbnailPath = media(seed.image, jpeg: true)
                drop.pinnedAt = seed.pinnedHoursAgo.map { now.addingTimeInterval(-$0 * 3600) }
                drop.vibes = seed.vibes
                drop.clusterId = seed.cluster
                drop.clusterLabel = clusterLabels[seed.cluster]
                drop.neighbors = seed.neighbors.map { DropNeighbor(clientId: clientId(board: 2, $0.0).uuidString, reason: $0.1) }
                drop.suggestion = seed.suggestion
                drop.relatedDropIds = seed.related.map { [clientId(board: 2, $0)] } ?? []
                drop.mediaDuration = seed.seconds
            }
        }
    }

    @MainActor
    static func clear(_ context: ModelContext) {
        do {
            try context.delete(model: Drop.self)
        } catch {
            Logger.store.error("clearing the board failed: \(String(describing: error), privacy: .public)")
        }
        save(context)
    }

    private static func media(_ name: String, jpeg: Bool) -> String? {
        guard let image = UIImage(named: name),
              let data = jpeg ? image.jpegData(compressionQuality: 0.85) : image.pngData()
        else {
            Logger.store.error("seed image \(name, privacy: .public) is missing")
            return nil
        }
        do {
            return try MediaStore.save(data, named: "\(name).\(jpeg ? "jpg" : "png")")
        } catch {
            Logger.store.error("saving seed image \(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    @MainActor
    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            Logger.store.error("saving the seed board failed: \(String(describing: error), privacy: .public)")
        }
    }
}
#endif
