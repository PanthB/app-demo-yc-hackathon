#if DEBUG
import SwiftData
import SwiftUI

struct GlassSampleGate<Board: View>: View {
    @Query(GlassSamples.anyDrop) private var stored: [Drop]
    @ViewBuilder var board: Board

    var body: some View {
        if stored.isEmpty {
            board.modelContainer(GlassSamples.container)
        } else {
            board
        }
    }
}

enum GlassSamples {
    static var anyDrop: FetchDescriptor<Drop> {
        var descriptor = FetchDescriptor<Drop>()
        descriptor.fetchLimit = 1
        return descriptor
    }

    @MainActor static let container: ModelContainer = {
        let container = BoardStore.makeInMemoryContainer()
        for drop in drops(now: .now) {
            container.mainContext.insert(drop)
        }
        return container
    }()

    static func drops(now: Date) -> [Drop] {
        let me = DeviceIdentity.personId
        let saturday = Calendar.current.nextDate(
            after: now,
            matching: DateComponents(hour: 20, weekday: 7),
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(6 * 86400)

        let reminder = Drop(createdAt: now.addingTimeInterval(-466), dropperId: me, sourceKind: .text, rawText: "remind me to move the car in 1 hr")
        reminder.title = "move the car"
        reminder.dueAt = now.addingTimeInterval(3134)
        reminder.whenLabel = "in 1 hr"
        reminder.type = .note
        place(reminder, in: .now)

        let matcha = Drop(createdAt: now.addingTimeInterval(-3 * 86400), dropperId: me, sourceKind: .url, url: "https://maps.apple.com/?q=stonemill+matcha")
        matcha.title = "the matcha place"
        matcha.placeName = "stonemill matcha"
        matcha.latitude = 37.7625
        matcha.longitude = -122.4215
        matcha.whenLabel = "open till 6pm"
        matcha.kindWords = ["matcha", "cafe"]
        matcha.vibeWords = ["quiet", "sunny"]
        matcha.type = .place
        place(matcha, in: .now)

        let ramen = Drop(createdAt: now.addingTimeInterval(-5 * 86400), dropperId: me, sourceKind: .image)
        ramen.title = "ramen on clement"
        ramen.placeName = "the ramen shop on clement"
        ramen.cutoutPath = GlassSampleArt.ramen
        ramen.whenLabel = "some weeknight"
        ramen.kindWords = ["ramen"]
        ramen.type = .place
        place(ramen, in: .tonight)

        let ticket = Drop(createdAt: now.addingTimeInterval(-2 * 86400), dropperId: me, sourceKind: .pdf)
        ticket.title = "mk.gee at the fillmore"
        ticket.placeName = "the fillmore"
        ticket.startsAt = saturday
        ticket.price = "$35"
        ticket.type = .event
        place(ticket, in: .thisWeekend)

        let show = Drop(createdAt: now.addingTimeInterval(-9 * 86400), dropperId: me, sourceKind: .video, url: "https://www.tiktok.com/@livesets/video/7301")
        show.title = "that show in march"
        show.whenLabel = "sometime in march"
        show.type = .event
        place(show, in: .someday)

        let voice = Drop(createdAt: now.addingTimeInterval(-86400), dropperId: me, sourceKind: .audio)
        voice.title = "an idea for sam's birthday"
        voice.type = .note
        place(voice, in: .someday)

        let song = Drop(createdAt: now.addingTimeInterval(-8 * 86400), dropperId: me, sourceKind: .url, url: "https://open.spotify.com/track/4sample")
        song.title = "are you looking up"
        song.objectKind = .record
        song.type = .song
        song.relatedDropIds = [show.id]
        place(song, in: .vibes)

        let market = Drop(createdAt: now.addingTimeInterval(-12 * 86400), dropperId: me, sourceKind: .url, url: "https://maps.apple.com/?q=farmers+market")
        market.title = "the sunday farmers market"
        market.placeName = "clement street farmers market"
        market.type = .place
        place(market, in: .done)

        return [reminder, matcha, ramen, ticket, show, voice, song, market]
    }

    private static func place(_ drop: Drop, in zone: Zone) {
        drop.status = .processed
        drop.applyDecidedZone(zone, unsure: false)
    }
}

enum GlassSampleArt {
    static let ramen = "glass-sample/ramen"

    static func view(for path: String?) -> AnyView? {
        path == ramen ? AnyView(GlassSampleRamen()) : nil
    }
}

struct GlassSampleRamen: View {
    var body: some View {
        Canvas { context, size in
            let unit = min(size.width, size.height) / 128
            context.scaleBy(x: unit, y: unit)

            context.fill(Path(ellipseIn: CGRect(x: 8, y: 14, width: 104, height: 104)), with: .color(Color(red: 0.96, green: 0.93, blue: 0.86)))
            context.fill(Path(ellipseIn: CGRect(x: 16, y: 22, width: 88, height: 88)), with: .color(Color(red: 0.66, green: 0.34, blue: 0.14)))
            context.fill(Path(ellipseIn: CGRect(x: 21, y: 27, width: 78, height: 78)), with: .color(Color(red: 0.78, green: 0.45, blue: 0.19)))

            let strands: [(CGPoint, CGPoint, CGPoint)] = [
                (CGPoint(x: 32, y: 58), CGPoint(x: 88, y: 50), CGPoint(x: 58, y: 30)),
                (CGPoint(x: 28, y: 70), CGPoint(x: 92, y: 64), CGPoint(x: 60, y: 46)),
                (CGPoint(x: 34, y: 82), CGPoint(x: 90, y: 78), CGPoint(x: 62, y: 60)),
                (CGPoint(x: 42, y: 94), CGPoint(x: 84, y: 90), CGPoint(x: 62, y: 76)),
            ]
            for strand in strands {
                var noodle = Path()
                noodle.move(to: strand.0)
                noodle.addQuadCurve(to: strand.1, control: strand.2)
                context.stroke(noodle, with: .color(Color(red: 0.98, green: 0.86, blue: 0.55)), style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
            }

            var nori = Path()
            nori.move(to: CGPoint(x: 26, y: 20))
            nori.addLine(to: CGPoint(x: 50, y: 12))
            nori.addLine(to: CGPoint(x: 58, y: 40))
            nori.addLine(to: CGPoint(x: 34, y: 48))
            nori.closeSubpath()
            context.fill(nori, with: .color(Color(red: 0.1, green: 0.17, blue: 0.13)))

            context.fill(Path(ellipseIn: CGRect(x: 30, y: 60, width: 30, height: 25)), with: .color(.white))
            context.fill(Path(ellipseIn: CGRect(x: 38, y: 66, width: 13, height: 13)), with: .color(Color(red: 1.0, green: 0.7, blue: 0.2)))

            let scallions = [CGPoint(x: 66, y: 60), CGPoint(x: 74, y: 70), CGPoint(x: 64, y: 74), CGPoint(x: 72, y: 82), CGPoint(x: 80, y: 62)]
            for point in scallions {
                context.fill(Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)), with: .color(Color(red: 0.38, green: 0.68, blue: 0.33)))
            }

            for start in [CGPoint(x: 70, y: 100), CGPoint(x: 80, y: 104)] {
                var stick = Path()
                stick.move(to: start)
                stick.addLine(to: CGPoint(x: start.x + 40, y: start.y - 92))
                context.stroke(stick, with: .color(Color(red: 0.85, green: 0.63, blue: 0.4)), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }
    }
}
#endif
