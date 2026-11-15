#if DEBUG
import os
import SwiftData
import SwiftUI
import UIKit

enum ClusterFixture {
    struct Person {
        let id: String
        let name: String
        let color: String
    }

    static let panth = Person(id: "seed-panth", name: "panth", color: "orange")
    static let maya = Person(id: "seed-maya", name: "maya", color: "blue")
    static let sam = Person(id: "seed-sam", name: "sam", color: "green")
    static let alex = Person(id: "seed-alex", name: "alex", color: "pink")
    static let boardId = "sf-crew"
    static let arrivalId = UUID(uuidString: "C1057E00-0000-4000-8000-000000000001") ?? UUID()

    static func seedId(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "5EED0002-0000-4000-8000-%012X", number)) ?? UUID()
    }

    private static let sunny = ("sunny-afternoons", "upbeat, in the mission")
    private static let night = ("late-night", "late night")
    private static let golden = ("golden-hour", "golden hour, by the water")

    private static func facts(
        _ cluster: (String, String),
        _ vibes: [String],
        genre: String? = nil,
        _ neighbors: [(Int, String)]
    ) -> ClusterFacts {
        ClusterFacts(
            vibes: vibes,
            clusterId: cluster.0,
            clusterLabel: cluster.1,
            neighbors: neighbors.map { ClusterFacts.Neighbor(clientId: seedId($0.0).uuidString, reason: $0.1) },
            genre: genre
        )
    }

    static let facts: [UUID: ClusterFacts] = {
        var table: [UUID: ClusterFacts] = [
            seedId(1): facts(sunny, ["upbeat", "outdoors", "mission"], [(5, "both upbeat, outdoors."), (2, "both in the mission.")]),
            seedId(2): facts(sunny, ["cozy", "morning", "food", "mission"], [(3, "both morning, in the mission."), (1, "both in the mission.")]),
            seedId(3): facts(sunny, ["calm", "morning", "mission"], [(2, "both morning, in the mission.")]),
            seedId(4): facts(sunny, ["upbeat", "folk", "steady"], genre: "folk", [(1, "both upbeat."), (5, "both upbeat.")]),
            seedId(5): facts(sunny, ["upbeat", "outdoors"], [(1, "both upbeat, outdoors.")]),
            seedId(6): facts(night, ["late night", "food", "mission"], [(7, "both late night, food."), (10, "both late night, in the mission.")]),
            seedId(7): facts(night, ["cozy", "late night", "food", "japantown"], [(6, "both late night, food.")]),
            seedId(8): facts(night, ["dreamy", "late night", "rock", "steady"], genre: "rock", [(9, "both late night."), (14, "both dreamy.")]),
            seedId(9): facts(night, ["moody", "late night", "r&b", "slow"], genre: "r&b", [(8, "both late night.")]),
            seedId(10): facts(night, ["late night", "live music", "mission"], [(6, "both late night, in the mission.")]),
            seedId(11): facts(golden, ["golden hour", "by the water", "calm", "presidio"], [(12, "both golden hour, by the water."), (15, "both golden hour, by the water.")]),
            seedId(12): facts(golden, ["golden hour", "by the water", "dreamy"], [(11, "both golden hour, by the water."), (14, "both dreamy, golden hour.")]),
            seedId(13): facts(golden, ["calm", "by the water", "soul", "slow"], genre: "soul", [(11, "both calm, by the water.")]),
            seedId(14): facts(golden, ["dreamy", "golden hour", "r&b", "steady"], genre: "r&b", [(12, "both dreamy, golden hour.")]),
            seedId(15): facts(golden, ["golden hour", "by the water", "outdoors", "lands end"], [(11, "both golden hour, by the water.")]),
        ]
        table[arrivalId] = facts(sunny, ["upbeat", "indie", "steady"], genre: "indie", [(4, "both upbeat, steady."), (5, "both upbeat.")])
        return table
    }()

    @MainActor
    static func fill(_ context: ModelContext, now: Date = .now) {
        func drop(_ number: Int, _ person: Person, minutesAgo: Double, _ zone: Zone, configure: (Drop) -> Void) {
            let drop = Drop(id: seedId(number), createdAt: now.addingTimeInterval(-minutesAgo * 60), authorId: person.id, boardId: boardId, sourceKind: .url)
            drop.authorName = person.name
            drop.authorColor = person.color
            drop.status = .processed
            configure(drop)
            drop.applyDecidedZone(zone, unsure: false)
            context.insert(drop)
        }
        func clip(_ drop: Drop, _ url: String, _ title: String, image: String) {
            drop.url = url
            drop.title = title
            drop.type = .mood
            drop.objectKind = .polaroid
            drop.thumbnailPath = media(image)
        }
        func song(_ drop: Drop, _ url: String, _ title: String, _ artist: String, image: String? = nil) {
            drop.url = url
            drop.title = title
            drop.artist = artist
            drop.type = .song
            drop.objectKind = .record
            drop.thumbnailPath = image.flatMap(media)
        }
        func place(_ drop: Drop, _ url: String, _ title: String, _ name: String, _ latitude: Double, _ longitude: Double, image: String? = nil) {
            drop.url = url
            drop.title = title
            drop.placeName = name
            drop.latitude = latitude
            drop.longitude = longitude
            drop.type = .place
            drop.objectKind = .postcard
            drop.thumbnailPath = image.flatMap(media)
        }

        drop(1, maya, minutesAgo: 300, .vibes) {
            clip($0, "https://www.tiktok.com/@graacciiee/video/7617551860244745503", "dolores park on a sunny day", image: "seed-dolores")
            $0.placeName = "dolores park"
            $0.latitude = 37.75972
            $0.longitude = -122.42713
            $0.pinnedAt = now.addingTimeInterval(-2 * 3600)
        }
        drop(2, sam, minutesAgo: 1500, .someday) {
            place($0, "https://www.instagram.com/p/DHY65llvDPK/", "tartine morning bun", "tartine bakery", 37.76146, -122.42395)
        }
        drop(3, alex, minutesAgo: 2600, .someday) {
            place($0, "https://www.stonemillmatcha-us.com/", "stonemill matcha", "stonemill matcha", 37.76402, -122.42153, image: "seed-matcha")
        }
        drop(4, panth, minutesAgo: 900, .vibes) {
            song($0, "https://open.spotify.com/track/6UsdldEfcEXSID2G3nA89J", "san francisco (be sure to wear flowers in your hair)", "scott mckenzie")
        }
        drop(5, maya, minutesAgo: 4000, .vibes) {
            clip($0, "https://www.tiktok.com/@marissadaily_/video/7541446036347309343", "15 things to do in sf", image: "seed-bookshop")
        }
        drop(6, alex, minutesAgo: 700, .vibes) {
            clip($0, "https://www.tiktok.com/@thesnacksensei/video/7561602082596343095", "mission district food tour", image: "seed-strand")
        }
        drop(7, sam, minutesAgo: 2000, .vibes) {
            clip($0, "https://www.youtube.com/watch?v=zmIgc0SkVgE", "marufuku ramen", image: "seed-ramen")
            $0.placeName = "marufuku ramen"
            $0.latitude = 37.78530
            $0.longitude = -122.43010
        }
        drop(8, panth, minutesAgo: 3100, .vibes) {
            song($0, "https://open.spotify.com/track/0ofHAoxe9vBkTCp2UQIavz", "dreams", "fleetwood mac")
        }
        drop(9, maya, minutesAgo: 1200, .vibes) {
            song($0, "https://open.spotify.com/track/6ZRuF2n1CQxyxxAAWsKJOy", "nights like this", "kehlani")
        }
        drop(10, alex, minutesAgo: 5200, .someday) {
            place($0, "https://thechapelsf.com", "the chapel", "the chapel", 37.76049, -122.42120, image: "seed-concert")
        }
        drop(11, panth, minutesAgo: 450, .vibes) {
            clip($0, "https://www.instagram.com/p/DWCN6pbgn3F/", "golden gate from fort point", image: "seed-album")
            $0.placeName = "fort point"
            $0.latitude = 37.81060
            $0.longitude = -122.47710
        }
        drop(12, sam, minutesAgo: 3600, .vibes) {
            clip($0, "https://www.instagram.com/reel/DbySW82ILGn/", "the golden gate still feels unreal", image: "seed-pinksky")
        }
        drop(13, maya, minutesAgo: 6100, .vibes) {
            song($0, "https://open.spotify.com/track/3zBhihYUHBmGd2bcQIobrF", "(sittin' on) the dock of the bay", "otis redding")
        }
        drop(14, alex, minutesAgo: 2300, .vibes) {
            song($0, "https://open.spotify.com/track/3xKsf9qdS1CyvXSMEid6g8", "pink + white", "frank ocean", image: "seed-pinkpony")
        }
        drop(15, panth, minutesAgo: 8000, .someday) {
            place($0, "https://www.nps.gov/goga/planyourvisit/landsend.htm", "lands end trail", "lands end", 37.78020, -122.51150)
            $0.pinnedAt = now.addingTimeInterval(-20 * 3600)
        }
        save(context)
    }

    @MainActor
    static func playArrival(_ context: ModelContext) async {
        try? await Task.sleep(for: .seconds(2.5))
        let drop = Drop(id: arrivalId, createdAt: .now, authorId: panth.id, boardId: boardId, sourceKind: .url, url: "https://open.spotify.com/track/6MpCaSIOfqBqbMED4kXgNY")
        drop.authorName = panth.name
        drop.authorColor = panth.color
        context.insert(drop)
        save(context)
        Logger.app.info("cluster fixture: prom queen landed")
        try? await Task.sleep(for: .seconds(1.8))
        drop.title = "prom queen"
        drop.artist = "beach bunny"
        drop.type = .song
        drop.objectKind = .record
        drop.status = .processed
        drop.applyDecidedZone(.vibes, unsure: false)
        save(context)
        Logger.app.info("cluster fixture: prom queen was read")
    }

    private static func media(_ name: String) -> String? {
        guard let image = UIImage(named: name), let data = image.pngData() else {
            Logger.store.error("cluster fixture image \(name, privacy: .public) is missing")
            return nil
        }
        do {
            return try MediaStore.save(data, named: "cluster-\(name).png")
        } catch {
            Logger.store.error("saving cluster fixture image \(name, privacy: .public) failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    @MainActor
    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            Logger.store.error("saving the cluster fixture failed: \(String(describing: error), privacy: .public)")
        }
    }
}

struct ClusterPlayground: View {
    var body: some View {
        ClusterPlaygroundBoard()
            .modelContainer(for: Drop.self, inMemory: true)
    }
}

private struct ClusterPlaygroundBoard: View {
    @Query(sort: \Drop.createdAt) private var drops: [Drop]
    @Environment(\.modelContext) private var context
    @Namespace private var namespace
    @State private var opened: Drop?
    @State private var filled = false

    var body: some View {
        NavigationStack {
            ClusterBoardView(drops: filled ? drops : [], namespace: namespace, me: ClusterFixture.panth.id) { opened = $0 }
                .navigationTitle("sf crew")
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 64) }
                .sheet(item: $opened) { drop in
                    Text(drop.title ?? "")
                        .font(.title2.weight(.semibold))
                        .presentationDetents([.medium])
                        .navigationTransition(.zoom(sourceID: drop.id, in: namespace))
                }
        }
        .task {
            ClusterFixture.fill(context)
            filled = true
            if UserDefaults.standard.bool(forKey: "ClusterDebugArrival") {
                await ClusterFixture.playArrival(context)
            }
        }
    }
}
#endif
