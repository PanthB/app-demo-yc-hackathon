#if DEBUG
import os
import SwiftData
import UIKit

enum SeedBoard {
    @MainActor
    static func replace(in context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        clear(context)
        pin(into: context, now: now, calendar: calendar)
    }

    @MainActor
    static func pin(into context: ModelContext, now: Date = .now, calendar: Calendar = .current) {
        let me = DeviceIdentity.personId
        let today = calendar.startOfDay(for: now)
        func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            let base = calendar.date(byAdding: .day, value: offset, to: today) ?? today
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? base
        }
        func rounded(_ date: Date, toMinutes step: Double) -> Date {
            let seconds = step * 60
            return Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / seconds).rounded(.up) * seconds)
        }
        let weekday = calendar.component(.weekday, from: today)
        let saturday = 7 - weekday

        func drop(_ kind: SourceKind, _ zone: Zone, minutesAgo: Double, configure: (Drop) -> Void) -> Drop {
            let drop = Drop(createdAt: now.addingTimeInterval(-minutesAgo * 60), dropperId: me, sourceKind: kind)
            drop.status = .processed
            configure(drop)
            drop.applyDecidedZone(zone, unsure: false)
            context.insert(drop)
            return drop
        }

        _ = drop(.text, .now, minutesAgo: 2) {
            $0.rawText = "remind me in 1 hr to call mom back"
            $0.type = .note
            $0.dueAt = now.addingTimeInterval(58 * 60 + 12)
            $0.whenLabel = "in 1 hr"
        }
        _ = drop(.url, .now, minutesAgo: 90) {
            $0.url = "https://www.kettlmatcha.example/mission"
            $0.title = "matcha place"
            $0.placeName = "kettl matcha bar"
            $0.latitude = 37.7599
            $0.longitude = -122.4148
            $0.type = .place
            $0.objectKind = .postcard
            $0.startsAt = rounded(now.addingTimeInterval(40 * 60), toMinutes: 15)
            $0.thumbnailPath = media("seed-matcha", jpeg: true)
        }
        _ = drop(.image, .tonight, minutesAgo: 600) {
            $0.title = "tonkotsu ramen"
            $0.placeName = "mensho tokyo"
            $0.type = .place
            $0.objectKind = .cutout
            $0.startsAt = max(day(0, 19, 30), rounded(now.addingTimeInterval(2 * 3600), toMinutes: 30))
            $0.cutoutPath = media("seed-ramen", jpeg: false)
        }
        _ = drop(.pdf, .thisWeekend, minutesAgo: 1440) {
            $0.title = "chapel jazz night"
            $0.placeName = "the chapel"
            $0.type = .event
            $0.objectKind = .stub
            $0.startsAt = day(saturday, 20)
        }
        _ = drop(.audio, .thisWeekend, minutesAgo: 300) {
            $0.rawText = "the thrift spots on valencia, the one with the green awning first"
            $0.type = .note
            $0.objectKind = .slip
            $0.mediaDuration = 14
            $0.startsAt = day(saturday, 11)
        }
        let concert = drop(.video, .someday, minutesAgo: 4000) {
            $0.url = "https://www.tiktok.com/@soundcheck/video/7311"
            $0.title = "the warehouse show"
            $0.type = .event
            $0.objectKind = .polaroid
            $0.whenLabel = "sometime in march"
            $0.thumbnailPath = media("seed-concert", jpeg: true)
        }
        _ = drop(.url, .someday, minutesAgo: 9000) {
            $0.url = "https://www.greendoorbooks.example"
            $0.title = "green door books"
            $0.type = .place
            $0.objectKind = .postcard
            $0.thumbnailPath = media("seed-bookshop", jpeg: true)
        }
        let unsure = Drop(createdAt: now.addingTimeInterval(-7000 * 60), dropperId: me, sourceKind: .text, rawText: "that pottery class maya mentioned")
        unsure.status = .processed
        unsure.applyDecidedZone(.someday, unsure: true)
        context.insert(unsure)

        let song = drop(.url, .vibes, minutesAgo: 3000) {
            $0.url = "https://music.apple.com/us/album/golden-hour/1"
            $0.title = "golden hour"
            $0.artist = "kacey musgraves"
            $0.type = .song
            $0.objectKind = .record
            $0.thumbnailPath = media("seed-album", jpeg: true)
        }
        _ = drop(.text, .vibes, minutesAgo: 5000) {
            $0.rawText = "soft pink everything"
            $0.type = .mood
        }
        concert.relatedDropIds = [song.id]
        song.relatedDropIds = [concert.id]

        _ = drop(.url, .done, minutesAgo: 20000) {
            $0.title = "the dumpling place"
            $0.type = .place
            $0.objectKind = .postcard
        }
        _ = drop(.text, .done, minutesAgo: 30000) {
            $0.rawText = "call the landlord about the window"
            $0.type = .note
        }

        context.insert(Drop(createdAt: now, dropperId: me, sourceKind: .url, url: "https://www.instagram.com/p/C9pastaplace"))

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
