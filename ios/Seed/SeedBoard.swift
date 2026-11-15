#if DEBUG
import os
import SwiftData
import UIKit

enum SeedBoard {
    static let boardId = "sf-crew"

    struct Person {
        let id: String
        let name: String
        let color: String
    }

    static let panth = Person(id: "seed-panth", name: "panth", color: "orange")
    static let maya = Person(id: "seed-maya", name: "maya", color: "blue")
    static let sam = Person(id: "seed-sam", name: "sam", color: "green")
    static let alex = Person(id: "seed-alex", name: "alex", color: "pink")

    static func clientId(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "5EED0000-0000-4000-8000-%012X", number)) ?? UUID()
    }

    @MainActor
    static func replace(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        clear(context)
        DeviceIdentity.adopt(personId: panth.id)
        pin(into: context, now: now, calendar: calendar)
    }

    @MainActor
    static func pin(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
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

        func drop(
            _ number: Int,
            _ person: Person,
            _ kind: SourceKind,
            _ zone: Zone,
            minutesAgo: Double,
            unsure: Bool = false,
            configure: (Drop) -> Void
        ) -> Drop {
            let drop = Drop(
                id: clientId(number),
                createdAt: now.addingTimeInterval(-minutesAgo * 60),
                authorId: person.id,
                boardId: boardId,
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

        _ = drop(1, panth, .text, .now, minutesAgo: 2) {
            $0.rawText = "remind me in 1 hr to call mom back"
            $0.type = .note
            $0.dueAt = $0.createdAt.addingTimeInterval(3600)
            $0.whenLabel = "in 1 hr"
        }
        _ = drop(2, maya, .url, .now, minutesAgo: 90) {
            $0.url = "https://www.stonemillmatcha.com"
            $0.title = "stonemill matcha"
            $0.placeName = "stonemill matcha"
            $0.latitude = 37.7637
            $0.longitude = -122.4217
            $0.type = .place
            $0.objectKind = .postcard
            $0.startsAt = rounded(now.addingTimeInterval(40 * 60), toMinutes: 15)
            $0.thumbnailPath = media("seed-matcha", jpeg: true)
        }
        _ = drop(3, sam, .image, .tonight, minutesAgo: 600) {
            $0.title = "tonkotsu ramen"
            $0.placeName = "mensho tokyo"
            $0.latitude = 37.7869
            $0.longitude = -122.4137
            $0.type = .place
            $0.objectKind = .cutout
            $0.startsAt = max(day(0, 19, 30), rounded(now.addingTimeInterval(2 * 3600), toMinutes: 30))
            $0.cutoutPath = media("seed-ramen", jpeg: false)
        }
        _ = drop(4, alex, .url, .tonight, minutesAgo: 200) {
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
        _ = drop(5, panth, .pdf, .thisWeekend, minutesAgo: 1440) {
            $0.title = "chapel jazz night"
            $0.placeName = "the chapel"
            $0.type = .event
            $0.objectKind = .stub
            $0.startsAt = day(saturday, 20)
            $0.price = "$25"
        }
        _ = drop(6, sam, .audio, .thisWeekend, minutesAgo: 300) {
            $0.rawText = "the thrift spots on valencia, the one with the green awning first"
            $0.type = .note
            $0.objectKind = .slip
            $0.mediaDuration = 14
            $0.startsAt = day(saturday, 11)
        }
        _ = drop(7, alex, .text, .thisWeekend, minutesAgo: 2880) {
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
        _ = drop(8, maya, .image, .thisWeekend, minutesAgo: 420) {
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
        let show = drop(9, sam, .video, .someday, minutesAgo: 4000) {
            $0.url = "https://www.tiktok.com/@soundcheck/video/7311"
            $0.title = "the warehouse show"
            $0.type = .event
            $0.objectKind = .polaroid
            $0.whenLabel = "sometime in march"
            $0.thumbnailPath = media("seed-concert", jpeg: true)
            $0.suggestion = "alex saved something that goes with this."
        }
        _ = drop(10, panth, .url, .someday, minutesAgo: 9000) {
            $0.url = "https://www.greendoorbooks.example"
            $0.title = "green door books"
            $0.type = .place
            $0.objectKind = .postcard
            $0.thumbnailPath = media("seed-bookshop", jpeg: true)
        }
        _ = drop(11, alex, .text, .someday, minutesAgo: 7000, unsure: true) {
            $0.rawText = "that pottery class maya mentioned"
        }
        _ = drop(12, maya, .url, .someday, minutesAgo: 6000) {
            $0.url = "https://sf.eater.com/maps/best-burritos-san-francisco"
            $0.title = "the best burritos in the mission"
            $0.type = .note
            $0.objectKind = .postcard
        }
        _ = drop(13, panth, .url, .vibes, minutesAgo: 3000) {
            $0.url = "https://music.apple.com/us/album/golden-hour/1"
            $0.title = "golden hour"
            $0.artist = "kacey musgraves"
            $0.type = .song
            $0.objectKind = .record
            $0.thumbnailPath = media("seed-album", jpeg: true)
        }
        let song = drop(14, alex, .url, .vibes, minutesAgo: 2500) {
            $0.url = "https://open.spotify.com/track/1k2pQc5i348DCHwbn5KTdc"
            $0.title = "pink pony club"
            $0.artist = "chappell roan"
            $0.type = .song
            $0.objectKind = .record
            $0.thumbnailPath = media("seed-pinkpony", jpeg: true)
            $0.suggestion = "sam saved something that goes with this."
        }
        _ = drop(15, maya, .image, .vibes, minutesAgo: 5000) {
            $0.rawText = "soft pink everything"
            $0.type = .mood
            $0.objectKind = .polaroid
            $0.thumbnailPath = media("seed-pinksky", jpeg: true)
        }
        let dumplings = drop(16, panth, .url, .someday, minutesAgo: 20000) {
            $0.title = "the dumpling place"
            $0.placeName = "dumpling home"
            $0.type = .place
            $0.objectKind = .postcard
        }
        dumplings.moveByUser(to: .done)
        show.relatedDropIds = [song.id]
        song.relatedDropIds = [show.id]

        let arriving = Drop(id: clientId(17), createdAt: now, authorId: sam.id, boardId: boardId, sourceKind: .url, url: "https://www.instagram.com/p/C9pastaplace")
        arriving.authorName = sam.name
        arriving.authorColor = sam.color
        context.insert(arriving)

        save(context)
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
